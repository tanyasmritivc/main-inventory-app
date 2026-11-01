-- Pending identifications belong to their selected Space, just like saved items.
-- Bind existing name-based records without deleting unassigned captures.
begin;

alter table public.capture_reviews
  add column if not exists space_id uuid references public.spaces(id) on delete cascade;

create index if not exists idx_capture_reviews_space_id
  on public.capture_reviews(space_id);

update public.capture_reviews r
set space_id = s.id
from public.spaces s
where r.space_id is null
  and r.user_id = s.user_id
  and lower(btrim(r.location)) = lower(btrim(s.name))
  and lower(btrim(r.location)) <> 'unsorted'
  and not exists (
    select 1 from public.spaces other
    where other.user_id = s.user_id and other.id <> s.id
      and lower(btrim(other.name)) = lower(btrim(s.name))
  );

create or replace function public.bind_capture_review_space()
returns trigger language plpgsql set search_path = public as $$
declare
  space_name text;
  matching_id uuid;
  matches integer;
begin
  if new.space_id is not null then
    select name into space_name from public.spaces
    where id = new.space_id and user_id = new.user_id;
    if not found then
      raise check_violation using message = 'Review Space must belong to its owner';
    end if;
    if tg_op = 'UPDATE' and new.location is distinct from old.location
       and lower(btrim(coalesce(new.location, ''))) <> lower(btrim(space_name)) then
      new.space_id := null;
    else
      new.location := space_name;
    end if;
  end if;

  if new.space_id is null
     and nullif(btrim(new.location), '') is not null
     and lower(btrim(new.location)) <> 'unsorted' then
    select count(*), min(id::text)::uuid into matches, matching_id
    from public.spaces
    where user_id = new.user_id
      and lower(btrim(name)) = lower(btrim(new.location));
    if matches = 1 then
      new.space_id := matching_id;
      select name into new.location from public.spaces where id = matching_id;
    elsif matches > 1 then
      raise check_violation using message = 'Review location matches more than one Space';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists capture_review_bind_space on public.capture_reviews;
create trigger capture_review_bind_space
before insert or update of user_id, location, space_id on public.capture_reviews
for each row execute function public.bind_capture_review_space();

create or replace function public.sync_space_review_location()
returns trigger language plpgsql set search_path = public as $$
begin
  update public.capture_reviews
  set location = new.name, updated_at = now()
  where space_id = new.id and user_id = new.user_id;
  return new;
end;
$$;

drop trigger if exists space_sync_review_location on public.spaces;
create trigger space_sync_review_location
after update of name on public.spaces
for each row when (old.name is distinct from new.name)
execute function public.sync_space_review_location();

notify pgrst, 'reload schema';
commit;
