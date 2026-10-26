"""Fresh actor identity and opted-in preferences, never another owner's profile."""
import logging
from app.services.supabase_client import get_supabase_raw
from app.services.memory_context import load_preferences

logger = logging.getLogger(__name__)


def load(actor):
    result = {'profile': {}, 'preferences': load_preferences(actor)}
    try:
        rows = get_supabase_raw().table('profiles').select('first_name,display_name').eq('id', actor).limit(1).execute().data or []
        if rows:
            result['profile'] = {k: str(rows[0][k]).strip()[:100] for k in ('first_name', 'display_name')
                if isinstance(rows[0].get(k), str) and rows[0][k].strip()}
        result['profile_available'] = True
    except Exception:
        logger.info('Chat profile unavailable; inventory remains authoritative')
        result['profile_available'] = False
    from app.services.response_feedback import learning_guidance
    result['feedback_guidance'] = learning_guidance(actor)
    return result


def inventory_aliases(actor, inventory):
    from app.services.inventory_scope import current_inventory
    scope = current_inventory.get()
    if scope is None or scope.actor_id != actor or scope.inventory_id != inventory:
        return []
    # The existing preference service respects the account's memory switch and
    # only returns explicitly confirmed aliases in the currently authorized scope.
    return load_preferences(actor).get('aliases', [])
