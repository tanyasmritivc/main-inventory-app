import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import jwt

from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="apns")
_token_lock = threading.Lock()
_provider_token: tuple[str, float] | None = None


def _credentials() -> tuple[str, str, str, str] | None:
    settings = get_settings()
    if not settings.apns_key_path or not settings.apns_key_id or not settings.apns_team_id:
        return None
    return (
        settings.apns_key_path,
        settings.apns_key_id,
        settings.apns_team_id,
        settings.apns_topic,
    )


def _authorization() -> str:
    global _provider_token
    credentials = _credentials()
    if credentials is None:
        raise RuntimeError("APNs is not configured")
    key_path, key_id, team_id, _ = credentials
    with _token_lock:
        now = time.time()
        if _provider_token and now - _provider_token[1] < 3000:
            return _provider_token[0]
        private_key = Path(key_path).read_text(encoding="utf-8")
        token = jwt.encode(
            {"iss": team_id, "iat": int(now)},
            private_key,
            algorithm="ES256",
            headers={"kid": key_id},
        )
        _provider_token = (token, now)
        return token


def _send(
    device: dict,
    *,
    title: str,
    body: str,
    data: dict | None = None,
    badge: int | None = None,
    thread_id: str | None = None,
) -> bool:
    credentials = _credentials()
    if credentials is None:
        return False
    _, _, _, topic = credentials
    environment = device.get("environment", "production")
    host = "api.sandbox.push.apple.com" if environment == "sandbox" else "api.push.apple.com"
    token = device["device_token"]
    aps = {
        "alert": {"title": title, "body": body},
        "sound": "default",
        "category": "TEAM_ACTIVITY",
    }
    if badge is not None:
        aps["badge"] = max(0, badge)
    if thread_id:
        aps["thread-id"] = thread_id
    payload = {"aps": aps, **(data or {})}
    response = None
    for attempt in range(3):
        try:
            with httpx.Client(http2=True, timeout=10.0) as client:
                response = client.post(
                    f"https://{host}/3/device/{token}",
                    headers={"authorization": f"bearer {_authorization()}",
                             "apns-topic": topic, "apns-push-type": "alert", "apns-priority": "10"},
                    json=payload,
                )
            if response.status_code != 429 and response.status_code < 500:
                break
        except httpx.HTTPError:
            # Exception URLs can contain private device tokens. Keep logs generic.
            if attempt == 2:
                logger.warning("APNs transport unavailable after bounded retries")
                return False
        if attempt < 2:
            time.sleep(attempt + 1)
    if response is None:
        return False
    if response.status_code == 200:
        return True
    reason = ""
    try:
        reason = response.json().get("reason", "")
    except ValueError:
        pass
    if response.status_code == 410 or reason in {"BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"}:
        get_supabase_admin().table("push_devices").update({"enabled": False}).eq(
            "device_token", token
        ).execute()
    logger.warning("APNs rejected a notification: status=%s reason=%s", response.status_code, reason)
    return False


