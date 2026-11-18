"""Prepare simple standalone Space requests without model or item lookups."""
import re


def space_name(message):
    # Intentionally narrow. Compound requests, conditions, questions, and parent
    # destinations stay in the conversational path instead of losing intent.
    match = re.fullmatch(
        r'(?:please\s+)?(?:create|make|add|set up)\s+(?:a\s+)?(?:new\s+)?space\s+'
        r'(?:called|named)\s+([\w \-\'\"]{1,100})[.!]?',
        message.strip(), re.I,
    )
    if not match:
        return None
    name = match[1].strip()
    if name[:1] in ('"', "'"):
        if len(name) < 3 or name[-1] != name[0]:
            return None
        name = name[1:-1].strip()
    if not re.fullmatch(r'[\w]+(?:[ \-\'][\w]+)*', name):
        return None
    if len(name.split()) > 6 or re.search(
        r'\b(?:and|or|then|but|if|unless|not|never|don|in|under|inside|into|within|'
        r'for|with|without|please|instead|actually|create|delete|remove|move|add|'
        r'called|named|cancel|stop|it|that|this|same|there|later|tomorrow|after|'
        r'before|when|once|until|next)\b', name, re.I,
    ):
        return None
    return name


def prepare(actor, world, name, *, supports_task_actions):
    from app.services import world_chat as w

    known = w.directory(actor, world)
    inventories = known['inventories']
    # Never resolve from an incomplete set of matching destinations.
    if len(inventories) > 200:
        return None
    ids = [i['inventory_id'] for i in inventories]
    # Only Space identity metadata. No item rows, quantities, photos, or model.
    rows = (w.get_supabase_raw().table('spaces').select('id,name,inventory_id')
            .in_('inventory_id', ids).ilike('name', name.replace('_', r'\_'))
            .limit(201).execute().data or []) if ids else []
    if len(rows) > 200:
        return None
    matches = [s for s in rows if s['name'].casefold() == name.casefold()]
    if len(matches) > 1:
        return None
    if matches:
        space = matches[0]
        # Reauthorize before presenting a saved destination from metadata.
        w.inventory_scope(actor, world, space['inventory_id'])
        return {'assistant_message': f'A Space named "{space["name"]}" already exists.',
                'answer_context': {'world_actions': [], 'pending_actions': [],
                    'resource_links': [], 'operation_diagnostics': [
                        {'operation': 'world_space_creation_lookup', 'read_only': True,
                         'result': 'not_observed'}]}}

    matching_inventories = [i for i in inventories if i['name'].casefold() == name.casefold()]
    if len(matching_inventories) > 1:
        return None
    if matching_inventories:
        target = matching_inventories[0]
        if not target['can_edit']:
            return None
        workspace_id, inventory_name = target['workspace_id'], target['name']
    else:
        # Same destination policy as world_chat.DESTINATION_GUIDANCE.
        choices = [s for s in known['workspaces'] if s['can_create']
                   and (world != 'personal' or s['workspace_id'] == 'personal')]
        if len(choices) != 1:
            return None
        workspace_id, inventory_name = choices[0]['workspace_id'], name

    if not any(s['workspace_id'] == workspace_id and s['can_create'] for s in known['workspaces']):
        return None
    args = {'workspace_id': workspace_id,
            'inventories': [{'name': inventory_name, 'spaces': [name]}]}
    tool = 'world_create_task' if supports_task_actions else 'world_structure'
    # Existing validation and confirmation remain the only write path. This
    # call prepares a proposal and rechecks access, but creates no Space/items.
    result = w.execute(actor, world, tool, args)
    action = result['world_action']
    if action.get('status') != 'pending' or result.get('saved') is not False:
        raise RuntimeError('The Space proposal could not be confirmed')
    return {'assistant_message': f'Ready to create "{name}". Review the confirmation below.',
            'answer_context': {'world_actions': [action], 'pending_actions': [],
                'resource_links': [], 'operation_diagnostics': [
                    {'operation': 'world_space_creation_lookup', 'read_only': True,
                     'result': 'not_observed'},
                    {'operation': tool, 'read_only': False, 'result': 'proposal'}]}}
