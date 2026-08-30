
import asyncio
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
import logging
import threading
import time
import re
from uuid import uuid4
import json as _json_dumps
from typing import Any, Iterator

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import list_recent_activity, list_documents
from app.services.item_events_repo import get_events_for_item, log_event
from app.services.items_repo import add_item, delete_item, search_items_basic, update_item
from app.services.spaces_repo import SpaceLimitExceeded


logger = logging.getLogger(__name__)


def _matches_knowledge_query(row: dict, query: str) -> bool:
    raw_tokens = re.findall(r'[a-z0-9][a-z0-9._-]*', (query or '').lower())
    generic_tokens = {
        'a', 'an', 'the', 'my', 'our', 'is', 'are', 'where', 'which', 'what',
        'find', 'locate', 'show', 'open', 'please', 'project', 'projects', 'kit', 'kits',
    }
    tokens = [token for token in raw_tokens if token not in generic_tokens]
    if not tokens:
        return True
    searchable = ' '.join(str(row.get(key) or '') for key in (
        'name', 'category', 'subcategory', 'brand', 'location', 'part_number',
        'barcode', 'notes', 'tags', 'space_name', 'access',
    )).lower()
    return all(token in searchable for token in tokens)


def _inventory_knowledge(*, user_id: str, query: str = '') -> dict:
    """Return live, access-scoped inventory structure for read-only AI answers."""
    from app.services.sharing_service import get_joined_shares, get_my_shares, get_share_inventory
    from app.services.spaces_repo import list_spaces
    from app.services.supabase_client import get_supabase_admin

    personal_items = search_items_basic(user_id=user_id, q=query)
    personal_spaces = list_spaces(user_id=user_id)
    owned_shares = get_my_shares(user_id=user_id) or []
    joined_memberships = get_joined_shares(user_id=user_id) or []

    spaces: list[dict] = [
        {
            'space_id': space.get('id'),
            'name': space.get('name'),
            'item_count': space.get('item_count', 0),
            'kind': 'personal',
            'access': 'owner',
        }
        for space in personal_spaces
    ]
    accessible_shares: dict[str, dict] = {}
    for share in owned_shares:
        share_id = str(share.get('share_id') or share.get('id') or '')
        if not share_id:
            continue
        info = {
            'share_id': share_id,
            'name': share.get('share_name') or 'Shared Space',
            'kind': 'shared',
            'access': 'owner',
            'permission': 'edit',
            'member_count': share.get('member_count', 0),
        }
        accessible_shares[share_id] = info
        matching_space = next(
            (space for space in spaces if str(space.get('name') or '').strip().lower()
             == str(info['name']).strip().lower()),
            None,
        )
        if matching_space:
            matching_space.update(info)
        else:
            spaces.append(info)
    for membership in joined_memberships:
        share = membership.get('team_shares') or {}
        if not isinstance(share, dict) or not share.get('is_active', True):
            continue
        share_id = str(share.get('share_id') or membership.get('share_id') or '')
        if not share_id:
            continue
        permission = share.get('permission') or 'view'
        info = {
            'share_id': share_id,
            'name': share.get('share_name') or 'Joined Space',
            'kind': 'joined',
            'access': 'member',
            'permission': permission,
        }
        accessible_shares[share_id] = info
        spaces.append(info)

    owned_shared_names = {
        str(info['name']).strip().lower(): info
        for info in accessible_shares.values() if info['kind'] == 'shared'
    }
    personal_items = [
        {
            **item,
            'space_name': item.get('location') or 'Unsorted',
            'space_kind': (
                owned_shared_names.get(str(item.get('location') or '').strip().lower(), {})
                .get('kind', 'personal')
            ),
            'access': 'owner',
            'share_id': (
                owned_shared_names.get(str(item.get('location') or '').strip().lower(), {})
                .get('share_id')
            ),
        }
        for item in personal_items
    ]

    shared_items: list[dict] = []
    for share_id, info in accessible_shares.items():
        if info['kind'] != 'joined':
            continue
        inventory = get_share_inventory(requesting_user_id=user_id, share_id=share_id) or []
        matching = [item for item in inventory if _matches_knowledge_query(item, query)]
        shared_items.extend({
            **item,
            'share_id': share_id,
            'space_name': info['name'],
            'space_kind': info['kind'],
            'access': info['access'],
            'permission': info['permission'],
        } for item in matching)

    client = get_supabase_admin()
    kit_fields = 'id,name,location,share_id,owner_user_id,created_by_user_id,updated_at'
    raw_kits = client.table('project_kits').select(
        kit_fields
    ).eq('created_by_user_id', user_id).is_('share_id', 'null').execute().data or []
    for share_id in accessible_shares:
        raw_kits.extend(client.table('project_kits').select(
            kit_fields
        ).eq('share_id', share_id).execute().data or [])
    kits: list[dict] = []
    for kit in raw_kits:
        share_id = str(kit.get('share_id') or '')
        is_personal = not share_id and kit.get('created_by_user_id') == user_id
        if not is_personal and share_id not in accessible_shares:
            continue
        lines = client.table('project_kit_items').select(
            'name,part_number,brand,required_quantity'
        ).eq('kit_id', kit['id']).execute().data or []
        searchable_kit = {
            **kit,
            'notes': ' '.join(
                f"{line.get('name', '')} {line.get('part_number', '')} {line.get('brand', '')}"
                for line in lines
            ),
        }
        if not _matches_knowledge_query(searchable_kit, query):
            continue
        space_info = accessible_shares.get(share_id)
        kits.append({
            'project_kit_id': kit.get('id'),
            'name': kit.get('name'),
            'location': kit.get('location'),
            'share_id': kit.get('share_id'),
            'space_name': (space_info or {}).get('name') or kit.get('location'),
            'space_kind': (space_info or {}).get('kind') or 'personal',
            'access': (space_info or {}).get('access') or 'owner',
            'line_count': len(lines),
            'items': lines,
            'updated_at': kit.get('updated_at'),
        })

    return {
        'query': query,
        'spaces': spaces,
        'personal_items': personal_items,
        'shared_and_joined_items': shared_items,
        'project_kits': kits,
    }


