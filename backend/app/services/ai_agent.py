from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import threading
import time
from collections.abc import Iterator
from typing import Any

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import list_recent_activity, list_documents
from app.services.items_repo import add_item, delete_item, search_items_basic, update_item


logger = logging.getLogger(__name__)


def _get_openai_client() -> OpenAI:
    try:
        return OpenAI(api_key=get_settings().openai_api_key)
    except Exception as e:
        logger.exception('Failed to initialize OpenAI client')
        raise RuntimeError('AI client initialization failed') from e


@dataclass
class _SessionState:
    last_item_name: str | None = None
    last_user_message: str | None = None
    updated_at: float = 0.0


_SESSION: dict[str, _SessionState] = {}
_LOCK = threading.Lock()


def _get_state(user_id: str) -> _SessionState:
    with _LOCK:
        if user_id not in _SESSION:
            _SESSION[user_id] = _SessionState(updated_at=time.time())
        return _SESSION[user_id]


def _json_dumps(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, default=str)


_SYSTEM_PROMPT = (
    "You are FindEZ Assist, a helpful, general-purpose AI assistant for an inventory app. "
    "You speak naturally and conversationally.\n\n"
    "SCOPE:\n"
    "You help with inventory tracking, everyday items, and projects. You can also help with DIY and (when relevant) robotics.\n"
    "Do not assume the user's domain. Only introduce a specific domain if the user mentions it or if the provided inventory/documents clearly reflect it.\n\n"
    "Never mention FTC or FIRST Tech Challenge unless the user explicitly brings it up or the provided inventory/documents clearly indicate it.\n\n"
    "FIRST-TIME / UNCLEAR REQUESTS:\n"
    "If this appears to be the first interaction (no prior user message in context) or the user's request is a generic greeting/unclear, respond with exactly: What are you working on today?\n\n"
    "When you need to interact with the user's inventory or documents, you may call the available tools.\n\n"
    "DECISION RULE:\n"
    "Do not call any tool unless absolutely necessary.\n"
    "Only call tools when the user explicitly wants to add, remove, update, or search for a specific inventory item.\n"
    "If the user is asking for advice, planning, or recommendations, respond directly using reasoning and the provided context.\n"
    "Do not search the inventory blindly for planning questions like 'what do I need' or 'what am I missing'.\n\n"
    "PLANNING MODE:\n"
    "If the user asks about:\n"
    "- building something\n"
    "- what they need\n"
    "- recommendations\n"
    "- missing items\n\n"
    "You MUST:\n"
    "- understand the goal\n"
    "- analyze current inventory\n"
    "- identify missing parts\n"
    "- suggest specific items\n"
    "- provide a simple plan\n\n"
    "Do not say you don't understand. Always try to help intelligently.\n\n"
    "FOLLOW-UP UNDERSTANDING:\n"
    "If the user asks a follow-up like 'what do I need', refer to their previous message and infer the goal.\n"
    "Answer based on the inferred goal and the provided context.\n\n"
    "ITEM DATA:\n"
    "Each inventory item may include: name, category, subcategory, brand, location, quantity, barcode, part_number, tags, and notes (free-text user notes about the item).\n"
    "When users ask about notes or details for a specific item, reference the notes field in the provided inventory context.\n"
    "Documents (receipts, manuals, warranties, images) are listed separately in the documents_preview section of the context and are not linked to individual items.\n\n"
    "Rules:\n"
    "- Do not mention tools, function names, schemas, or internal processing.\n"
    "- Do not output JSON to the user.\n"
    "- If you are missing details required to complete a request, ask a short clarifying question instead of guessing.\n"
    "- Always reflect the real outcome accurately.\n"
)


