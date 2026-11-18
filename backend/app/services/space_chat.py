"""Space-only Ask, using existing model tools, saved history and reviewed writes."""
import asyncio
import base64
import json
import logging
import threading
from uuid import UUID
from dataclasses import replace

from fastapi import HTTPException
from fastapi.responses import StreamingResponse

from app.services.inventory_scope import current_inventory
from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)
TOOLS = frozenset({'inventory_search', 'inventory_query', 'inventory_update_item',
                   'inventory_propose_add', 'inventory_propose_delete', 'list_spaces',
                   'inventory_recall'})


def scope():
    value = current_inventory.get()
    return value if value and value.chat_space_id else None


def conversation_ids(raw, selected):
    # A private metadata-only record binds the Space in existing message context.
    # Keep world_key null: reviewed item transactions intentionally distinguish
    # inventory conversations from organization-wide world conversations.
    ids, offset = [], 0
    while True:
        rows = raw.table('messages').select('conversation_id,conversations!inner(user_id,inventory_id)').eq('inventory_id', selected.inventory_id).eq('conversations.user_id', selected.actor_id).eq('conversations.inventory_id', selected.inventory_id).contains('answer_context', {'space_chat': selected.chat_space_id}).order('id').range(offset, offset + 499).execute().data or []
        ids.extend(row['conversation_id'] for row in rows)
        if len(rows) < 500:
            return list(dict.fromkeys(ids))
        offset += 500


def prepare_conversation(user_id, message, conversation_id):
    from app.api.routes.ai import _prepare_ask_conversation
    selected = scope()
    if conversation_id:
        # Existing history is checked by InventoryClient before any new message.
        return _prepare_ask_conversation(user_id=user_id, message=message, conversation_id=conversation_id)
    # Create the metadata marker and question under the same actor/inventory authorization.
    # Its marker must exist before applying the narrower history lookup.
    token = current_inventory.set(replace(selected, chat_space_id=None, chat_space_name=None))
    try:
        client = get_supabase_admin()
        rows = client.table('conversations').insert({'user_id': user_id, 'title': message[:60]}).execute().data or []
        identity = (rows[0] if rows else {}).get('id')
        if not identity:
            raise RuntimeError('Conversation insert returned no identity')
        client.table('messages').insert({'conversation_id': identity, 'role': 'assistant', 'content': '',
            'answer_context': {'space_chat': selected.chat_space_id, 'space_chat_marker': True}}).execute()
        client.table('messages').insert({'conversation_id': identity, 'role': 'user', 'content': message}).execute()
        return identity
    finally:
        current_inventory.reset(token)


def guard_tool(name, args):
    selected = scope()
    if selected is None:
        return
    if name not in TOOLS:
        raise HTTPException(403, 'Use the main Ask for questions outside this Space.')
    if name == 'inventory_query':
        filters = dict(args.get('filters') or {})
        if filters.get('space_id', selected.chat_space_id) != selected.chat_space_id:
            raise HTTPException(403, 'This question is limited to the selected Space.')
        filters['space_id'] = selected.chat_space_id
        args['filters'] = filters
    if name == 'inventory_update_item':
        changes = args.get('updates') or {}
        if ('location' in changes and changes['location'] != selected.chat_space_name) or ('space_id' in changes and changes['space_id'] != selected.chat_space_id):
            raise HTTPException(403, 'Use Move on the item to choose another Space.')
    ids = args.get('item_ids', []) if name == 'inventory_propose_delete' else ([args.get('item_id')] if name in ('inventory_update_item', 'inventory_recall') else [])
    if ids:
        ids = [str(UUID(value)) for value in ids]
        rows = get_supabase_admin().table('items').select('item_id').in_('item_id', ids).execute().data or []
        if {row['item_id'] for row in rows} != set(ids):
            raise HTTPException(404, 'The selected item is no longer in this Space.')


def guard_action(action_id):
    selected = scope()
    if selected is None:
        return
    from app.services.supabase_client import get_supabase_raw
    rows = get_supabase_raw().table('messages').select('conversation_id,answer_context,conversations!inner(id,user_id,inventory_id)').eq('conversations.user_id', selected.actor_id).eq('conversations.inventory_id', selected.inventory_id).contains('answer_context', {'pending_actions': [{'id': action_id}]}).limit(1).execute().data or []
    if not rows or rows[0]['conversation_id'] not in conversation_ids(get_supabase_raw(), selected):
        raise HTTPException(404, 'This action is not part of this Space chat.')
    action = next((a for a in rows[0]['answer_context']['pending_actions'] if a.get('id') == action_id), None)
    if not action:
        raise HTTPException(404, 'This action is no longer available.')
    if action.get('status') == 'pending' and action.get('operation') == 'delete':
        guard_tool('inventory_propose_delete', {'item_ids': [i['item_id'] for i in action['items']]})
    if action.get('operation') == 'add' and any(i.get('space_id') != selected.chat_space_id for i in action['items']):
        raise HTTPException(403, 'This action has another destination Space.')


