"""Handle explicit Space requests and spreadsheet review using verified draft state."""
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


REVIEW_REQUEST = 'Help me review this extraction and choose where to save it.'


def spreadsheet_request(draft, message):
    if not draft or draft.get('source_kind') != 'spreadsheet' or draft.get('status') != 'draft':
        return False
    return message.strip() == REVIEW_REQUEST or bool(space_name(message))


def review(draft):
    rows = draft['items']
    selected = sum(bool(row['selected']) for row in rows)
    if not selected:
        instruction = 'Select the rows you want to keep.'
    elif draft.get('space_id'):
        instruction = 'Review the selected rows, then tap Save items when you’re ready.'
    else:
        instruction = 'Tap Choose a Space, or tell me the name of a new Space.'
    return {'assistant_message': f'Your spreadsheet draft has {selected} of {len(rows)} rows selected. {instruction}',
            'answer_context': {'chat_capture_id': draft['id']}}


def prepare(actor, world, name, *, supports_task_actions, capture=None):
    from app.services import world_chat as w

    known = w.directory(actor, world)
    draft = capture['draft'] if capture else None

    def reply(text):
        return {'assistant_message': text, 'answer_context': {
            'chat_capture_id': draft['id']} if draft else {}}

    inventories = known['inventories']
    ids = [i['inventory_id'] for i in inventories]
    # Check every authorized inventory without putting hundreds of IDs into one
    # request URL. Two distinct matches already make this choice ambiguous.
    matches = []
    for offset in range(0, len(ids), 50):
        rows = (w.get_supabase_raw().table('spaces').select('id,name,inventory_id')
                .in_('inventory_id', ids[offset:offset + 50]).ilike('name', name.replace('_', r'\_'))
                .limit(2).execute().data or [])
        matches.extend(s for s in rows if s['name'].casefold() == name.casefold())
        if len(matches) > 1:
            break
    if len(matches) > 1:
        return reply(f'Multiple Spaces are named "{name}". Tap Choose a Space to select the right one.') if draft else None
    if matches:
        space = matches[0]
        # Reauthorize before presenting a saved destination from metadata.
        target = w.inventory_scope(actor, world, space['inventory_id'])
        if draft:
            if not target['can_edit']:
                return reply(f'You have view-only access to "{name}". Choose a Space you can edit.')
            from app.services.chat_capture import edit
            capture['draft'] = edit(actor, world, capture['cid'], draft['id'], draft['revision'],
                                    {'inventory_id': space['inventory_id'], 'space_id': space['id']})
            return reply(f'Your draft now points to "{space["name"]}". Review the rows and tap Save items when ready.')
        return {'assistant_message': f'A Space named "{space["name"]}" already exists.',
                'answer_context': {'world_actions': [], 'pending_actions': [],
                    'resource_links': [], 'operation_diagnostics': [
                        {'operation': 'world_space_creation_lookup', 'read_only': True,
                         'result': 'not_observed'}]}}

    if known.get('hierarchy') == 'organization_spaces':
        if not known['can_create_space']:
            return reply('You need permission to create a Space here. Choose an existing Space you can edit.')
        args = {'spaces': [{'name': name}] if supports_task_actions else [name]}
        return proposal(actor, world, name, args, supports_task_actions, draft)

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
    return proposal(actor, world, name, args, supports_task_actions, draft)


def proposal(actor, world, name, args, supports_task_actions, draft):
    from app.services import world_chat as w
    tool = 'world_create_task' if supports_task_actions else 'world_structure'
    # Existing validation and confirmation remain the only write path. This
    # call prepares a proposal and rechecks access, but creates no Space/items.
    result = w.execute(actor, world, tool, args)
    action = result['world_action']
    if action.get('status') != 'pending' or result.get('saved') is not False:
        raise RuntimeError('The Space proposal could not be confirmed')
    return {'assistant_message': f'Ready to create "{name}". Review the confirmation below.',
            'answer_context': {**({'chat_capture_id': draft['id']} if draft else {}),
                'world_actions': [action], 'pending_actions': [],
                'resource_links': [], 'operation_diagnostics': [
                    {'operation': 'world_space_creation_lookup', 'read_only': True,
                     'result': 'not_observed'},
                    {'operation': tool, 'read_only': False, 'result': 'proposal'}]}}