_TOOLS: list[dict[str, Any]] = [
    {
        'type': 'function',
        'function': {
            'name': 'inventory_search',
            'description': "Search the user's inventory for items matching a query.",
            'parameters': {
                'type': 'object',
                'properties': {
                    'query': {'type': 'string', 'description': 'Search query (name, location, notes, etc.).'},
                },
                'required': ['query'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'inventory_add_item',
            'description': "Add a new inventory item.",
            'parameters': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string', 'description': 'Item name.'},
                    'category': {'type': 'string', 'description': 'Item category.'},
                    'quantity': {'type': 'integer', 'description': 'Quantity to add.'},
                    'location': {'type': 'string', 'description': 'Where the item is stored.'},
                    'notes': {'type': 'string', 'description': 'Optional notes/attributes.'},
                    'barcode': {'type': 'string', 'description': 'Optional barcode.'},
                    'image_url': {'type': 'string', 'description': 'Optional image URL.'},
                    'purchase_source': {'type': 'string', 'description': 'Optional purchase source.'},
                },
                'required': ['name', 'category', 'quantity', 'location'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'inventory_update_item',
            'description': "Update an existing inventory item by item_id.",
            'parameters': {
                'type': 'object',
                'properties': {
                    'item_id': {'type': 'string', 'description': 'The item_id to update.'},
                    'updates': {
                        'type': 'object',
                        'description': 'Fields to update (name, category, quantity, location, notes, barcode, image_url, purchase_source).',
                    },
                },
                'required': ['item_id', 'updates'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'inventory_delete_item',
            'description': "Delete an inventory item by item_id.",
            'parameters': {
                'type': 'object',
                'properties': {
                    'item_id': {'type': 'string', 'description': 'The item_id to delete.'},
                },
                'required': ['item_id'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'documents_list',
            'description': "List the user's recent uploaded documents.",
            'parameters': {
                'type': 'object',
                'properties': {
                    'limit': {'type': 'integer', 'description': 'Maximum number of documents to return.'},
                },
                'required': [],
            },
        },
    },
]


def _load_context(*, user_id: str, first_name: str | None) -> dict:
    try:
        items = search_items_basic(user_id=user_id, q='')
    except Exception:
        logger.exception('Inventory load failed')
        items = []

    try:
        docs = list_documents(user_id=user_id)
    except Exception:
        logger.exception('Docs load failed')
        docs = []

    try:
        activity = list_recent_activity(user_id=user_id)
    except Exception:
        logger.exception('Activity load failed')
        activity = []

    st = _get_state(user_id)

    inventory_preview = items[:50] if isinstance(items, list) else []
    documents_preview = docs[:20] if isinstance(docs, list) else []
    activity_preview = activity[:10] if isinstance(activity, list) else []

    return {
        'user': {'first_name': first_name},
        'inventory_count': len(items) if isinstance(items, list) else 0,
        'inventory_preview': inventory_preview,
        'documents_preview': documents_preview,
        'recent_activity_preview': activity_preview,
        'memory': {'last_item_name': st.last_item_name, 'last_user_message': st.last_user_message},
    }


def _should_enable_tools(*, message: str) -> bool:
    text = (message or '').strip().lower()
    if not text:
        return False

    planning_phrases = (
        'what do i need',
        'what do we need',
        'what am i missing',
        'what should i build',
        'how do i make',
        'how do i build',
    )
    if any(p in text for p in planning_phrases):
        return False

    inventory_verbs_always = (
        'add ',
        'remove ',
        'delete ',
    )
    inventory_update_verbs = (
        'update ',
        'change ',
        'set ',
        'edit ',
        'move ',
        'rename ',
        'increase ',
        'decrease ',
    )
    inventory_queries = (
        'find ',
        'search ',
        'look for ',
        'where is ',
        'where are ',
        'do i have',
        'do we have',
        'list my inventory',
        'show my inventory',
        'show my items',
        'list my items',
    )

    if any(v in text for v in inventory_verbs_always):
        return True
    if any(q in text for q in inventory_queries):
        return True

    if any(v in text for v in inventory_update_verbs):
        inventory_context = (
            'inventory' in text
            or ' item' in text
            or 'items' in text
            or 'quantity' in text
            or 'qty' in text
            or 'location' in text
            or 'category' in text
            or 'notes' in text
            or 'barcode' in text
            or 'brand' in text
            or 'part' in text
        )
        return bool(inventory_context)

    return False


def _execute_tool_call(*, user_id: str, tool_name: str, args: dict) -> Any:
    if tool_name == 'inventory_search':
        query = (args.get('query') or '').strip()
        return search_items_basic(user_id=user_id, q=query)

    if tool_name == 'inventory_add_item':
        item = {
            'name': (args.get('name') or '').strip(),
            'category': (args.get('category') or '').strip(),
            'quantity': int(args.get('quantity') or 0),
            'location': (args.get('location') or '').strip(),
            'notes': (args.get('notes') or '').strip() or None,
            'barcode': (args.get('barcode') or '').strip() or None,
            'image_url': (args.get('image_url') or '').strip() or None,
            'purchase_source': (args.get('purchase_source') or '').strip() or None,
        }
        if not item['name'] or not item['category'] or not item['location']:
            raise ValueError('name, category, and location are required')
        if item['quantity'] < 0:
            item['quantity'] = 0
        return add_item(user_id=user_id, item=item)

    if tool_name == 'inventory_update_item':
        item_id = (args.get('item_id') or '').strip()
        updates = args.get('updates')
        if not item_id:
            raise ValueError('item_id is required')
        if not isinstance(updates, dict):
            raise ValueError('updates must be an object')
        return update_item(user_id=user_id, item_id=item_id, updates=updates)

    if tool_name == 'inventory_delete_item':
        item_id = (args.get('item_id') or '').strip()
        if not item_id:
            raise ValueError('item_id is required')
        return {'deleted': bool(delete_item(user_id=user_id, item_id=item_id))}

    if tool_name == 'documents_list':
        limit = args.get('limit', 50)
        try:
            limit_i = int(limit)
        except Exception:
            limit_i = 50
        if limit_i <= 0:
            limit_i = 50
        return list_documents(user_id=user_id, limit=limit_i)

    raise ValueError(f'Unknown tool: {tool_name}')


def _update_memory_from_trace(*, user_id: str, tool_trace: list[dict]) -> None:
    if not tool_trace:
        return

    st = _get_state(user_id)

    for entry in reversed(tool_trace):
        if not isinstance(entry, dict):
            continue
        if entry.get('tool') in {'inventory_add_item', 'inventory_update_item'}:
            result = entry.get('result')
            if isinstance(result, dict):
                name = result.get('name')
                if isinstance(name, str) and name.strip():
                    st.last_item_name = name.strip()
                    st.updated_at = time.time()
                    return


def _run_agent(*, user_id: str, message: str, first_name: str | None) -> dict:
    if not user_id:
        return {'tool': None, 'result': None, 'assistant_message': 'Missing user session.'}

    client = _get_openai_client()
    model = get_settings().openai_model

    context = _load_context(user_id=user_id, first_name=first_name)

    allow_tools = _should_enable_tools(message=message)

    messages: list[dict[str, Any]] = [
        {'role': 'system', 'content': _SYSTEM_PROMPT},
        {'role': 'system', 'content': f"CONTEXT:\n{_json_dumps(context)}"},
        {'role': 'user', 'content': message},
    ]

    tool_trace: list[dict[str, Any]] = []
    last_tool: str | None = None

    for _step in range(8):
        kwargs: dict[str, Any] = {
            'model': model,
            'messages': messages,
            'temperature': 0.3,
            'max_completion_tokens': 500,
        }
        if allow_tools:
            kwargs['tools'] = _TOOLS
            kwargs['tool_choice'] = 'auto'
        resp = client.chat.completions.create(**kwargs)

        msg = resp.choices[0].message
        tool_calls = getattr(msg, 'tool_calls', None) or []
        content = getattr(msg, 'content', None) or ''

        if tool_calls:
            assistant_tool_calls: list[dict[str, Any]] = []
            for tc in tool_calls:
                assistant_tool_calls.append(
                    {
                        'id': tc.id,
                        'type': 'function',
                        'function': {'name': tc.function.name, 'arguments': tc.function.arguments},
                    }
                )

            messages.append({'role': 'assistant', 'content': content, 'tool_calls': assistant_tool_calls})

            for tc in tool_calls:
                tool_name = tc.function.name
                args_raw = tc.function.arguments or '{}'
                try:
                    args = json.loads(args_raw) if args_raw else {}
                except Exception:
                    args = {}

                try:
                    result = _execute_tool_call(user_id=user_id, tool_name=tool_name, args=args if isinstance(args, dict) else {})
                except Exception as e:
                    logger.exception('Tool call failed: %s', tool_name)
                    result = {'success': False, 'error': str(e)}

                tool_trace.append({'tool': tool_name, 'args': args, 'result': result})
                last_tool = tool_name

                messages.append({'role': 'tool', 'tool_call_id': tc.id, 'content': _json_dumps(result)})

            continue

        assistant_message = content.strip()
        if not assistant_message:
            try:
                final_resp = client.chat.completions.create(
                    model=model,
                    messages=messages,
                    temperature=0.3,
                    max_completion_tokens=500,
                )
                final_msg = final_resp.choices[0].message
                assistant_message = (getattr(final_msg, 'content', None) or '').strip()
            except Exception:
                assistant_message = ''

        if not assistant_message:
            assistant_message = 'Let me think about that...'

        st = _get_state(user_id)
        st.last_user_message = message
        st.updated_at = time.time()
        _update_memory_from_trace(user_id=user_id, tool_trace=tool_trace)
        return {
            'tool': last_tool,
            'result': {'tool_trace': tool_trace},
            'assistant_message': assistant_message,
        }

    _update_memory_from_trace(user_id=user_id, tool_trace=tool_trace)

    assistant_message = ''
    try:
        final_resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.3,
            max_completion_tokens=500,
        )
        final_msg = final_resp.choices[0].message
        assistant_message = (getattr(final_msg, 'content', None) or '').strip()
    except Exception:
        assistant_message = ''

    if not assistant_message:
        assistant_message = 'Let me think about that...'

    st = _get_state(user_id)
    st.last_user_message = message
    st.updated_at = time.time()

    return {
        'tool': last_tool,
        'result': {'tool_trace': tool_trace},
        'assistant_message': assistant_message,
    }


def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None) -> Iterator[str]:
    def _evt(payload: dict) -> str:
        return f"data: {_json_dumps(payload)}\n\n"

    try:
        out = _run_agent(user_id=user_id, message=message, first_name=first_name)
        yield _evt({'type': 'delta', 'delta': out.get('assistant_message') or ''})
        yield _evt({'type': 'done', 'tool': out.get('tool'), 'result': out.get('result'), 'assistant_message': out.get('assistant_message') or ''})
    except Exception:
        logger.exception('Critical AI failure')
        yield _evt({'type': 'done', 'tool': None, 'result': None, 'assistant_message': 'Something went wrong. Please try again.'})


def run_ai_command(*, user_id: str, message: str, first_name: str | None = None) -> dict:
    return _run_agent(user_id=user_id, message=message, first_name=first_name)