def model_kwargs(provider, messages, enabled, allow_item_actions, image=False):
    from app.core.config import get_settings
    from app.services.ai_agent import _TOOLS
    allowed = TOOLS if allow_item_actions else TOOLS - {'inventory_propose_add', 'inventory_propose_delete'}
    result = {'model': get_settings().findez_chat_vision_model if image else provider.model,
              'messages': messages, 'temperature': .3, 'stream': True, 'max_tokens': 8192,
              'extra_headers': {'X-Agent-Conversation-ID': provider.conversation_id,
                                'X-Agent-Timezone': provider.timezone}}
    if enabled:
        result.update(tools=[t for t in _TOOLS if t['function']['name'] in allowed],
                      tool_choice='auto', parallel_tool_calls=False)
    return result


def events(user_id, message, conversation_id, allow_item_actions, image_bytes=None, cancelled=None):
    from app.services import ai_agent
    from app.services.ask_presentation import answer_context_from_reads
    from app.services.assistant_tool_safety import provider_data
    from app.services.chat_item_actions import action_context
    selected = scope()
    if selected is None:
        raise RuntimeError('Space authorization is required')
    # No inventory-wide memory, other conversations, shared Spaces or projects.
    # Current rows are independently filtered in the repository, including tools.
    rows = ai_agent._current_items(user_id=user_id, q='')
    context = {'scope': {'space_id': selected.chat_space_id, 'name': selected.chat_space_name},
               'inventory_read_status': 'available', 'inventory_count': len(rows),
               'inventory_preview': rows[:30]}
    history = ai_agent._question_history(user_id=user_id, conversation_id=conversation_id,
        supplied=None, state=ai_agent._SessionState(), message=message)
    content = message
    if image_bytes:
        content = [{'type': 'text', 'text': message}, {'type': 'image_url', 'image_url': {
            'url': 'data:image/jpeg;base64,' + base64.b64encode(image_bytes).decode()}}]
    messages = [{'role': 'system', 'content': ai_agent._SYSTEM_PROMPT +
        '\nThis chat is restricted to the selected Space. Retrieve current facts with its tools. '
        'Do not infer facts about other Spaces or use old conversation statements as current inventory evidence. '
        'Use main Ask for organization-wide work. Do not create Spaces or move items elsewhere. '
        'Item additions/deletions require the existing explicit review card; no proposal is a completed write. '
        'An attached photo is evidence only and never permission to save.'},
        {'role': 'system', 'content': 'CONTEXT:\n' + json.dumps(provider_data(context), default=str)},
        *history, {'role': 'user', 'content': content}]
    provider = ai_agent._get_chat_provider(conversation_id)
    def model_call(messages, enabled):
        return provider.client.chat.completions.create(**model_kwargs(provider, messages, enabled, allow_item_actions, bool(image_bytes)))
    allowed = TOOLS if allow_item_actions else TOOLS - {'inventory_propose_add', 'inventory_propose_delete'}
    for event in ai_agent.iter_model_turn(user_id=user_id, message=message, messages=messages,
                                         model_call=model_call, allowed_tools=allowed, cancelled=cancelled):
        if event['type'] != 'model_done':
            yield event
            continue
        trace = event['tool_trace']
        answer = answer_context_from_reads(context, trace)
        answer['pending_actions'] = action_context(trace)
        yield {'type': 'done', 'assistant_message': event['assistant_message'], 'answer_context': answer}


async def response(*, user, message, conversation_id, allow_item_actions, image_bytes=None):
    from app.api.routes.ai import _save_ask_answer, _authorized_stream
    from app.services.limits import check_and_increment_chat, check_and_increment_scan, ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded
    try:
        if image_bytes:
            await asyncio.to_thread(check_and_increment_scan, user.user_id)
        await asyncio.to_thread(check_and_increment_chat, user.user_id)
    except (ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded):
        raise HTTPException(403, 'Your account photo or chat allowance has been reached.')
    conv_id = await asyncio.to_thread(prepare_conversation, user.user_id, message, conversation_id)
    effective_user_id = user.user_id
    async def generate():
        # next() in a worker preserves the validated ContextVars. Keeping one
        # iteration pending applies backpressure and avoids orphaned generators.
        stopped = threading.Event()
        iterator = events(effective_user_id, message, conv_id, allow_item_actions, image_bytes, stopped.is_set)
        def step():
            return next(iterator, None)
        try:
            while True:
                event = await asyncio.to_thread(step)
                if event is None:
                    break
                if event['type'] == 'done':
                    receipt = await asyncio.to_thread(_save_ask_answer, conversation_id=conv_id, answer=event)
                    event.update(conversation_id=conv_id, **(receipt if isinstance(receipt, dict) else {}))
                yield ('data: ' + json.dumps(event) + '\n\n').encode()
            yield b'data: [DONE]\n\n'
        except Exception:
            logger.exception('Space answer failed')
            yield b'data: {"type":"error","error":"Your Space answer could not be completed. Please retry."}\n\n'
            yield b'data: [DONE]\n\n'
        finally:
            stopped.set()
            # An in-flight synchronous request finishes on cancellation; do not
            # close an executing generator from another thread.
            if not iterator.gi_running:
                iterator.close()
    return StreamingResponse(_authorized_stream(generate()), media_type='text/event-stream',
                             headers={'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no'})
