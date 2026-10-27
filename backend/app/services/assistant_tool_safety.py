"""Validate caller tools against their existing schemas and the actual user turn."""
import json
import re


READ_TOOLS = frozenset(('inventory_search', 'inventory_knowledge_search',
                        'inventory_recall', 'documents_list', 'list_spaces',
                        'inventory_query', 'project_kit_readiness',
                        'world_directory', 'world_search', 'world_inventory', 'world_spaces',
                        'world_tracking', 'world_reorders', 'world_query', 'world_projects',
                        'world_project_readiness', 'world_activity', 'world_recall', 'world_item_photos'))
SAFE_EDIT_FIELDS = frozenset(('name', 'category', 'location', 'notes'))
_ACTION = r'^\s*(?:(?:can|could|would) you\s+)?(?:please\s+)?(?:move|rename|change|set|update|edit|add|delete|remove|create|increase|decrease|restock|log)\b'


def mutation_requested(message):
    return bool(re.search(_ACTION, message, re.I))


def _valid(value, schema):
    kind = schema.get('type')
    if kind == 'object':
        if not isinstance(value, dict):
            return False
        properties = schema.get('properties')
        if properties is None:
            return True
        return (not (set(value) - set(properties))
                and all(key in value for key in schema.get('required', []))
                and all(_valid(v, properties[k]) for k, v in value.items()))
    if kind == 'array':
        return (isinstance(value, list) and len(value) <= schema.get('maxItems', 12)
                and all(_valid(item, schema['items']) for item in value))
    if kind == 'string':
        return isinstance(value, str) and len(value) <= 2000 and ('enum' not in schema or value in schema['enum'])
    if kind == 'integer':
        return isinstance(value, int) and not isinstance(value, bool) and abs(value) <= 1_000_000
    return False


def rejection(*, tool_name, args, definitions, enabled, message, trace):
    schema = next((tool['function']['parameters'] for tool in definitions
                   if tool['function']['name'] == tool_name), None)
    if not enabled or schema is None:
        return 'This operation was not enabled for this request. No change was made.'
    if not _valid(args, schema):
        return 'The requested operation had invalid arguments. No change was made.'
    if tool_name in READ_TOOLS:
        return None
    from app.services.inventory_scope import current_inventory
    scope = current_inventory.get()
    if scope is not None and not scope.can_edit:
        return 'You have view-only access to this inventory. No change was made.'
    if tool_name in ('inventory_propose_add', 'inventory_propose_delete'):
        return None  # A proposal is read-only; confirmation has a separate server transaction.
    # These established write services do not have durable chat request receipts
    # or atomic quantity/event updates. A model cannot manufacture confirmation.
    if tool_name in ('inventory_add_item', 'inventory_log_event', 'create_space'):
        return 'Use Capture or the item editor to confirm this change safely. Chat cannot safely retry this operation, so no change was made.'
    if tool_name in ('inventory_delete_item', 'inventory_delete_by_filter'):
        return 'Deletion needs a reviewed selection and confirmation. Open the item or inventory editor to confirm deletion. No items were deleted.'
    if tool_name != 'inventory_update_item':
        return 'This chat operation is unavailable. No change was made.'
    if not mutation_requested(message):
        return 'Please explicitly request the edit and give the item and new value. No change was made.'
    updates = args.get('updates')
    if not isinstance(updates, dict) or len(updates) != 1 or set(updates) - SAFE_EDIT_FIELDS:
        return 'Use the item editor for quantities, identifiers, photos or other fields. No change was made.'
    if not all(isinstance(value, str) and value.strip() and value.casefold() in message.casefold()
               for value in updates.values()):
        return 'Please give the exact new value instead of an inferred value. No change was made.'
    matches = []
    for entry in trace:
        if entry.get('tool') == 'inventory_search' and isinstance(entry.get('result'), list):
            matches = entry['result']
        elif entry.get('tool') == 'inventory_query' and isinstance(entry.get('result'), dict):
            matches = entry['result'].get('items', []) if entry['result'].get('complete') else []
        elif entry.get('tool') == 'inventory_knowledge_search' and isinstance(entry.get('result'), dict):
            result = entry['result']
            matches = (result.get('personal_items') or []) + (result.get('shared_and_joined_items') or [])
    if len(matches) != 1 or matches[0].get('item_id') != args.get('item_id'):
        return 'Choose one item from a fresh inventory search before editing it. No change was made.'
    name = matches[0].get('name')
    field, value = next(iter(updates.items()))
    assignment = re.search(r'(?:\bto\s+|[:=]\s*)["\']?' + re.escape(value) + r'["\']?[.!?]?\s*$', message, re.I)
    target = message[:assignment.start()] if assignment else ''
    verb = re.search(r'\b(move|rename|change|set|update|edit|add)\b', target, re.I)
    target_name = target[verb.end():].strip() if verb else ''
    verb = verb.group().casefold() if verb else ''
    if (verb == 'move' and field != 'location' or verb == 'rename' and field != 'name'
            or verb not in ('move', 'rename') and not re.search(r'\b' + ('notes?' if field == 'notes' else field) + r'\b', target, re.I)):
        return 'Please specify one field and its exact new value. No change was made.'
    if verb not in ('move', 'rename'):
        target_name = re.sub(r'\s+' + ('notes?' if field == 'notes' else field) + r'\s*$', '', target_name, flags=re.I)
    target_name = target_name.strip(' "\'')
    names = {target_name.casefold(), re.sub(r'^(my|the)\s+', '', target_name, flags=re.I).casefold()}
    if not isinstance(name, str) or not name.strip() or name.casefold() not in names:
        return 'Please name the exact saved item to edit. No change was made.'
    if any(entry.get('tool') not in READ_TOOLS for entry in trace):
        return 'Only one reviewed item edit is allowed per request. No further change was made.'
    return None


