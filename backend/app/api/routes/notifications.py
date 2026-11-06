from datetime import datetime, timedelta, timezone

from uuid import UUID
from zoneinfo import available_timezones
from fastapi import APIRouter, Depends, HTTPException
from postgrest.exceptions import APIError
from app.schemas.notification_preferences import PreferenceChange, StockRulesChange
from app.services import notification_policy
from app.services.account_memory import actor_id
from app.services.supabase_client import get_supabase_raw

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin
from app.services.access_invitations import notification_rows, invitation_rpc

router = APIRouter(prefix="/notifications", tags=["notifications"])
NOTIFICATION_HISTORY_DAYS = 30


def _history_cutoff() -> str:
    return (datetime.now(timezone.utc) - timedelta(days=NOTIFICATION_HISTORY_DAYS)).isoformat()


def _team_ids(user_id: str) -> list[str]:
    rows = get_supabase_admin().table("team_memberships").select("team_id").eq(
        "user_id", user_id
    ).execute().data or []
    return [row["team_id"] for row in rows]


def _visible_activity(client, user_id: str, activity: list[dict]) -> list[dict]:
    teams = set(_team_ids(user_id))
    inventory_access, spaces = {}, {}
    visible = []
    for row in activity:
        if row.get('team_id') not in teams:
            continue
        metadata = row.get('metadata') or {}
        inventory = metadata.get('inventory_id')
        space = metadata.get('space_id')
        if space and not inventory:
            if space not in spaces:
                rows = client.table('spaces').select('inventory_id').eq('id', space).limit(1).execute().data or []
                spaces[space] = rows[0].get('inventory_id') if rows else None
            inventory = spaces[space]
            if not inventory:
                continue
        if inventory:
            if inventory not in inventory_access:
                inventory_access[inventory] = bool(client.rpc('findez_inventory_role', {'p_inventory':inventory,'p_actor':user_id}).execute().data)
            if not inventory_access[inventory]:
                continue
        visible.append(row)
    return visible


def _task_title_from_summary(summary: str) -> str:
    for prefix, suffix in (
        ("Added ", " to the Team Board"),
        ("Completed ", ""),
        ("Updated ", ""),
    ):
        if summary.startswith(prefix) and (not suffix or summary.endswith(suffix)):
            end = -len(suffix) if suffix else None
            return summary[len(prefix):end].strip()
    return ""


def _presentation(row: dict, actor_name: str, task: dict | None) -> tuple[str, str]:
    action = row.get("action", "")
    metadata = row.get("metadata") or {}
    if action.startswith("task_"):
        task_type = metadata.get("task_type") or (task or {}).get("task_type") or "task"
        label = {
            "task": "Task",
            "part_request": "Part Request",
            "checklist": "Checklist",
        }.get(task_type, "Team Board")
        title = (
            metadata.get("title")
            or (task or {}).get("title")
            or _task_title_from_summary(row.get("summary", ""))
        )
        verb = {
            "task_created": "created",
            "task_updated": "updated",
            "task_completed": "completed",
            "task_deleted": "deleted",
        }.get(action, "updated")
        subject = f"the {label.lower()}"
        text = f"{actor_name} {verb} {subject}"
        if title:
            text += f": {title}"
        return label, text
    label = "Team"
    if action.startswith("space_"):
        label = "Space"
    elif action.startswith("item_"):
        label = "Inventory"
    elif action.startswith("member_"):
        label = "People"
    summary = (row.get("summary") or "updated the team").strip()
    described = summary[:1].lower() + summary[1:] if summary else "updated the team"
    return label, f"{actor_name} {described}"


