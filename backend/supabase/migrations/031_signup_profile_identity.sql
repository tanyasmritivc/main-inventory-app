-- Persist signup identity fields before an email-confirmation session exists.
-- This keeps team member names consistent across web and mobile signups.
begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  given_name text := trim(coalesce(metadata->>'given_name', ''));
  family_name text := trim(coalesce(metadata->>'family_name', ''));
  display_name text := trim(coalesce(
    nullif(metadata->>'display_name', ''),
    nullif(metadata->>'full_name', ''),
    nullif(metadata->>'name', ''),
    concat_ws(' ', nullif(given_name, ''), nullif(family_name, ''))
  ));
begin
  insert into public.profiles (
    id,
    is_pro,
    created_at,
    display_name,
    first_name,
    last_name,
    organization,
    profile_role
  ) values (
    new.id,
    false,
    now(),
    nullif(left(display_name, 100), ''),
    nullif(left(given_name, 100), ''),
    nullif(left(family_name, 100), ''),
    nullif(left(trim(coalesce(metadata->>'organization', '')), 120), ''),
    nullif(left(trim(coalesce(metadata->>'profile_role', '')), 120), '')
  )
  on conflict (id) do update set
    display_name = coalesce(nullif(excluded.display_name, ''), profiles.display_name),
    first_name = coalesce(nullif(excluded.first_name, ''), profiles.first_name),
    last_name = coalesce(nullif(excluded.last_name, ''), profiles.last_name),
    organization = coalesce(nullif(excluded.organization, ''), profiles.organization),
    profile_role = coalesce(nullif(excluded.profile_role, ''), profiles.profile_role);
  return new;
end;
$$;

-- Repair existing profiles where an OAuth or email signup already supplied a
-- name in auth metadata but the older trigger did not copy it.
update public.profiles as profile
set
  display_name = coalesce(
    nullif(trim(profile.display_name), ''),
    nullif(left(trim(coalesce(
      nullif(auth_user.raw_user_meta_data->>'display_name', ''),
      nullif(auth_user.raw_user_meta_data->>'full_name', ''),
      nullif(auth_user.raw_user_meta_data->>'name', ''),
      concat_ws(
        ' ',
        nullif(trim(coalesce(auth_user.raw_user_meta_data->>'given_name', '')), ''),
        nullif(trim(coalesce(auth_user.raw_user_meta_data->>'family_name', '')), '')
      )
    )), 100), '')
  ),
  first_name = coalesce(
    nullif(trim(profile.first_name), ''),
    nullif(left(trim(coalesce(auth_user.raw_user_meta_data->>'given_name', '')), 100), '')
  ),
  last_name = coalesce(
    nullif(trim(profile.last_name), ''),
    nullif(left(trim(coalesce(auth_user.raw_user_meta_data->>'family_name', '')), 100), '')
  ),
  organization = coalesce(
    nullif(trim(profile.organization), ''),
    nullif(left(trim(coalesce(auth_user.raw_user_meta_data->>'organization', '')), 120), '')
  ),
  profile_role = coalesce(
    nullif(trim(profile.profile_role), ''),
    nullif(left(trim(coalesce(auth_user.raw_user_meta_data->>'profile_role', '')), 120), '')
  )
from auth.users as auth_user
where profile.id = auth_user.id;

commit;