def fingerprint(tool_name, args):
    return tool_name + ':' + json.dumps(args, sort_keys=True, separators=(',', ':'))


def validate_model_answer(message, trace, text):
    """Reject false action claims; never substitute scripted assistant prose."""
    writes = [entry for entry in trace if entry.get('tool') not in READ_TOOLS]
    if not mutation_requested(message) and not writes:
        return
    confirmed = any(entry.get('tool') == 'inventory_update_item'
                    and isinstance(entry.get('result'), dict)
                    and entry['result'].get('item_id') and not entry['result'].get('error')
                    for entry in writes)
    confirmed = confirmed or any(
        isinstance(entry.get('result'), dict)
        and entry['result'].get('inventory_changed') is True
        and (entry['result'].get('pending_action') or {}).get('status') == 'confirmed'
        and isinstance(entry['result'].get('receipt'), dict)
        and entry['result']['receipt'].get('count', 0) > 0
        for entry in writes)
    if confirmed:
        return
    claims = re.search(r"(?:\b(?:i|we)(?:'ve| have)?\s+(?:successfully\s+)?|^)(?:moved|saved|updated|deleted|removed|created|added|attached|renamed|reserved|ordered|scheduled|logged|changed)\b", text, re.I)
    if claims:
        raise RuntimeError('The model claimed an action without a confirmed receipt')


def provider_data(value):
    """Bound untrusted tool data and omit private transport/storage references."""
    remaining = 12_000
    excluded = {'image_url', 'storage_path', 'photo_url', 'user_id',
                'owner_user_id', 'created_by_user_id', 'inventory_id', 'token', 'access_token'}
    def bounded(value, depth=0):
        nonlocal remaining
        if depth >= 6 or remaining <= 0:
            return '[data omitted]'
        if isinstance(value, str):
            text = re.sub(r'https?://\S+', '[saved link omitted]', value)[:min(1500, remaining)]
            remaining -= len(text)
            return text
        if isinstance(value, list):
            rows = []
            for row in value[:50]:
                if remaining <= 0:
                    break
                remaining -= 2
                rows.append(bounded(row, depth + 1))
            return rows if len(rows) == len(value) else {'records': rows, 'records_truncated': True}
        if isinstance(value, dict):
            result = {}
            for key, val in list(value.items())[:50]:
                if remaining <= 0:
                    result['fields_truncated'] = True
                    break
                if key not in excluded:
                    remaining -= len(str(key)) + 4
                    result[key] = bounded(val, depth + 1)
            return result
        remaining -= 20
        return value
    return bounded(value)
