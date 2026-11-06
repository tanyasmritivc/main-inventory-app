"""Notification policy rollout switch; separate from permission to send pushes."""
import os
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def enabled() -> bool:
    return os.environ.get('FINDEZ_NOTIFICATION_POLICY_ENABLED') == '1'


def fallback_timezone() -> str:
    value = os.environ.get('FINDEZ_NOTIFICATION_FALLBACK_TIMEZONE', 'America/Los_Angeles')
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError):
        return 'America/Los_Angeles'
    return value


CAPABILITIES = {
    'inventory_alerts': True, 'capture_reminders': True,
    'weekly_recap': False, 'cleanup_insights': False,
    'reengagement': False, 'user_reminders': False,
}