@router.get("")
def list_notifications(user: AuthenticatedUser = Depends(get_current_user)):
    if notification_policy.enabled():
        return policy_inbox(user)
    client = get_supabase_admin()
    invitations = notification_rows(user.user_id)
    recipient_rows = client.table("team_notification_recipients").select(
        "activity_id"
    ).eq("user_id", user.user_id).gte(
        "created_at", _history_cutoff()
    ).execute().data or []
    activity_ids = [row["activity_id"] for row in recipient_rows]
    if not activity_ids:
        return {"notifications": invitations, "unread_count": sum(not row['is_read'] for row in invitations)}
    activity = client.table("team_activity").select("*").in_(
        "activity_id", activity_ids
    ).gte("created_at", _history_cutoff()).order(
        "created_at", desc=True
    ).limit(1000).execute().data or []
    activity = _visible_activity(client, user.user_id, activity)
    if not activity:
        return {"notifications":invitations,"unread_count":sum(not row['is_read'] for row in invitations)}
    team_ids = list({row["team_id"] for row in activity if row.get("team_id")})
    teams = client.table("teams").select("team_id,name").in_(
        "team_id", team_ids
    ).execute().data or []
    team_names = {row["team_id"]: row["name"] for row in teams}
    actor_ids = list({row.get("actor_id") for row in activity if row.get("actor_id")})
    profiles = []
    if actor_ids:
        profiles = client.table("profiles").select(
            "id,display_name,first_name,last_name"
        ).in_("id", actor_ids).execute().data or []
    actor_names = {}
    for profile in profiles:
        fallback = " ".join(
            part for part in (profile.get("first_name"), profile.get("last_name")) if part
        ).strip()
        actor_names[profile["id"]] = profile.get("display_name") or fallback or "Team member"
    task_ids = list({
        (row.get("metadata") or {}).get("task_id")
        for row in activity
        if row.get("action", "").startswith("task_")
        and (row.get("metadata") or {}).get("task_id")
    })
    board_tasks = []
    if task_ids:
        board_tasks = client.table("team_board_tasks").select(
            "task_id,title,task_type"
        ).in_("task_id", task_ids).execute().data or []
    tasks_by_id = {row["task_id"]: row for row in board_tasks}
    activity_ids = [row["activity_id"] for row in activity]
    reads = []
    if activity_ids:
        reads = client.table("team_notification_reads").select("activity_id").eq(
            "user_id", user.user_id
        ).in_("activity_id", activity_ids).execute().data or []
    read_ids = {row["activity_id"] for row in reads}
    result = []
    unread = 0
    for row in activity:
        is_own = row.get("actor_id") == user.user_id
        is_read = is_own or row["activity_id"] in read_ids
        if not is_read:
            unread += 1
        actor_name = "You" if is_own else actor_names.get(row.get("actor_id"), "Team member")
        task_id = (row.get("metadata") or {}).get("task_id")
        activity_type, display_text = _presentation(
            row, actor_name, tasks_by_id.get(task_id)
        )
        result.append({
            **row,
            "team_name": team_names.get(row["team_id"], "Team"),
            "actor_name": actor_name,
            "activity_type": activity_type,
            "display_text": display_text,
            "is_read": is_read,
        })
    return {"notifications": invitations + result, "unread_count": unread + sum(not row['is_read'] for row in invitations)}


@router.post("/read")
def mark_notifications_read(user: AuthenticatedUser = Depends(get_current_user)):
    if notification_policy.enabled():
        actor = actor_id(user)
        count = _policy_rpc('findez_notification_inbox_action', {'p_actor':actor,'p_action':'read'})
        invitation_rpc(actor, 'read')
        return {'marked_read':count}
    client = get_supabase_admin()
    invitation_rpc(user.user_id, 'read')
    recipient_rows = client.table("team_notification_recipients").select(
        "activity_id"
    ).eq("user_id", user.user_id).gte(
        "created_at", _history_cutoff()
    ).execute().data or []
    activity_ids = [row["activity_id"] for row in recipient_rows]
    if not activity_ids:
        return {"marked_read": 0}
    activity = client.table("team_activity").select(
        "activity_id,actor_id"
    ).in_("activity_id", activity_ids).neq(
        "actor_id", user.user_id
    ).gte("created_at", _history_cutoff()).execute().data or []
    rows = [{
        "user_id": user.user_id,
        "activity_id": row["activity_id"],
        "read_at": datetime.now(timezone.utc).isoformat(),
    } for row in activity]
    if rows:
        client.table("team_notification_reads").upsert(
            rows, on_conflict="user_id,activity_id"
        ).execute()
    return {"marked_read": len(rows)}


def _policy_rpc(name, values):
    if not notification_policy.enabled():
        raise HTTPException(404, 'Notification preferences are not available yet.')
    try:
        return get_supabase_raw().rpc(name, values).execute().data
    except APIError as error:
        if error.code == '42501':
            raise HTTPException(403, 'This item is no longer available to your account.') from None
        if error.code in {'PT409', '40001'}:
            raise HTTPException(409, 'Preferences changed on another device. Refresh and try again.') from None
        if error.code in {'22023','23514','22P02','23502'}:
            raise HTTPException(422, 'Choose valid notification preferences.') from None
        raise HTTPException(503, 'Notifications could not be updated. Try again.') from None
    except Exception:
        raise HTTPException(503, 'Notifications are unavailable. Try again.') from None


