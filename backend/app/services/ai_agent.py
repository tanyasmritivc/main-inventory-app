from __future__ import annotations

import json
import logging

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import list_recent_activity
from app.services.items_repo import add_item, delete_item, search_items_basic, update_item
from app.services.documents_repo import list_documents


logger = logging.getLogger(__name__)


def _client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


def run_ai_command(*, user_id: str, message: str) -> dict:
    settings = get_settings()
    client = _client()

    items = search_items_basic(user_id=user_id, q="")
    docs = list_documents(user_id=user_id, limit=50)
    activity = list_recent_activity(user_id=user_id, limit=25)

    context = {
        "inventory_items": items,
        "documents": docs,
        "recent_activity": activity,
        "notes": {
            "documents_text": "Document full text is not available in the database. Only filenames/metadata are available.",
        },
    }

    tools = [
        {
            "type": "function",
            "function": {
                "name": "add_inventory_item",
                "description": "Add a new inventory item for the current user.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "category": {"type": "string"},
                        "quantity": {"type": "integer"},
                        "location": {"type": "string"},
                        "image_url": {"type": ["string", "null"]},
                        "barcode": {"type": ["string", "null"]},
                        "purchase_source": {"type": ["string", "null"]},
                        "notes": {"type": ["string", "null"]},
                    },
                    "required": ["name", "category", "quantity", "location"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "search_inventory",
                "description": "Search the current user's inventory.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string"},
                    },
                    "required": ["query"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "update_inventory_items",
                "description": "Update one or more inventory items matching a query (move, change category/location, adjust quantity, etc.).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string"},
                        "updates": {
                            "type": "object",
                            "properties": {
                                "name": {"type": ["string", "null"]},
                                "category": {"type": ["string", "null"]},
                                "quantity": {"type": ["integer", "null"]},
                                "location": {"type": ["string", "null"]},
                                "barcode": {"type": ["string", "null"]},
                                "purchase_source": {"type": ["string", "null"]},
                                "notes": {"type": ["string", "null"]},
                            },
                            "additionalProperties": False,
                        },
                        "limit": {"type": ["integer", "null"]},
                    },
                    "required": ["query", "updates"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "delete_inventory_items",
                "description": "Delete one or more inventory items matching a query (use when user asks to delete by description, not id).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string"},
                        "limit": {"type": ["integer", "null"]},
                    },
                    "required": ["query"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "delete_inventory_item",
                "description": "Delete an inventory item by item_id.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "item_id": {"type": "string"},
                    },
                    "required": ["item_id"],
                    "additionalProperties": False,
                },
            },
        },
    ]

    messages: list[dict] = [
        {
            "role": "system",
            "content": (
                "You are Manifest Inventory, a calm, confident personal inventory assistant. You are STRICTLY grounded in the provided JSON context for this user. "
                "Response style: be concise, decisive, action-oriented. No rambling. No defensive language. No explaining limitations or internals. Minimal formatting. "
                "Formatting: keep answers ChatGPT-like and easy to scan. Use short paragraphs. Use simple '-' bullet lists when helpful. "
                "Avoid long single paragraphs. Minimal bolding only for short section headers. Do not use heavy markdown or code blocks. "
                "Use blank lines to separate sections and keep a calm vertical rhythm. "
                "Default to ACTION: when the user asks to add/delete/move/change category/change location/adjust quantity, execute it via tools immediately. "
                "Do not ask clarifying questions unless absolutely required to proceed. If ambiguity exists (e.g., multiple matches), pick the most recent / most common match based on USER_CONTEXT_JSON (inventory_items + recent_activity) and proceed. "
                "Inventory questions: answer in two short sections: 'You already have' and 'You're missing'. Do not list everything the user owns. Do not include IDs or internal metadata. "
                "Never mention other users or data. "
                "When asked about documents, you only know filenames/metadata (no PDF text). "
                "Prefer delete_inventory_items/update_inventory_items when the user describes items in natural language. "
                "Use delete_inventory_item only if an item_id is explicitly provided or uniquely identified. "
                "If missing required fields for add, infer reasonable defaults (quantity=1, location='Unsorted', category='Unsorted') and proceed."
            ),
        },
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    try:
        first = client.chat.completions.create(
            model=settings.openai_model,
            messages=messages,
            tools=tools,
            tool_choice="auto",
        )
    except Exception:
        logger.exception("OpenAI ai_command initial call failed")
        raise

    assistant = first.choices[0].message
    tool_calls = assistant.tool_calls or []

    if not tool_calls:
        return {"tool": None, "result": None, "assistant_message": assistant.content or ""}

    tool_call = tool_calls[0]
    tool_name = tool_call.function.name

    try:
        args = json.loads(tool_call.function.arguments or "{}")
    except Exception:
        args = {}

    result: dict | list | None
    if tool_name == "add_inventory_item":
        created = add_item(user_id=user_id, item=args)
        result = created
    elif tool_name == "search_inventory":
        items = search_items_basic(user_id=user_id, q=str(args.get("query") or ""))
        result = items
    elif tool_name == "update_inventory_items":
        q = str(args.get("query") or "").strip()
        updates = args.get("updates") or {}
        limit = args.get("limit")
        candidates = search_items_basic(user_id=user_id, q=q) if q else []

        cleaned_updates = {k: v for k, v in updates.items() if v is not None}
        applied: list[dict] = []
        failures: list[dict] = []

        for it in candidates[: int(limit) if isinstance(limit, int) and limit > 0 else len(candidates)]:
            item_id = str(it.get("item_id") or "")
            if not item_id:
                failures.append({"error": "Missing item_id", "item": it})
                continue
            updated = update_item(user_id=user_id, item_id=item_id, updates=cleaned_updates)
            if updated:
                applied.append(updated)
            else:
                failures.append({"error": "Update failed", "item_id": item_id})

        result = {"updated": applied, "failures": failures}
    elif tool_name == "delete_inventory_items":
        q = str(args.get("query") or "").strip()
        limit = args.get("limit")
        candidates = search_items_basic(user_id=user_id, q=q) if q else []
        deleted: list[str] = []
        failures: list[dict] = []
        for it in candidates[: int(limit) if isinstance(limit, int) and limit > 0 else len(candidates)]:
            item_id = str(it.get("item_id") or "")
            if not item_id:
                failures.append({"error": "Missing item_id", "item": it})
                continue
            ok = delete_item(user_id=user_id, item_id=item_id)
            if ok:
                deleted.append(item_id)
            else:
                failures.append({"error": "Delete failed", "item_id": item_id})
        result = {"deleted": deleted, "failures": failures}
    elif tool_name == "delete_inventory_item":
        ok = delete_item(user_id=user_id, item_id=str(args.get("item_id") or ""))
        result = {"deleted": ok}
    else:
        result = {"error": "Unknown tool"}

    messages.append(
        {
            "role": "assistant",
            "content": assistant.content,
            "tool_calls": [
                {
                    "id": tool_call.id,
                    "type": "function",
                    "function": {"name": tool_name, "arguments": tool_call.function.arguments},
                }
            ],
        }
    )
    messages.append(
        {
            "role": "tool",
            "tool_call_id": tool_call.id,
            "content": json.dumps(result),
        }
    )

    try:
        final = client.chat.completions.create(
            model=settings.openai_model,
            messages=messages,
        )
    except Exception:
        logger.exception("OpenAI ai_command final call failed")
        raise

    final_msg = final.choices[0].message.content or ""
    return {"tool": tool_name, "result": result, "assistant_message": final_msg}