def _knowledge_navigation_hint(result: dict, query: str = '') -> dict | None:
    kits = result.get('project_kits') or []
    if len(kits) == 1:
        kit = kits[0]
        return {
            'type': 'project_kit',
            'id': kit.get('project_kit_id'),
            'name': kit.get('name'),
            'space_name': kit.get('space_name') or kit.get('location'),
            'share_id': kit.get('share_id'),
        }

    items = [*(result.get('personal_items') or []), *(result.get('shared_and_joined_items') or [])]
    if len(items) == 1:
        item = items[0]
        return {
            'type': 'item',
            'id': item.get('item_id'),
            'name': item.get('name'),
            'space_name': item.get('space_name') or item.get('location') or 'Unsorted',
            'share_id': item.get('share_id'),
        }

    needle = (query or '').strip().lower()
    spaces = result.get('spaces') or []
    exact_spaces = [space for space in spaces if str(space.get('name') or '').strip().lower() == needle]
    if len(exact_spaces) == 1:
        space = exact_spaces[0]
        return {
            'type': 'space',
            'name': space.get('name'),
            'space_name': space.get('name'),
            'share_id': space.get('share_id'),
        }

    locations = {
        str(item.get('space_name') or item.get('location') or 'Unsorted').strip()
        for item in items
    }
    if items and len(locations) == 1:
        location = next(iter(locations))
        first = items[0]
        return {
            'type': 'space',
            'name': location,
            'space_name': location,
            'share_id': first.get('share_id'),
        }
    return None


def _navigation_hint_from_trace(tool_trace: list[dict]) -> dict | None:
    for entry in reversed(tool_trace):
        if entry.get('tool') == 'inventory_knowledge_search':
            result = entry.get('result') or {}
            if isinstance(result, dict):
                hint = _knowledge_navigation_hint(
                    result,
                    str((entry.get('args') or {}).get('query') or ''),
                )
                if hint:
                    return hint
    for entry in reversed(tool_trace):
        if entry.get('tool') in ('inventory_add_item', 'inventory_update_item'):
            location = (entry.get('args') or {}).get('location', '').strip()
            if not location:
                location = (((entry.get('args') or {}).get('updates') or {}).get('location') or '').strip()
            if not location:
                location = ((entry.get('result') or {}).get('location') or '').strip()
            if location:
                return {'type': 'space', 'name': location, 'space_name': location}
    return None


def _is_valid_uuid(val: str) -> bool:
    return bool(re.match(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        str(val).strip().lower()
    ))


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
    conversation_history: list[dict] = field(default_factory=list)


_SESSION: dict[str, _SessionState] = {}
_LOCK = threading.Lock()


def _load_session(user_id: str) -> _SessionState:
    """Load session from Supabase. Falls back to empty session on any error."""
    try:
        from app.services.supabase_client import get_supabase_admin
        supabase = get_supabase_admin()
        resp = supabase.table("conversation_sessions").select("*").eq("user_id", user_id).maybe_single().execute()
        if resp is None:
            return _SessionState(updated_at=time.time())
        data = resp.data
        if isinstance(data, dict):
            history = data.get("history") or []
            if not isinstance(history, list):
                history = []
            return _SessionState(
                conversation_history=history,
                last_item_name=data.get("last_item_name"),
                last_user_message=data.get("last_user_message"),
                updated_at=time.time(),
            )
    except Exception:
        logger.exception("Failed to load session from Supabase")
    return _SessionState(updated_at=time.time())


def _save_session(user_id: str, state: _SessionState) -> None:
    """Persist session to Supabase. Fire-and-forget (errors are logged, not raised)."""
    try:
        from app.services.supabase_client import get_supabase_admin
        supabase = get_supabase_admin()
        supabase.table("conversation_sessions").upsert({
            "user_id": user_id,
            "history": state.conversation_history,
            "last_item_name": state.last_item_name,
            "last_user_message": state.last_user_message,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }, on_conflict="user_id").execute()
    except Exception:
        logger.exception("Failed to save session to Supabase")


def _get_state(user_id: str) -> _SessionState:
    with _LOCK:
        if user_id not in _SESSION:
            _SESSION[user_id] = _load_session(user_id)
        return _SESSION[user_id]


def _persist_state(user_id: str) -> None:
    """Write current in-memory state to Supabase."""
    with _LOCK:
        state = _SESSION.get(user_id)
    if state:
        _save_session(user_id, state)


def _json_dumps(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, default=str)


