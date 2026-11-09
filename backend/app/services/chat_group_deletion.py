"""Resolve explicit all-by-name requests before preparing a reviewed deletion."""
import re
from uuid import UUID

from app.services.chat_item_actions import ChatProposalError, MAX_ITEMS, propose_deletion
from app.services.supabase_client import get_supabase_admin


class GroupSelectionError(ChatProposalError):
    """Safe, actionable selection feedback for the assistant."""


def _text(value):
    return str(value or '').strip().strip('\"\'').casefold()


def _request(message):
    match = re.fullmatch(
        r'\s*(?:(?:can|could|would) you\s+)?(?:please\s+)?(?:remove|delete)\s+'
        r'all\s+(?:the\s+)?(.{1,200}?)\s+(?:from|in)\s+(.{1,100}?)\s*[.!?]?\s*',
        message, re.I)
    if not match:
        return None
    return _text(match[1]), _text(match[2])


def _name_matches(requested, saved):
    name = _text(saved)
    # Only exact saved names or their simple plural, never aliases or fuzzy rank.
    return bool(name) and requested in (name, name + 's')


def _literal(value):
    return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')


def prepare(actor, world, message, args, trace):
    """Return a read-only proposal, or None for the normal singular selection path.

    A model-visible preview may omit IDs. Resolve the entire exact named group
    again in its authorized Space rather than treating that preview as all stock.
    """
    request = _request(message)
    if request is None:
        return None
    from app.services import world_chat as w
    w.DeleteItems.model_validate(args, strict=True)
    inventory_id = str(UUID(args['inventory_id']))
    ids = [str(UUID(value)) for value in args['item_ids']]
    if len(set(ids)) != len(ids):
        raise GroupSelectionError('Choose distinct saved items from a fresh search.')
    requested_name, requested_space = request
    observed = {}
    for entry in trace:
        if entry.get('tool') not in ('world_query', 'world_search', 'world_inventory'):
            continue
        for row in entry.get('result', {}).get('items', []):
            if row.get('inventory_id') == inventory_id:
                observed[row.get('item_id')] = row
    seeds = [observed.get(identity) for identity in ids]
    if not seeds or any(not row or not _name_matches(requested_name, row.get('name')) for row in seeds):
        raise GroupSelectionError('Search the exact requested item name in the requested Space before proposing deletion. Do not use unrelated or approximate matches.')
    names = {row['name'] for row in seeds}
    space_ids = {row.get('space_id') for row in seeds}
    if len(names) != 1 or len(space_ids) != 1 or None in space_ids:
        raise GroupSelectionError('Choose one exact saved item name and one Space before preparing the group for review.')
    name, space_id = next(iter(names)), next(iter(space_ids))
    with w.in_inventory(actor, world, inventory_id) as inv:
        if not inv['can_edit']:
            raise GroupSelectionError('You have view-only access to this inventory.')
        client = get_supabase_admin()
        spaces = client.table('spaces').select('id,name').eq('id', space_id).limit(1).execute().data or []
        if len(spaces) != 1 or _text(spaces[0]['name']) != requested_space:
            raise GroupSelectionError('The selected Space does not match the requested destination. Ask which Space before proposing deletion.')
        def selection():
            return (client.table('items').select('item_id,name,space_id')
                .eq('space_id', space_id).ilike('name', _literal(name))
                .order('item_id').limit(MAX_ITEMS + 1).execute().data)
        rows = selection()
        if not isinstance(rows, list) or not rows:
            raise GroupSelectionError('No matching saved items remain in that Space. Search again before proposing deletion.')
        if len(rows) > MAX_ITEMS:
            raise GroupSelectionError('More than 100 items match. Ask for a smaller selection; do not describe a partial preview as all matching items.')
        if any(row.get('space_id') != space_id or _text(row.get('name')) != _text(name) for row in rows):
            raise GroupSelectionError('The matching selection could not be verified. Search again before proposing deletion.')
        full_ids = [row['item_id'] for row in rows]
        if not set(ids).issubset(full_ids):
            raise GroupSelectionError('Some selected items changed or moved. Search again before proposing deletion.')
        result = propose_deletion(user_id=inv['owner_user_id'], item_ids=full_ids)
        # Detect a changed selection around the fingerprint snapshot. Later edits
        # are still rejected by the existing confirmation transaction.
        if selection() != rows or any(_text(row.get('name')) != _text(name)
                                      for row in result['pending_action']['items']):
            raise GroupSelectionError('The selection changed while preparing review. Search again before proposing deletion.')
        result['pending_action']['world'] = world
        result['pending_action']['destination_label'] = inv['workspace']['name'] + ' / ' + inv['name']
        return {'selected_count': len(full_ids), 'selection_complete': True,
                'selection_name': name, 'selection_space': spaces[0]['name'], **result}
