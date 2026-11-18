"""Execute explicit edits using durable per-turn receipts and existing SQL guards."""
import re
from uuid import uuid5, NAMESPACE_URL
from fastapi import HTTPException
from app.services.supabase_client import get_supabase_raw


def requested(message):
    # Questions, quoted document instructions and a bare acknowledgement do not
    # authorize direct changes. Ambiguous targets must still be resolved by tools.
    value = message.strip()
    if re.search(r'\b(?:do not|don.t|cancel|never mind|nevermind)\b', value, re.I):
        return False
    return bool(re.search(r'^(?:(?:can|could|would) you\s+)?(?:please\s+)?(?:move|rename|change|set|update|edit|increase|decrease|restock|add|mark|reserve|release|receive)\b|^(?:i|we)\s+(?:just\s+)?(?:used|received|bought|consumed|found|lost)\b|^actually\b', value, re.I))


def apply(actor, world, conversation_id, turn_id, ordinal, action):
    action_id = str(uuid5(NAMESPACE_URL, f'findez:direct:{actor}:{world}:{turn_id}:{ordinal}'))
    proposed = {**action, 'id': action_id, 'direct': True, 'turn_id': turn_id}
    try:
        result = get_supabase_raw().rpc('findez_world_direct_action', {
            'p_actor': actor, 'p_world': world, 'p_conversation': conversation_id,
            'p_turn': turn_id, 'p_action': proposed}).execute().data
    except Exception as error:
        if getattr(error, 'code', None) == '42501':
            raise HTTPException(403, 'Your access changed. No new change was applied.') from None
        if getattr(error, 'code', None) in ('P0002', '23514', '22023', '40001'):
            raise HTTPException(409, 'The item changed while I was checking it. Read its current details and try again.') from None
        # Unknown outcome is never translated into "nothing changed".
        raise HTTPException(502, 'I could not verify the result. Retry this request to check the same saved receipt.') from None
    if not isinstance(result, dict) or result.get('id') != action_id or result.get('status') != 'confirmed' or not result.get('receipt'):
        raise HTTPException(502, 'I could not verify the result. Retry this request to check its receipt.')
    from app.services.items_repo import invalidate_inventory_cache
    from app.services.world_chat import inventory_scope
    for inv in {result['inventory_id'], *(i.get('inventory_id', result['inventory_id']) for i in result['receipt']['items'])}:
        invalidate_inventory_cache(inventory_scope(actor, world, inv)['owner_user_id'])
    return {'pending_action': result, 'inventory_changed': True, 'receipt': result['receipt'],
            'next_step': 'This change is committed. Report the receipt; do not ask for confirmation.'}