MAX_HISTORY = 20
MAX_MSG_CHARS = 2000
_VALID_HISTORY_ROLES = {'user', 'assistant'}


def _sanitize_history(history: list[dict]) -> list[dict]:
    out = []
    for item in history:
        if not isinstance(item, dict):
            continue
        role = item.get('role')
        content = item.get('content')
        if role in _VALID_HISTORY_ROLES and isinstance(content, str):
            # Truncate any single message that is abnormally large
            if len(content) > MAX_MSG_CHARS:
                content = content[:MAX_MSG_CHARS] + '... [truncated]'
            out.append({'role': role, 'content': content})
    return out


_SYSTEM_PROMPT = (
    "You are FindEZ, an AI assistant built exclusively "
    "for inventory management. Your only purpose is to "
    "help users manage physical items they own. You are "
    "not a general assistant. You cannot help with "
    "anything outside of inventory.\n\n"

    "MEMORY & PERSONALIZATION:\n"
    "Your system context may include a section starting with "
    "'What I know about this user:' — if present, use this to "
    "personalize your responses naturally. Do not announce that "
    "you have memory or explain where the information came from. "
    "Just use it as if you naturally know the user.\n"
    "Your context may also include 'Relevant past conversations:' — "
    "if present, use this to give more accurate and consistent answers. "
    "If a user asks what you remember about them, summarize what is "
    "in your memory context naturally and warmly.\n"
    "The CONTEXT system message reflects the current live state of the user's inventory "
    "and always takes precedence over anything in memory or past conversations. "
    "If memory and CONTEXT disagree about an item's location, quantity, or existence, "
    "CONTEXT is correct. Never state an item's location or quantity from memory alone.\n\n"

    "BEFORE RESPONDING TO ANY MESSAGE:\n"
    "First check if the message matches ANY of these — if yes, respond helpfully, never refuse:\n"
    "- User shares personal context: their name, team name, role, "
    "location, organization, or how they use their inventory. "
    "Acknowledge it warmly in 1-2 sentences, then offer to help with inventory.\n"
    "- User asks what you remember, what they asked before, or what you know about them. "
    "Summarize their memory context and invite their inventory question.\n"
    "- User sends a greeting. Respond warmly and ask what they need.\n"
    "- User shares any detail about themselves or their life "
    "(homeowner, teacher, student, etc.). Acknowledge briefly, connect it "
    "to how you can help with their inventory, and move forward.\n\n"
    "Only if the message does NOT match any of the above AND is not about "
    "the user's physical inventory, items, spaces, quantities, or locations — "
    "respond with this exact sentence and nothing else:\n"
    "'That's not something I can help with — I'm only "
    "able to assist with your inventory.'\n"
    "Do not explain. Do not apologize. Do not engage "
    "with the request.\n\n"

    "The following ALWAYS get the refusal above, "
    "no exceptions:\n"
    "- Stories, fiction, or creative writing\n"
    "- Fitness, diet, workout, or health plans\n"
    "- Jokes, riddles, games, or trivia\n"
    "- Recipes (unless checking if an ingredient "
    "is in their inventory)\n"
    "- Coding, math, science, or homework help\n"
    "- News, politics, sports, or celebrities\n"
    "- Relationship, legal, or financial advice\n"
    "- Anything a general chatbot would answer "
    "that has nothing to do with physical items "
    "the user owns\n\n"

    "CONTENT RULES — NON-NEGOTIABLE:\n"
    "This app is rated 4+ on the Apple App Store. You must NEVER produce:\n"
    "- Sexually explicit descriptions, sexual storytelling, or graphic sexual content\n"
    "- Graphic violence or gore\n"
    "- Strong or offensive language\n"
    "- Promotion, glorification, or encouragement of alcohol or drug use\n"
    "- Horror or disturbing content\n"
    "- Any content inappropriate for children\n"
    "If asked for any of the above, respond with exactly:\n"
    "'I can't help with that. I'm your inventory assistant — ask me about "
    "your items, spaces, or what you own!'\n"
    "Do not explain, negotiate, or engage further with the request.\n\n"

    "SCOPE — what you CAN help with:\n"
    "- Finding, adding, updating, deleting items in the user's inventory\n"
    "- Answering questions about what the user owns\n"
    "- Checking if the user already owns something before they buy it\n"
    "- Organizing items by space, category, or location\n"
    "- Identifying low stock or duplicate items\n"
    "- Helping with DIY or robotics projects ONLY when directly related "
    "to items already in the user's inventory\n"
    "- Reviewing uploaded documents, receipts, and manuals\n\n"

    "SCOPE — what you must NEVER do:\n"
    "- Give fitness, health, diet, or medical advice\n"
    "- Write stories, poems, essays, or any creative content\n"
    "- Answer general knowledge questions unrelated to the user's inventory\n"
    "- Give relationship, legal, or financial advice\n"
    "- Discuss news, politics, or current events\n"
    "- Act as a general-purpose chatbot or assistant\n"
    "- Tell jokes, play games, or engage in casual chat\n"
    "- Give cooking or recipe advice unless the user "
    "is checking if they own an ingredient\n"
    "If asked about anything outside your scope, "
    "respond with this exact sentence and nothing else:\n"
    "'That's not something I can help with — I'm only "
    "able to assist with your inventory.'\n\n"

    "FIRST-TIME / UNCLEAR REQUESTS:\n"
    "If this appears to be the first interaction or the user's request "
    "is a generic greeting, respond with exactly: "
    "What are you looking for today?\n\n"

    "DECISION RULE:\n"
    "Do not call any tool unless absolutely necessary.\n"
    "Only call tools when the user explicitly wants to add, remove, "
    "update, or search for a specific inventory item.\n"
    "If the user is asking for advice, planning, or recommendations, "
    "respond directly using reasoning and the provided context.\n"
    "Do not search the inventory blindly for planning questions like "
    "'what do I need' or 'what am I missing'.\n\n"

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
    "If the user asks a follow-up like 'what do I need', refer to their "
    "previous message and infer the goal.\n"
    "Answer based on the inferred goal and the provided context.\n\n"

    "ITEM DATA:\n"
    "Each inventory item may include: name, category, subcategory, brand, "
    "location, quantity, barcode, part_number, tags, and notes.\n"
    "When users ask about notes or details for a specific item, reference "
    "the notes field in the provided inventory context.\n"
    "Documents (receipts, manuals, warranties, images) are listed "
    "separately in the documents_preview section of the context and are "
    "not linked to individual items.\n\n"

    "SPACES & PROJECT KITS:\n"
    "For questions about where something is, what a space contains, shared or joined "
    "spaces, or Project Kits, call inventory_knowledge_search. Its result is the live, "
    "access-scoped source of truth. State the exact space name and whether it is personal, "
    "shared, or joined. Project Kits are plans stored inside a space, not physical inventory "
    "items. Do not claim a kit or item exists when it is absent from the live result.\n\n"

    "RULES:\n"
    "- Do not mention tools, function names, schemas, or internal processing.\n"
    "- Do not output JSON to the user.\n"
    "- If you are missing details required to complete a request, ask a "
    "short clarifying question instead of guessing.\n"
    "- Always reflect the real outcome accurately.\n"
    "- When the user gives a clear instruction, execute it immediately. "
    "Do not ask for confirmation on obvious details like capitalization, "
    "spelling variations, or whether to proceed. Use your best judgment "
    "(title case for space/item names) and act. Only ask a clarifying "
    "question if critical information is genuinely missing (e.g. no "
    "quantity given, no location given).\n"
    "- Never ask the same clarifying question twice.\n\n"

    "CONVERSATION CONTEXT:\n"
    "You have access to the full conversation history above. Always "
    "maintain context from earlier in the conversation. If the user "
    "refers to something they mentioned before, reference it naturally. "
    "Remember names, items, locations, and preferences the user has "
    "mentioned throughout the conversation.\n\n"

    "ITEM EVENTS — INSTITUTIONAL MEMORY:\n"
    "When a user describes using items (e.g. 'we used 6 acrylic sheets'), "
    "notes something about an item, or reports a failure or success with an "
    "item (not just asking to add/search/delete), call inventory_search to "
    "find the item_id, then call inventory_log_event.\n"
    "When asked what happened with an item or what the team learned about it "
    "(e.g. 'what happened with the acrylic sheets', 'what do we know about X', "
    "'history of X'), call inventory_search first to get the item_id, "
    "then call inventory_recall.\n"
)


