-- Keep API inventory connected to the application's existing Team Spaces.
-- API requests still run as authenticated (RLS), never as service_role.
begin;

create or replace function public.findez_api_can_access_workspace(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
    select exists (
        select 1 from public.api_keys k
        join public.teams t on t.team_id = p_workspace_id and t.owner_user_id = k.org_id
        where k.id::text = public.findez_api_claim('api_key_id')
          and k.org_id::text = public.findez_api_claim('api_org_id')
          and k.workspace_id::text is not distinct from public.findez_api_claim('api_workspace_id')
          and (k.workspace_id is null or k.workspace_id = p_workspace_id)
          and k.revoked_at is null and (k.expires_at is null or k.expires_at > now())
    );
$$;

-- PostgreSQL UPDATE/UPSERT needs SELECT visibility even with RETURNING minimal.
-- The internal 90-second RLS token is never returned to callers; HTTP read
-- endpoints independently require items:read/workspace:read/org:read.
drop policy if exists items_api_key_select on public.items;
create policy items_api_key_select on public.items for select to authenticated
using (
    workspace_id is not null and public.findez_api_can_access_workspace(workspace_id)
    and (
        public.findez_api_has_scope('items:read') or public.findez_api_has_scope('workspace:read')
        or public.findez_api_has_scope('org:read') or public.findez_api_has_scope('items:write')
        or public.findez_api_has_scope('import:write') or public.findez_api_has_scope('org:write')
    )
);

create or replace function public.assign_api_item_owner()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
    v_space public.spaces%rowtype;
    v_matches integer;
begin
    if public.findez_api_claim('api_key_id') is not null then
        if not public.findez_api_can_access_workspace(new.workspace_id) then
            raise insufficient_privilege using message = 'workspace access denied';
        end if;
        select count(*) into v_matches
        from public.spaces s join public.team_spaces ts on ts.space_id = s.id
        where ts.team_id = new.workspace_id and s.name = new.location;
        if v_matches <> 1 then
            raise invalid_parameter_value using message = 'use an unambiguous linked space location';
        end if;
        select s.* into v_space
        from public.spaces s join public.team_spaces ts on ts.space_id = s.id
        where ts.team_id = new.workspace_id and s.name = new.location;
        new.user_id := v_space.user_id;
        new.space_id := v_space.id;
    else
        -- Normal app writes derive the API boundary from the actual association.
        -- In particular, a personal item cannot retain a stale Team workspace.
        select ts.team_id into new.workspace_id
        from public.team_spaces ts where ts.space_id = new.space_id;
    end if;
    return new;
end;
$$;

drop trigger if exists items_assign_api_owner on public.items;
create trigger items_assign_api_owner
before insert or update of workspace_id, space_id, location on public.items
for each row execute function public.assign_api_item_owner();

create or replace function public.sync_api_team_space()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
    if tg_op in ('DELETE', 'UPDATE') then
        update public.items i set workspace_id = (
            select ts.team_id from public.team_spaces ts where ts.space_id = i.space_id
        ) where i.space_id = old.space_id;
    end if;
    if tg_op in ('INSERT', 'UPDATE') then
        update public.items set workspace_id = new.team_id where space_id = new.space_id;
    end if;
    return null;
end;
$$;

drop trigger if exists team_spaces_sync_api on public.team_spaces;
create trigger team_spaces_sync_api after insert or update or delete on public.team_spaces
for each row execute function public.sync_api_team_space();

-- Reconcile linked and detached rows; do not delete inventory or change owners.
update public.items i set workspace_id = (
    select ts.team_id from public.team_spaces ts where ts.space_id = i.space_id
) where i.space_id is not null and i.workspace_id is distinct from (
    select ts.team_id from public.team_spaces ts where ts.space_id = i.space_id
);

-- Strict JSON -> parameterized SQL. Only identifiers/operators from the fixed
-- whitelist enter the statement; all caller values stay in bound parameters.
create or replace function public.api_query_items(
    p_workspace_id uuid default null, p_filters jsonb default '[]'::jsonb,
    p_aggregate text default null, p_page integer default 1, p_page_size integer default 50
) returns jsonb language plpgsql stable security invoker set search_path = public
as $$
declare
    v_filter jsonb;
    v_index integer := 0;
    v_field text;
    v_op text;
    v_where text := ' where ($2 is null or i.workspace_id = $2)';
    v_total bigint;
    v_value bigint;
    v_items jsonb;
    v_columns text := 'i.item_id,i.workspace_id,i.name,i.category,i.quantity,i.location,i.image_url,i.barcode,i.purchase_source,i.notes,i.brand,i.part_number,i.source_system,i.external_id,i.created_at';
begin
    if not (public.findez_api_has_scope('items:read') or public.findez_api_has_scope('org:read')) then
        raise insufficient_privilege using message = 'items:read required';
    end if;
    if p_page is null or p_page < 1 or p_page > 1000000
       or p_page_size is null or p_page_size < 1 or p_page_size > 100
       or p_filters is null or jsonb_typeof(p_filters) <> 'array'
       or jsonb_array_length(p_filters) > 10
       or (p_aggregate is not null and p_aggregate not in ('count', 'sum_quantity')) then
        raise invalid_parameter_value using message = 'invalid query';
    end if;
    for v_filter in select value from jsonb_array_elements(p_filters) loop
        v_field := v_filter->>'field';
        v_op := case v_filter->>'op'
            when 'eq' then '=' when 'neq' then '<>' when 'gt' then '>'
            when 'gte' then '>=' when 'lt' then '<' when 'lte' then '<=' else null end;
        if v_field is null or v_field not in ('name','category','location','brand','part_number','barcode','quantity','source_system','external_id')
           or v_op is null or not (v_filter ? 'value') then
            raise invalid_parameter_value using message = 'invalid filter';
        end if;
        if v_field = 'quantity' then
            if jsonb_typeof(v_filter->'value') <> 'number'
               or (v_filter->>'value') !~ '^[0-9]{1,6}$'
               or (v_filter->>'value')::numeric > 100000 then
                raise invalid_parameter_value using message = 'invalid quantity';
            end if;
            v_where := v_where || format(' and i.%I %s (($1->%s->>''value'')::integer)', v_field, v_op, v_index);
        else
            if v_op not in ('=', '<>') or jsonb_typeof(v_filter->'value') <> 'string'
               or length(v_filter->>'value') > 200 then
                raise invalid_parameter_value using message = 'invalid text filter';
            end if;
            v_where := v_where || format(' and i.%I %s ($1->%s->>''value'')', v_field, v_op, v_index);
        end if;
        v_index := v_index + 1;
    end loop;
    execute 'select count(*), coalesce(sum(i.quantity),0) from public.items i' || v_where
        into v_total, v_value using p_filters, p_workspace_id;
    if p_aggregate is not null then
        return jsonb_build_object('resource','items','aggregate',p_aggregate,
            'value',case when p_aggregate = 'count' then v_total else v_value end);
    end if;
    execute 'select coalesce(jsonb_agg(row_to_json(r)),''[]''::jsonb) from (select ' || v_columns ||
        ' from public.items i' || v_where || ' order by i.created_at desc, i.item_id limit $3 offset $4) r'
        into v_items using p_filters, p_workspace_id, p_page_size, (p_page - 1) * p_page_size;
    return jsonb_build_object('resource','items','items',v_items,'page',p_page,'page_size',p_page_size,'total',v_total);
end;
$$;

revoke all on function public.api_query_items(uuid,jsonb,text,integer,integer) from public;
grant execute on function public.api_query_items(uuid,jsonb,text,integer,integer) to authenticated;
revoke all on function public.assign_api_item_owner() from public;
revoke all on function public.sync_api_team_space() from public;

notify pgrst, 'reload schema';
commit;
