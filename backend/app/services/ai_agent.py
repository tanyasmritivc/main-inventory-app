from __future__ import annotations

import json

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import list_recent_activity
from app.services.items_repo import add_item, delete_item, search_items_basic
from app.services.documents_repo import list_documents


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
                "You are a personal inventory assistant. You are STRICTLY grounded in the provided JSON context for this user. "
                "Do not use outside knowledge about the user's possessions. If the context does not contain the answer, say you don't know and suggest what to do next. "
                "Never mention other users or data. "
                "When asked about documents, you only know filenames/metadata (no PDF text). "
                "Decide when to call tools. "
                "Use delete_inventory_item only when the user explicitly asks to delete and provides an item id. "
                "If missing required fields for add, ask a concise follow-up question instead of guessing."
            ),
        },
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    first = client.chat.completions.create(
        model=settings.openai_model,
        messages=messages,
        tools=tools,
        tool_choice="auto",
        temperature=0.2,
    )

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

    final = client.chat.completions.create(
        model=settings.openai_model,
        messages=messages,
        temperature=0.2,
    )

    final_msg = final.choices[0].message.content or ""
    return {"tool": tool_name, "result": result, "assistant_message": final_msg}