_TOOLS: list[dict[str, Any]] = [
    {
        'type': 'function',
        'function': {
            'name': 'inventory_knowledge_search',
            'description': (
                "Search the user's complete live inventory structure: personal, shared, and "
                "joined spaces; items and their exact locations; and Project Kits with their "
                "space and BOM lines. Use for every location, space, or Project Kit question."
            ),
            'parameters': {
                'type': 'object',
                'properties': {
                    'query': {
                        'type': 'string',
                        'description': 'Item, part number, barcode, space, or Project Kit search text. Use an empty string to list everything.',
                    },
                },
                'required': ['query'],
            },
        },
    },
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
            'name': 'inventory_delete_by_filter',
            'description': (
                "Delete multiple inventory items at once "
                "by location, category, or both. "
                "Use when the user asks to delete all "
                "items in a space or category."
            ),
            'parameters': {
                'type': 'object',
                'properties': {
                    'location': {
                        'type': 'string',
                        'description': (
                            'Delete all items in this '
                            'location e.g. Unsorted, Kitchen'
                        ),
                    },
                    'category': {
                        'type': 'string',
                        'description': (
                            'Delete all items in this '
                            'category e.g. Electronics, Food'
                        ),
                    },
                },
                'required': [],
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
    {
        'type': 'function',
        'function': {
            'name': 'inventory_log_event',
            'description': (
                "Log a usage, note, failure, success, or restock event for an inventory item. "
                "Call this when the user describes using items, notes something about an item, "
                "or reports a failure or success. If quantity_delta is provided (negative for "
                "consumption, positive for restocking), the item's quantity will also be updated."
            ),
            'parameters': {
                'type': 'object',
                'properties': {
                    'item_id': {'type': 'string', 'description': "The item's UUID (use inventory_search first to find it)."},
                    'event_type': {
                        'type': 'string',
                        'enum': ['usage', 'note', 'failure', 'success', 'restock', 'photo'],
                        'description': 'Type of event.',
                    },
                    'content': {'type': 'string', 'description': 'Description or note about the event.'},
                    'quantity_delta': {
                        'type': 'integer',
                        'description': 'Quantity change: negative for consumption (e.g. -6), positive for restocking. Omit if no quantity change.',
                    },
                },
                'required': ['item_id', 'event_type'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'inventory_recall',
            'description': (
                "Retrieve the event history for an inventory item. "
                "Call this when asked what happened with an item, what the team learned, "
                "or to recall past events, notes, or failures for a specific item."
            ),
            'parameters': {
                'type': 'object',
                'properties': {
                    'item_id': {'type': 'string', 'description': "The item's UUID (use inventory_search first to find it)."},
                },
                'required': ['item_id'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'create_space',
            'description': (
                "Create a new space (or return an existing one if the name already exists). "
                "Use when the user wants to create a space without adding an item."
            ),
            'parameters': {
                'type': 'object',
                'properties': {
                    'name': {'type': 'string', 'description': 'The space name.'},
                },
                'required': ['name'],
            },
        },
    },
    {
        'type': 'function',
        'function': {
            'name': 'list_spaces',
            'description': (
                "List all of the user's spaces, including empty ones, with item counts. "
                "Use this instead of inventory_search when the user asks about their spaces."
            ),
            'parameters': {
                'type': 'object',
                'properties': {},
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

    # Load shared and joined space items for AI context
    try:
        from app.services.sharing_service import (
            get_my_shares,
            get_joined_shares,
            get_share_inventory,
        )

        shared_items: list = []

        # Get spaces this user shared with others
        my_shares = get_my_shares(user_id=user_id)
        for share in (my_shares or []):
            try:
                share_id = share.get('share_id') or share.get('id')
                share_name = share.get('share_name', 'Shared Space')
                if share_id:
                    inv = get_share_inventory(requesting_user_id=user_id, share_id=share_id)
                    for item in (inv or []):
                        item['_shared_context'] = f'shared space: {share_name}'
                    shared_items.extend(inv or [])
            except Exception:
                pass

        # Get spaces this user has joined
        joined = get_joined_shares(user_id=user_id)
        for share in (joined or []):
            try:
                share_id = share.get('share_id') or share.get('id')
                share_name = (
                    share.get('share_name')
                    or (share.get('team_shares') or {}).get('share_name', 'Joined Space')
                )
                if share_id:
                    inv = get_share_inventory(requesting_user_id=user_id, share_id=share_id)
                    for item in (inv or []):
                        item['_shared_context'] = f'joined space: {share_name}'
                    shared_items.extend(inv or [])
            except Exception:
                pass

        # Limit to 50 shared items to avoid token overflow
        shared_items = shared_items[:50]

    except Exception:
        shared_items = []

    st = _get_state(user_id)

    # Truncate each item to essential fields only
    # to prevent token overflow
    def _trim_item(item):
        return {
            'name': item.get('name', ''),
            'category': item.get('category', ''),
            'location': item.get('location', ''),
            'quantity': item.get('quantity', 0),
            'item_id': item.get('item_id', ''),
        }

    def _trim_shared_item(item):
        return {
            'name': item.get('name', ''),
            'category': item.get('category', ''),
            'location': item.get('location', ''),
            'quantity': item.get('quantity', 0),
            'part_number': item.get('part_number', ''),
            '_shared_context': item.get('_shared_context', ''),
        }

    inventory_preview = [
        _trim_item(i) for i in
        (items[:30] if isinstance(items, list) else [])
    ]
    shared_inventory_preview = [_trim_shared_item(i) for i in shared_items]
    documents_preview = docs[:5] if isinstance(docs, list) else []
    activity_preview = activity[:5] if isinstance(activity, list) else []

    return {
        'user': {'first_name': first_name},
        'inventory_count': len(items) if isinstance(items, list) else 0,
        'inventory_preview': inventory_preview,
        'shared_inventory_preview': shared_inventory_preview,
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
        'get rid of',
        'throw away',
        'erase ',
        'clear ',
        'eliminate ',
        'discard ',
        'take out',
        'take off',
        'all items in',
        'everything in',
        'all of my',
        'items in ',
        'items from ',
        'located in',
        'items located',
        'clear all',
        'delete all',
        'remove all',
        'create space',
        'create a space',
        'new space',
        'make a space',
        'make space',
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
        'what do i have',
        'what do i own',
        'show me',
        'how many',
        'what is in',
        "what's in",
        'how much',
        'is there',
        'tell me about',
        'check my',
        'look up',
        'my spaces',
        'list spaces',
        'show spaces',
        'what spaces',
        'which spaces',
        'my inventory',
        'inventory have',
        'in my',
        'in the',
        'anything in',
        'whats in',
        'contents of',
        'project kit',
        'project kits',
        'kit is',
        'kit called',
        'which kit',
        'shared space',
        'joined space',
    )

    event_phrases = (
        'we used ',
        'i used ',
        'used up',
        'ran out of',
        'note about',
        ' failed ',
        ' broke ',
        ' worked ',
        'what happened with',
        'what do we know about',
        'what happened to',
        'history of',
        'recall ',
        'events for',
        'log a note',
        'note that ',
        'remember that',
        'we ran out',
        'it failed',
        'it worked',
        'last time',
        'last season',
    )

    if any(v in text for v in inventory_verbs_always):
        return True
    if any(q in text for q in inventory_queries):
        return True
    if any(p in text for p in event_phrases):
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
    if tool_name == 'inventory_knowledge_search':
        query = (args.get('query') or '').strip()
        return _inventory_knowledge(user_id=user_id, query=query)

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
        item['name'] = (item.get('name') or '').strip() or 'Unknown item'
        item['category'] = (item.get('category') or '').strip() or 'Other'
        item['location'] = (item.get('location') or '').strip() or 'Unsorted'
        if item['quantity'] < 0:
            item['quantity'] = 0
        try:
            created = add_item(user_id=user_id, item=item)
        except SpaceLimitExceeded:
            return {
                'error': 'space_limit_reached',
                'message': 'You\'ve reached the free plan limit of 3 spaces. Upgrade to Pro for unlimited spaces.',
            }
        return created

    if tool_name == 'inventory_update_item':
        item_id = (args.get('item_id') or '').strip()
        updates = args.get('updates')
        if not item_id:
            raise ValueError('item_id is required')
        if not _is_valid_uuid(item_id):
            logger.warning(f"Invalid UUID format for item_id: {item_id}")
            return {'error': 'Invalid item_id format'}
        if not isinstance(updates, dict):
            raise ValueError('updates must be an object')
        return update_item(user_id=user_id, item_id=item_id, updates=updates)

    if tool_name == 'inventory_delete_item':
        item_id = (args.get('item_id') or '').strip()
        if not item_id:
            raise ValueError('item_id is required')
        if not _is_valid_uuid(item_id):
            logger.warning(f"Invalid UUID format for item_id: {item_id}")
            return {'deleted': False, 'error': 'Invalid item_id format'}
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

    if tool_name == 'inventory_delete_by_filter':
        location = (args.get('location') or '').strip()
        category = (args.get('category') or '').strip()
        if not location and not category:
            return {'deleted': 0, 'error': 'No filter provided'}
        q = location or category
        items = search_items_basic(user_id=user_id, q=q)
        if not isinstance(items, list):
            return {'deleted': 0}
        matched = []
        for item in items:
            loc_match = (
                not location or
                (item.get('location') or '').strip().lower()
                == location.lower()
            )
            cat_match = (
                not category or
                (item.get('category') or '').strip().lower()
                == category.lower()
            )
            if loc_match and cat_match:
                matched.append(item)
        deleted_count = 0
        for item in matched:
            item_id = (item.get('item_id') or '').strip()
            if _is_valid_uuid(item_id):
                try:
                    success = delete_item(
                        user_id=user_id,
                        item_id=item_id
                    )
                    if success:
                        deleted_count += 1
                except Exception:
                    logger.exception(
                        'Bulk delete failed for %s', item_id
                    )
        return {
            'deleted': deleted_count,
            'total_found': len(matched),
        }

    if tool_name == 'inventory_log_event':
        item_id = (args.get('item_id') or '').strip()
        event_type = (args.get('event_type') or '').strip()
        content = (args.get('content') or '').strip() or None
        quantity_delta = args.get('quantity_delta')
        if not item_id or not _is_valid_uuid(item_id):
            return {'success': False, 'error': 'valid item_id is required'}
        if not event_type:
            return {'success': False, 'error': 'event_type is required'}
        qty_int: int | None = None
        if quantity_delta is not None:
            try:
                qty_int = int(quantity_delta)
            except Exception:
                qty_int = None
        event = log_event(
            user_id=user_id,
            item_id=item_id,
            event_type=event_type,
            content=content,
            quantity_delta=qty_int,
        )
        result: dict = {'event': event}
        if qty_int is not None:
            try:
                items = search_items_basic(user_id=user_id, q='')
                current_item = next(
                    (i for i in (items or []) if i.get('item_id') == item_id), None
                )
                if current_item:
                    current_qty = int(current_item.get('quantity') or 0)
                    new_qty = max(0, current_qty + qty_int)
                    update_item(user_id=user_id, item_id=item_id, updates={'quantity': new_qty})
                    result['quantity_updated'] = {'from': current_qty, 'to': new_qty, 'delta': qty_int}
            except Exception:
                logger.exception('Failed to update quantity after log_event')
        return result

    if tool_name == 'inventory_recall':
        item_id = (args.get('item_id') or '').strip()
        if not item_id or not _is_valid_uuid(item_id):
            return {'success': False, 'error': 'valid item_id is required'}
        events = get_events_for_item(user_id=user_id, item_id=item_id, limit=15)
        return {'events': events, 'count': len(events)}

    if tool_name == 'create_space':
        from app.services.spaces_repo import get_or_create_space
        name = (args.get('name') or '').strip()
        if not name:
            return {'error': 'name is required'}
        try:
            return get_or_create_space(user_id=user_id, name=name)
        except SpaceLimitExceeded:
            return {
                'error': 'space_limit_reached',
                'message': 'You\'ve reached the free plan limit of 3 spaces. Upgrade to Pro for unlimited spaces.',
            }

    if tool_name == 'list_spaces':
        from app.services.spaces_repo import list_spaces
        return list_spaces(user_id=user_id)

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


def _run_agent(*, user_id: str, message: str, first_name: str | None, conversation_history: list[dict] | None = None) -> dict:
    if not user_id:
        return {'tool': None, 'result': None, 'assistant_message': 'Missing user session.'}

    client = _get_openai_client()
    model = get_settings().openai_model

    allow_tools = _should_enable_tools(message=message)
    # Live inventory context must always be supplied. Planning and conversational
    # questions may not need tools, but they must never fall back to stale memory.
    context = _load_context(user_id=user_id, first_name=first_name)

    st = _get_state(user_id)

    history = _sanitize_history(conversation_history if conversation_history else st.conversation_history)
    if len(history) > MAX_HISTORY:
        history = history[-MAX_HISTORY:]

    messages: list[dict[str, Any]] = [
        {'role': 'system', 'content': _SYSTEM_PROMPT},
        {'role': 'system', 'content': f"CONTEXT:\n{_json_dumps(context)}"},
        *history,
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
                    max_completion_tokens=500,
                )
                final_msg = final_resp.choices[0].message
                assistant_message = (getattr(final_msg, 'content', None) or '').strip()
            except Exception:
                assistant_message = ''

        if not assistant_message:
            assistant_message = 'Let me think about that...'

        st.conversation_history.append({'role': 'user', 'content': message})
        st.conversation_history.append({'role': 'assistant', 'content': assistant_message})
        if len(st.conversation_history) > MAX_HISTORY:
            st.conversation_history = st.conversation_history[-MAX_HISTORY:]
        st.last_user_message = message
        st.updated_at = time.time()
        _update_memory_from_trace(user_id=user_id, tool_trace=tool_trace)
        _persist_state(user_id)
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
            max_completion_tokens=500,
        )
        final_msg = final_resp.choices[0].message
        assistant_message = (getattr(final_msg, 'content', None) or '').strip()
    except Exception:
        assistant_message = ''

    if not assistant_message:
        assistant_message = 'Let me think about that...'

    st.conversation_history.append({'role': 'user', 'content': message})
    st.conversation_history.append({'role': 'assistant', 'content': assistant_message})
    if len(st.conversation_history) > MAX_HISTORY:
        st.conversation_history = st.conversation_history[-MAX_HISTORY:]
    st.last_user_message = message
    st.updated_at = time.time()
    _persist_state(user_id)

    return {
        'tool': last_tool,
        'result': {'tool_trace': tool_trace},
        'assistant_message': assistant_message,
    }


def _iter_agent_streaming(
    *, user_id: str, message: str, first_name: str | None, conversation_history: list[dict] | None = None,
    memory_context: str | None = None,
) -> Iterator[dict]:
    """Run the agent loop with OpenAI stream=True.
    Yields {'type':'delta','delta':str} for each token as it arrives, then
    {'type':'done','tool':...,'result':...,'assistant_message':str} when complete."""
    client = _get_openai_client()
    model = get_settings().openai_model
    allow_tools = _should_enable_tools(message=message)
    # Streaming responses require the same authoritative live context as the
    # non-streaming path; memory is supplemental, never the source of truth.
    context = _load_context(user_id=user_id, first_name=first_name)
    st = _get_state(user_id)
    history = _sanitize_history(conversation_history if conversation_history else st.conversation_history)
    if len(history) > MAX_HISTORY:
        history = history[-MAX_HISTORY:]

    messages: list[dict[str, Any]] = [
        {'role': 'system', 'content': _SYSTEM_PROMPT},
        {'role': 'system', 'content': f"CONTEXT:\n{_json_dumps(context)}"},
    ]
    if memory_context:
        messages.append({'role': 'system', 'content': memory_context})
    messages += [
        *history,
        {'role': 'user', 'content': message},
    ]

    tool_trace: list[dict[str, Any]] = []
    last_tool: str | None = None
    full_text = ''

    # Up to 8 tool-using steps then a guaranteed text step (step 8, tools disabled)
    for _step in range(9):
        kwargs: dict[str, Any] = {
            'model': model,
            'messages': messages,
            'temperature': 0.3,
            'max_completion_tokens': 500,
            'stream': True,
        }
        if allow_tools and _step < 8:
            kwargs['tools'] = _TOOLS
            kwargs['tool_choice'] = 'auto'

        try:
            stream = client.chat.completions.create(**kwargs)
        except Exception:
            logger.exception('OpenAI streaming call failed at step %d', _step)
            break

        accumulated_content = ''
        accumulated_tool_calls: dict[int, dict[str, Any]] = {}

        for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta
            if delta.content:
                accumulated_content += delta.content
                yield {'type': 'delta', 'delta': delta.content}
            if delta.tool_calls:
                for tc_delta in delta.tool_calls:
                    idx = tc_delta.index
                    if idx not in accumulated_tool_calls:
                        accumulated_tool_calls[idx] = {
                            'id': '',
                            'type': 'function',
                            'function': {'name': '', 'arguments': ''},
                        }
                    if tc_delta.id:
                        accumulated_tool_calls[idx]['id'] = tc_delta.id
                    if tc_delta.function:
                        if tc_delta.function.name:
                            accumulated_tool_calls[idx]['function']['name'] += tc_delta.function.name
                        if tc_delta.function.arguments:
                            accumulated_tool_calls[idx]['function']['arguments'] += tc_delta.function.arguments

        if accumulated_tool_calls:
            tool_calls_list = [accumulated_tool_calls[k] for k in sorted(accumulated_tool_calls)]
            messages.append({
                'role': 'assistant',
                'content': accumulated_content,
                'tool_calls': tool_calls_list,
            })
            for tc in tool_calls_list:
                tool_name = tc['function']['name']
                args_raw = tc['function']['arguments'] or '{}'
                try:
                    args: Any = json.loads(args_raw) if args_raw else {}
                except Exception:
                    args = {}
                try:
                    result = _execute_tool_call(user_id=user_id, tool_name=tool_name, args=args if isinstance(args, dict) else {})
                except Exception as e:
                    logger.exception('Tool call failed: %s', tool_name)
                    result = {'success': False, 'error': str(e)}
                tool_trace.append({'tool': tool_name, 'args': args, 'result': result})
                last_tool = tool_name
                messages.append({'role': 'tool', 'tool_call_id': tc['id'], 'content': _json_dumps(result)})
            continue

        # No tool calls — text was streamed, we're done
        full_text = accumulated_content.strip()
        break

    final_text = full_text if full_text else 'Let me think about that...'
    try:
        st.conversation_history.append({'role': 'user', 'content': message})
        st.conversation_history.append({'role': 'assistant', 'content': final_text})
        if len(st.conversation_history) > MAX_HISTORY:
            st.conversation_history = st.conversation_history[-MAX_HISTORY:]
        st.last_user_message = message
        st.updated_at = time.time()
        _update_memory_from_trace(user_id=user_id, tool_trace=tool_trace)
        _persist_state(user_id)
    except Exception:
        logger.exception('Failed to persist agent state after streaming')

    nav_hint = _navigation_hint_from_trace(tool_trace)

    yield {'type': 'done', 'tool': last_tool, 'result': {'tool_trace': tool_trace}, 'assistant_message': final_text, 'nav_hint': nav_hint}


def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None, conversation_history: list[dict] | None = None) -> Iterator[str]:
    def _evt(payload: dict) -> str:
        return f"data: {_json_dumps(payload)}\n\n"

    try:
        for item in _iter_agent_streaming(user_id=user_id, message=message, first_name=first_name, conversation_history=conversation_history):
            if item.get('type') == 'delta':
                yield _evt({'type': 'delta', 'delta': item['delta']})
            elif item.get('type') == 'done':
                yield _evt({'type': 'done', 'tool': item.get('tool'), 'result': item.get('result'), 'assistant_message': item.get('assistant_message') or '', 'nav_hint': item.get('nav_hint')})
    except Exception:
        logger.exception('Critical AI failure')
        yield _evt({'type': 'done', 'tool': None, 'result': None, 'assistant_message': 'Something went wrong. Please try again.'})


async def iter_ai_command_events_async(
    *, user_id: str, message: str, first_name: str | None = None, conversation_history: list[dict] | None = None,
    memory_context: str | None = None,
):
    """Async raw-event generator — runs the sync agent in a background thread and yields
    raw event dicts (not SSE-formatted) into the asyncio event loop."""
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue(maxsize=128)
    SENTINEL = object()

    def _run_sync() -> None:
        try:
            for item in _iter_agent_streaming(
                user_id=user_id, message=message,
                first_name=first_name, conversation_history=conversation_history,
                memory_context=memory_context,
            ):
                asyncio.run_coroutine_threadsafe(queue.put(item), loop).result()
        except BaseException as exc:
            asyncio.run_coroutine_threadsafe(queue.put(exc), loop).result()
        finally:
            asyncio.run_coroutine_threadsafe(queue.put(SENTINEL), loop).result()

    thread = threading.Thread(target=_run_sync, daemon=True)
    thread.start()
    try:
        while True:
            item = await queue.get()
            if item is SENTINEL:
                break
            if isinstance(item, BaseException):
                raise item
            yield item
    finally:
        thread.join(timeout=10)


async def iter_ai_command_sse_async(
    *, user_id: str, message: str, first_name: str | None = None, conversation_history: list[dict] | None = None,
):
    """Async SSE generator — runs the sync agent in a background thread and yields
    each SSE chunk into the asyncio event loop for true per-token flushing."""
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue = asyncio.Queue(maxsize=128)
    SENTINEL = object()

    def _run_sync() -> None:
        def _evt(payload: dict) -> str:
            return f"data: {_json_dumps(payload)}\n\n"
        try:
            for item in _iter_agent_streaming(
                user_id=user_id, message=message,
                first_name=first_name, conversation_history=conversation_history,
            ):
                if item.get('type') == 'delta':
                    chunk = _evt({'type': 'delta', 'delta': item['delta']})
                elif item.get('type') == 'done':
                    chunk = _evt({
                        'type': 'done',
                        'tool': item.get('tool'),
                        'result': item.get('result'),
                        'assistant_message': item.get('assistant_message') or '',
                        'nav_hint': item.get('nav_hint'),
                    })
                else:
                    continue
                asyncio.run_coroutine_threadsafe(queue.put(chunk), loop).result()
        except BaseException as exc:
            asyncio.run_coroutine_threadsafe(queue.put(exc), loop).result()
        finally:
            asyncio.run_coroutine_threadsafe(queue.put(SENTINEL), loop).result()

    thread = threading.Thread(target=_run_sync, daemon=True)
    thread.start()
    try:
        while True:
            item = await queue.get()
            if item is SENTINEL:
                break
            if isinstance(item, BaseException):
                raise item
            yield item
    finally:
        thread.join(timeout=10)


def run_ai_command(*, user_id: str, message: str, first_name: str | None = None, conversation_history: list[dict] | None = None) -> dict:
    return _run_agent(user_id=user_id, message=message, first_name=first_name, conversation_history=conversation_history)
