insert into public.team_notification_recipients (activity_id, user_id, reason, created_at)
select activity.activity_id, membership.user_id, activity.action, activity.created_at
from public.team_activity as activity
join public.team_memberships as membership on membership.team_id = activity.team_id
where activity.created_at >= now() - interval '14 days'
on conflict (activity_id, user_id) do nothing;

notify pgrst, 'reload schema';