def _deliver_to_recipients(
    team_id: str,
    actor_id: str,
    summary: str,
    action: str,
    recipient_ids: list[str],
    inventory_id: str | None = None,
) -> None:
    try:
        client = get_supabase_admin()
        teams = client.table("teams").select("name").eq("team_id", team_id).limit(1).execute().data or []
        title = teams[0].get("name", "FindEZ Team") if teams else "FindEZ Team"
        profiles = client.table("profiles").select(
            "display_name,first_name,last_name"
        ).eq("id", actor_id).limit(1).execute().data or []
        actor_name = "A team member"
        if profiles:
            profile = profiles[0]
            fallback = " ".join(
                part for part in (profile.get("first_name"), profile.get("last_name")) if part
            ).strip()
            actor_name = profile.get("display_name") or fallback or actor_name
        described_action = summary[:1].lower() + summary[1:] if summary else "updated the team"
        user_ids = list({user_id for user_id in recipient_ids if user_id and user_id != actor_id})
        if not user_ids:
            return
        members = client.table("team_memberships").select("user_id").eq("team_id", team_id).in_("user_id", user_ids).execute().data or []
        user_ids = [user_id for user_id in user_ids if user_id in {row['user_id'] for row in members}]
        if not user_ids:
            return
        devices = client.table("push_devices").select(
            "user_id,device_token,environment"
        ).in_("user_id", user_ids).eq("enabled", True).execute().data or []
        cutoff = (datetime.now(timezone.utc) - timedelta(days=14)).isoformat()
        recipient_rows = client.table("team_notification_recipients").select(
            "user_id,activity_id"
        ).in_("user_id", user_ids).gte("created_at", cutoff).execute().data or []
        activity_ids = list({row["activity_id"] for row in recipient_rows})
        read_pairs: set[tuple[str, str]] = set()
        activity_actors: dict[str, str | None] = {}
        if activity_ids:
            activities = client.table("team_activity").select(
                "activity_id,actor_id"
            ).in_("activity_id", activity_ids).execute().data or []
            activity_actors = {
                row["activity_id"]: row.get("actor_id") for row in activities
            }
            reads = client.table("team_notification_reads").select(
                "user_id,activity_id"
            ).in_("user_id", user_ids).in_("activity_id", activity_ids).execute().data or []
            read_pairs = {(row["user_id"], row["activity_id"]) for row in reads}
        unread_counts = {
            user_id: sum(
                1
                for row in recipient_rows
                if row["user_id"] == user_id
                and activity_actors.get(row["activity_id"]) != user_id
                and (user_id, row["activity_id"]) not in read_pairs
            )
            for user_id in user_ids
        }
        for device in devices:
            # Recheck at delivery, since membership can change while queued.
            if inventory_id and not client.rpc('findez_inventory_role', {
                'p_inventory': inventory_id, 'p_actor': device.get('user_id'),
            }).execute().data:
                continue
            _send(
                device,
                title=title,
                body=f"{actor_name} {described_action}",
                data={"team_id": team_id, "action": action, "recipient_user_id": device.get("user_id")},
                badge=unread_counts.get(device.get("user_id"), 1),
                thread_id=f"team-{team_id}",
            )
    except Exception:
        logger.warning("Team push delivery could not finish")


def enqueue_notifications(
    team_id: str,
    actor_id: str,
    summary: str,
    action: str,
    recipient_ids: list[str],
    inventory_id: str | None = None,
) -> None:
    if _credentials() is not None and recipient_ids:
        _executor.submit(
            _deliver_to_recipients,
            team_id,
            actor_id,
            summary,
            action,
            recipient_ids,
            inventory_id,
        )


def send_test(user_id: str) -> int:
    devices = get_supabase_admin().table("push_devices").select(
        "device_token,environment"
    ).eq("user_id", user_id).eq("enabled", True).execute().data or []
    return sum(
        1 for device in devices
        if _send(device, title="FindEZ notifications are ready", body="Team activity can now reach this iPhone.")
    )


def _deliver_invitation(invitation_id: str) -> None:
    try:
        client = get_supabase_admin()
        target = client.rpc('findez_invitation_push_target', {'p_invitation': invitation_id}).execute().data
        if not target:
            return
        devices = client.table('push_devices').select('device_token,environment').eq('user_id', target).eq('enabled', True).execute().data or []
        for device in devices:
            # A canceled/accepted invitation or revoked sender must not be pushed.
            if client.rpc('findez_invitation_push_target', {'p_invitation': invitation_id}).execute().data != target:
                return
            _send(device, title='FindEZ invitation',
                  body='You have a new invitation. Open Notifications to review it.',
                  data={'action':'access_invitation','invitation_id':invitation_id,'recipient_user_id':target})
    except Exception:
        logger.warning('Invitation phone alert unavailable; invitation remains in inbox')


def enqueue_invitation(invitation_id: str) -> None:
    if _credentials() is not None:
        _executor.submit(_deliver_invitation, invitation_id)
