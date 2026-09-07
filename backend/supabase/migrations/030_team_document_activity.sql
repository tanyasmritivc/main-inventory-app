alter table public.team_activity
  drop constraint if exists team_activity_action_check;

alter table public.team_activity
  add constraint team_activity_action_check check (action in (
    'space_created', 'space_added', 'space_removed',
    'item_added', 'item_updated', 'item_deleted',
    'task_created', 'task_updated', 'task_completed', 'task_deleted',
    'member_joined', 'member_role_changed', 'member_removed',
    'document_uploaded', 'document_deleted'
  ));
