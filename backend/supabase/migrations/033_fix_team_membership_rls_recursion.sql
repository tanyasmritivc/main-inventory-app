-- The original team_memberships SELECT policy queried team_memberships from
-- inside its own policy, which PostgreSQL rejects as infinite recursion.

create or replace function public.findez_is_team_member(p_team_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.team_memberships tm
        where tm.team_id = p_team_id
          and tm.user_id = p_user_id
    );
$$;

revoke all on function public.findez_is_team_member(uuid, uuid) from public;
grant execute on function public.findez_is_team_member(uuid, uuid) to authenticated;

drop policy if exists "team_member_can_read_roster" on public.team_memberships;
create policy "team_member_can_read_roster" on public.team_memberships
for select to authenticated
using (public.findez_is_team_member(team_id, auth.uid()));

drop policy if exists "team_member_can_read_team" on public.teams;
create policy "team_member_can_read_team" on public.teams
for select to authenticated
using (public.findez_is_team_member(team_id, auth.uid()));
