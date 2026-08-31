import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx
from jose import jwt

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


def _send(device: dict, *, title: str, body: str, data: dict | None = None) -> bool:
    credentials = _credentials()
    if credentials is None:
        return False
    _, _, _, topic = credentials
    environment = device.get("environment", "production")
    host = "api.sandbox.push.apple.com" if environment == "sandbox" else "api.push.apple.com"
    token = device["device_token"]
    payload = {
        "aps": {"alert": {"title": title, "body": body}, "sound": "default"},
        **(data or {}),
    }
    with httpx.Client(http2=True, timeout=10.0) as client:
        response = client.post(
            f"https://{host}/3/device/{token}",
            headers={
                "authorization": f"bearer {_authorization()}",
                "apns-topic": topic,
                "apns-push-type": "alert",
                "apns-priority": "10",
            },
            json=payload,
        )
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


def _deliver_team_activity(team_id: str, actor_id: str, summary: str, action: str) -> None:
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
        memberships = client.table("team_memberships").select("user_id").eq(
            "team_id", team_id
        ).neq("user_id", actor_id).execute().data or []
        user_ids = [row["user_id"] for row in memberships if row.get("user_id")]
        if not user_ids:
            return
        devices = client.table("push_devices").select(
            "device_token,environment"
        ).in_("user_id", user_ids).eq("enabled", True).execute().data or []
        for device in devices:
            _send(
                device,
                title=title,
                body=f"{actor_name} {described_action}",
                data={"team_id": team_id, "action": action},
            )
    except Exception:
        logger.exception("Team push delivery failed")


def enqueue_team_activity(team_id: str, actor_id: str, summary: str, action: str) -> None:
    if _credentials() is not None:
        _executor.submit(_deliver_team_activity, team_id, actor_id, summary, action)


def send_test(user_id: str) -> int:
    devices = get_supabase_admin().table("push_devices").select(
        "device_token,environment"
    ).eq("user_id", user_id).eq("enabled", True).execute().data or []
    return sum(
        1 for device in devices
        if _send(device, title="FindEZ notifications are ready", body="Team activity can now reach this iPhone.")
    )