@router.post('/stock-rules')
def stock_rules(body: StockRulesChange, user: AuthenticatedUser = Depends(get_current_user)):
    return {'rules':_policy_rpc('findez_notification_stock_rules', {
        'p_actor':actor_id(user),'p_rules':[r.model_dump(mode='json') for r in body.rules],
        'p_import':body.import_only})}


@router.get('/preferences')
def read_preferences(user: AuthenticatedUser = Depends(get_current_user)):
    preferences = _policy_rpc('findez_notification_preferences', {'p_actor':actor_id(user),'p_timezone':notification_policy.fallback_timezone()})
    return {'preferences':preferences,'capabilities':notification_policy.CAPABILITIES,
            'timezones':sorted(available_timezones()),
            'policy':{'daily':2,'weekly':5,'noncritical_hours':24,'local_alerts':False}}


@router.patch('/preferences')
def change_preferences(body: PreferenceChange, user: AuthenticatedUser = Depends(get_current_user)):
    values = body.model_dump(mode='json',exclude_unset=True,exclude={'expected_revision'})
    return {'preferences':_policy_rpc('findez_notification_preferences', {
        'p_actor':actor_id(user),'p_data':values,'p_expected':body.expected_revision,
        'p_timezone':notification_policy.fallback_timezone()})}


def policy_inbox(user):
    actor = actor_id(user)
    preferences = _policy_rpc('findez_notification_preferences', {'p_actor':actor,'p_timezone':notification_policy.fallback_timezone()})
    if not preferences['in_app_enabled']:
        return {'notifications':[],'unread_count':0,'policy_version':1}
    rows = _policy_rpc('findez_notification_inbox', {'p_actor':actor})
    try:
        hidden = {row['invitation_id'] for row in get_supabase_raw().table('notification_inbox_hidden').select('invitation_id').eq('user_id',actor).execute().data or []}
        invitations = [dict(row,id=row['activity_id']) for row in notification_rows(actor)
                       if row.get('invitation',{}).get('status')=='pending' and row['activity_id'] not in hidden]
    except Exception:
        raise HTTPException(503, 'Notifications could not be loaded. Try again.') from None
    rows = sorted(rows+invitations,key=lambda row:row['created_at'],reverse=True)
    return {'notifications':rows,'unread_count':sum(not row['is_read'] for row in rows),'policy_version':1}


@router.post('/{notification_id}/dismiss')
def dismiss_notification(notification_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    actor = actor_id(user)
    # Authorize against the current actionable feed before hiding an invitation.
    rows = policy_inbox(user)['notifications']
    row = next((row for row in rows if row['id']==str(notification_id)),None)
    if row is None:
        return {'dismissed':True}  # idempotent; never discloses another account's ID
    if row['action']=='access_invitation':
        try:
            get_supabase_raw().table('notification_inbox_hidden').upsert({'user_id':actor,'invitation_id':str(notification_id)},on_conflict='user_id,invitation_id').execute()
        except Exception:
            raise HTTPException(503, 'This notification could not be dismissed.') from None
    else:
        _policy_rpc('findez_notification_inbox_action', {'p_actor':actor,'p_action':'dismiss','p_id':str(notification_id)})
    return {'dismissed':True}


@router.post('/clear')
def clear_notifications(user: AuthenticatedUser = Depends(get_current_user)):
    # One request clears the visible snapshot; new arrivals remain visible.
    actor = actor_id(user)
    rows = policy_inbox(user)['notifications']
    for row in rows:
        if row['action']!='access_invitation':
            _policy_rpc('findez_notification_inbox_action', {'p_actor':actor,'p_action':'dismiss','p_id':row['id']})
    invitations = [{'user_id':actor,'invitation_id':row['id']} for row in rows if row['action']=='access_invitation']
    if invitations:
        try:
            get_supabase_raw().table('notification_inbox_hidden').upsert(invitations,on_conflict='user_id,invitation_id').execute()
        except Exception:
            raise HTTPException(503, 'Some notifications could not be cleared. Try again.') from None
    return {'cleared':True}
