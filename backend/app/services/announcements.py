"""Account-only announcement delivery. Entitlements stay in limits.py."""
from app.core.config import get_settings
from app.services.limits import LIMITS, get_user_tier, resolve_effective_limits
from app.services.supabase_client import get_supabase_admin


def access_snapshot(user_id: str) -> dict:
    pilot = get_settings().pilot_mode
    effective, team = resolve_effective_limits(user_id)
    tier = get_user_tier(user_id)
    # In pilot mode both current and Free accounts have the same active policy.
    # Never present proposed marketing quotas as a current entitlement.
    free = effective if pilot else LIMITS['free']
    def allowance(limits, key):
        return 'Included' if limits.get(key) is None else 'Limited'
    rows = [
        ('Open and search items', 'Included', 'Included'),
        ('See item details', 'Included', 'Included'),
        ('Export your inventory', 'Included', 'Included'),
        ('Ask FindEZ', allowance(effective, 'chats_per_month'), allowance(free, 'chats_per_month')),
        ('Add new items', allowance(effective, 'items'), allowance(free, 'items')),
        ('Add from a photo', allowance(effective, 'scans_per_month'), allowance(free, 'scans_per_month')),
        ('Import a spreadsheet', 'Limited' if (team or effective.get('items') is not None) and not pilot else 'Included', allowance(free, 'items')),
    ]
    return {
        'pilot': pilot,
        'name': 'Free pre-launch access' if pilot else {'pro': 'Pro', 'team_member': 'Team'}.get(tier, 'Free'),
        'badge': 'Free' if pilot or tier == 'free' else None,
        'rows': [{'label': label, 'now': now, 'free': later} for label, now, later in rows],
        'fine': 'Saved items stay accessible when plans change.',
    }


def claim(user_id: str, request) -> dict:
    access = access_snapshot(user_id)  # A failed plan read must not claim a popup.
    result = get_supabase_admin().rpc('findez_claim_announcement', {
        'p_user': user_id, 'p_session': str(request.session_id),
        'p_platform': request.platform, 'p_client': request.client_revision,
        'p_pilot': access['pilot'], 'p_legacy_seen': request.legacy_seen,
    }).execute()
    return {'campaign': result.data, 'access': access}


def receipt(user_id: str, campaign_id: str, event: str) -> bool:
    return bool(get_supabase_admin().rpc('findez_announcement_receipt', {
        'p_user': user_id, 'p_campaign': campaign_id, 'p_event': event,
    }).execute().data)
