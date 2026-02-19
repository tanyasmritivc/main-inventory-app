from __future__ import annotations

import json
import logging
from collections.abc import Iterator

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import create_activity, list_recent_activity
from app.services.documents_repo import get_ai_access_granted, grant_ai_access, list_documents
from app.services.items_repo import add_item, bulk_create_items, delete_item, search_items_basic, update_item
from app.services.supabase_client import get_supabase_admin
from app.services.document_text_extractor import extract_text_from_upload


logger = logging.getLogger(__name__)


def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None) -> Iterator[str]:
    def _evt(payload: dict) -> str:
        return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"

    yield _evt({"type": "status", "message": "Checking your inventory…"})
    yield _evt({"type": "status", "message": "Looking for similar items…"})
    yield _evt({"type": "status", "message": "Thinking…"})

    settings = get_settings()
    client = _client()

    items = search_items_basic(user_id=user_id, q="")
    docs = list_documents(user_id=user_id, limit=50)
    activity = list_recent_activity(user_id=user_id, limit=25)

    documents_for_ai: list[dict] = []
    for d in docs if isinstance(docs, list) else []:
        if not isinstance(d, dict):
            continue
        filename = (d.get("filename") or "").strip() or "Untitled"
        storage_path = (d.get("storage_path") or "").strip()
        granted = bool(d.get("ai_access_granted"))
        documents_for_ai.append(
            {
                "name": filename,
                "filename": filename,
                "storage_path": storage_path,
                "ai_access_granted": granted,
                "mime_type": d.get("mime_type"),
                "created_at": d.get("created_at"),
                "size_bytes": d.get("size_bytes"),
            }
        )

    greet_name = (first_name or "").strip() or None
    should_greet = False
    if greet_name:
        try:
            has_ai_chat = any((a.get("metadata") or {}).get("type") == "ai_chat" for a in activity if isinstance(a, dict))
            should_greet = not has_ai_chat
        except Exception:
            should_greet = True

    context = {
        "inventory_items": items,
        "documents": documents_for_ai,
        "recent_activity": activity,
        "notes": {
            "documents_text": "Document contents are NOT available unless the user grants AI access for that document. You must request permission first.",
            "documents_naming": "When you refer to a document, ALWAYS use its human-readable name/filename (field: name/filename). Never refer to documents as IDs. When asking permission, say: 'Do you want me to check <DOCUMENT_NAME>?'",
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
                "name": "add_inventory_items",
                "description": "Add multiple inventory items for the current user in one operation.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "items": {
                            "type": "array",
                            "items": {
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
                                "required": ["name"],
                                "additionalProperties": False,
                            },
                        },
                    },
                    "required": ["items"],
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
        {
            "type": "function",
            "function": {
                "name": "grant_document_ai_access",
                "description": "Grant AI access to read a specific document identified by storage_path.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "storage_path": {"type": "string"},
                    },
                    "required": ["storage_path"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "read_document_text",
                "description": "Read and extract text from a document in the 'documents' storage bucket by storage_path, only if ai_access_granted is true.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "storage_path": {"type": "string"},
                    },
                    "required": ["storage_path"],
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
                "When referencing a document, ALWAYS use its name/filename from USER_CONTEXT_JSON.documents (e.g., 'Your Makita Drill Manual…'). "
                "When requesting permission to read a document, explicitly name it (e.g., 'Do you want me to check the warranty in Water Heater Manual?'). "
                "Do not read or extract document text unless the user has explicitly granted AI access for that document. "
                "Prefer delete_inventory_items/update_inventory_items when the user describes items in natural language. "
                "Use delete_inventory_item only if an item_id is explicitly provided or uniquely identified. "
                "If missing required fields for add, infer reasonable defaults (quantity=1, location='Unsorted', category='Unsorted') and proceed."
            ),
        },
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    # Stream the FIRST model step to detect whether tools are required.
    assistant_content = ""
    streamed_prefix1 = False
    tool_calls_acc: dict[int, dict] = {}
    stream1 = client.chat.completions.create(
        model=settings.openai_model,
        messages=messages,
        tools=tools,
        tool_choice="auto",
        stream=True,
    )
    for chunk in stream1:
        try:
            choice = chunk.choices[0]
        except Exception:
            continue
        delta = getattr(choice, "delta", None)
        if delta is None:
            delta = getattr(choice, "message", None)
        if delta is None:
            continue

        content = getattr(delta, "content", None)
        if content:
            if should_greet and greet_name and (not streamed_prefix1):
                streamed_prefix1 = True
                yield _evt({"type": "delta", "delta": f"Hi {greet_name} — "})
            assistant_content += content
            # Only stream early deltas if we haven't seen any tool calls.
            if not tool_calls_acc:
                yield _evt({"type": "delta", "delta": content})

        d_tool_calls = getattr(delta, "tool_calls", None)
        if d_tool_calls:
            for tc in d_tool_calls:
                idx = getattr(tc, "index", 0)
                existing = tool_calls_acc.setdefault(idx, {"id": "", "function": {"name": "", "arguments": ""}})
                tc_id = getattr(tc, "id", None)
                if tc_id:
                    existing["id"] = tc_id
                fn = getattr(tc, "function", None)
                if fn is not None:
                    name = getattr(fn, "name", None)
                    if name:
                        existing["function"]["name"] = name
                    args_part = getattr(fn, "arguments", None)
                    if args_part:
                        existing["function"]["arguments"] += args_part

    tool_calls_list = [tool_calls_acc[k] for k in sorted(tool_calls_acc.keys())]

    # If no tool call, we already streamed deltas as they arrived.
    if not tool_calls_list:
        final_msg = assistant_content or ""
        if should_greet and greet_name and final_msg.strip() and (not streamed_prefix1):
            final_msg = f"Hi {greet_name} — {final_msg.lstrip()}"

        try:
            create_activity(
                user_id=user_id,
                summary="Used Assist",
                metadata={"type": "ai_chat", "tool": None, "message": message},
                actor_name=first_name,
            )
        except Exception:
            logger.exception("Failed to write ai_chat activity")

        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": final_msg})
        return

    tool_call = tool_calls_list[0]
    tool_name = (tool_call.get("function") or {}).get("name") or ""
    raw_args = (tool_call.get("function") or {}).get("arguments") or "{}"
    try:
        args = json.loads(raw_args)
    except Exception:
        args = {}

    # Execute tool call identically to run_ai_command.
    result: dict | list | None
    if tool_name == "add_inventory_item":
        created = add_item(user_id=user_id, item=args)
        result = created
    elif tool_name == "add_inventory_items":
        items_in = args.get("items")
        items_list = items_in if isinstance(items_in, list) else []

        normalized: list[dict] = []
        for idx, it in enumerate(items_list):
            if not isinstance(it, dict):
                continue

            name = (it.get("name") or "").strip()
            if not name:
                continue

            category = (it.get("category") or "").strip() or "Unsorted"
            location = (it.get("location") or "").strip() or "Unsorted"
            quantity = it.get("quantity")
            if quantity is None:
                quantity = 1

            normalized.append(
                {
                    **it,
                    "name": name,
                    "category": category,
                    "location": location,
                    "quantity": quantity,
                }
            )

        inserted: list[dict] = []
        failures: list[dict] = []

        try:
            inserted, failures = bulk_create_items(user_id=user_id, items=normalized)
        except Exception:
            logger.exception("bulk_create_items failed; falling back to per-item inserts")
            for idx, it in enumerate(normalized):
                if not isinstance(it, dict):
                    failures.append({"index": idx, "reason": "invalid item"})
                    continue
                try:
                    created = add_item(user_id=user_id, item=it)
                    inserted.append(created)
                except Exception:
                    logger.exception("add_item failed during bulk fallback")
                    failures.append({"index": idx, "reason": "insert failed"})

        try:
            create_activity(
                user_id=user_id,
                summary=f"Added {len(inserted)} items to inventory",
                metadata={"type": "bulk_add", "inserted": len(inserted), "failures": len(failures)},
                actor_name=first_name,
            )
        except Exception:
            logger.exception("Failed to write bulk_add activity")

        result = {"inserted": inserted, "failures": failures}
    elif tool_name == "search_inventory":
        items2 = search_items_basic(user_id=user_id, q=str(args.get("query") or ""))
        result = items2
    elif tool_name == "update_inventory_items":
        q2 = str(args.get("query") or "").strip()
        updates = args.get("updates") or {}
        limit = args.get("limit")
        candidates = search_items_basic(user_id=user_id, q=q2) if q2 else []

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
        q2 = str(args.get("query") or "").strip()
        limit = args.get("limit")
        candidates = search_items_basic(user_id=user_id, q=q2) if q2 else []
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
    elif tool_name == "grant_document_ai_access":
        storage_path = str(args.get("storage_path") or "").strip()
        if not storage_path:
            result = {"ok": False, "error": "missing_storage_path"}
        else:
            ok = grant_ai_access(user_id=user_id, storage_path=storage_path)
            result = {"ok": bool(ok)}
    elif tool_name == "read_document_text":
        storage_path = str(args.get("storage_path") or "").strip()
        if not storage_path:
            result = {"ok": False, "error": "missing_storage_path"}
        elif not get_ai_access_granted(user_id=user_id, storage_path=storage_path):
            result = {"ok": False, "error": "permission_required"}
        else:
            try:
                supabase = get_supabase_admin()
                raw = supabase.storage.from_("documents").download(storage_path)
                text, _truncated = extract_text_from_upload(filename=storage_path, mime_type=None, content=raw)
                if not text:
                    result = {"ok": True, "text": ""}
                else:
                    result = {"ok": True, "text": text[:12000]}
            except Exception:
                logger.exception("Failed to read document text")
                result = {"ok": False, "error": "read_failed"}
    elif tool_name == "delete_inventory_item":
        ok = delete_item(user_id=user_id, item_id=str(args.get("item_id") or ""))
        result = {"deleted": ok}
    else:
        result = {"error": "Unknown tool"}

    # Build messages for the final assistant generation exactly like run_ai_command.
    messages.append(
        {
            "role": "assistant",
            "content": assistant_content,
            "tool_calls": [
                {
                    "id": tool_call.get("id") or "",
                    "type": "function",
                    "function": {"name": tool_name, "arguments": raw_args},
                }
            ],
        }
    )
    messages.append(
        {
            "role": "tool",
            "tool_call_id": tool_call.get("id") or "",
            "content": json.dumps(result),
        }
    )

    final_msg = ""
    if should_greet and greet_name:
        final_msg = f"Hi {greet_name} — "
        yield _evt({"type": "delta", "delta": final_msg})
    stream2 = client.chat.completions.create(
        model=settings.openai_model,
        messages=messages,
        stream=True,
    )
    for chunk in stream2:
        try:
            choice = chunk.choices[0]
        except Exception:
            continue
        delta = getattr(choice, "delta", None)
        if delta is None:
            delta = getattr(choice, "message", None)
        if delta is None:
            continue
        content = getattr(delta, "content", None)
        if content:
            final_msg += content
            yield _evt({"type": "delta", "delta": content})

    try:
        create_activity(
            user_id=user_id,
            summary="Used Assist",
            metadata={"type": "ai_chat", "tool": tool_name, "message": message},
            actor_name=first_name,
        )
    except Exception:
        logger.exception("Failed to write ai_chat activity")

    yield _evt({"type": "done", "tool": tool_name, "result": result, "assistant_message": final_msg})


def _client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


def run_ai_command(*, user_id: str, message: str, first_name: str | None = None) -> dict:
    settings = get_settings()
    client = _client()

    items = search_items_basic(user_id=user_id, q="")
    docs = list_documents(user_id=user_id, limit=50)
    activity = list_recent_activity(user_id=user_id, limit=25)

    documents_for_ai: list[dict] = []
    for d in docs if isinstance(docs, list) else []:
        if not isinstance(d, dict):
            continue
        filename = (d.get("filename") or "").strip() or "Untitled"
        storage_path = (d.get("storage_path") or "").strip()
        granted = bool(d.get("ai_access_granted"))
        documents_for_ai.append(
            {
                "name": filename,
                "filename": filename,
                "storage_path": storage_path,
                "ai_access_granted": granted,
                "mime_type": d.get("mime_type"),
                "created_at": d.get("created_at"),
                "size_bytes": d.get("size_bytes"),
            }
        )

    greet_name = (first_name or "").strip() or None
    should_greet = False
    if greet_name:
        try:
            has_ai_chat = any((a.get("metadata") or {}).get("type") == "ai_chat" for a in activity if isinstance(a, dict))
            should_greet = not has_ai_chat
        except Exception:
            should_greet = True

    context = {
        "inventory_items": items,
        "documents": documents_for_ai,
        "recent_activity": activity,
        "notes": {
            "documents_text": "Document contents are NOT available unless the user grants AI access for that document. You must request permission first.",
            "documents_naming": "When you refer to a document, ALWAYS use its human-readable name/filename (field: name/filename). Never refer to documents as IDs. When asking permission, say: 'Do you want me to check <DOCUMENT_NAME>?'",
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
                "name": "add_inventory_items",
                "description": "Add multiple inventory items for the current user in one operation.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "items": {
                            "type": "array",
                            "items": {
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
                                "required": ["name"],
                                "additionalProperties": False,
                            },
                        },
                    },
                    "required": ["items"],
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
        {
            "type": "function",
            "function": {
                "name": "grant_document_ai_access",
                "description": "Grant AI access to read a specific document identified by storage_path.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "storage_path": {"type": "string"},
                    },
                    "required": ["storage_path"],
                    "additionalProperties": False,
                },
            },
        },
        {
            "type": "function",
            "function": {
                "name": "read_document_text",
                "description": "Read and extract text from a document in the 'documents' storage bucket by storage_path, only if ai_access_granted is true.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "storage_path": {"type": "string"},
                    },
                    "required": ["storage_path"],
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
                "When referencing a document, ALWAYS use its name/filename from USER_CONTEXT_JSON.documents (e.g., 'Your Makita Drill Manual…'). "
                "When requesting permission to read a document, explicitly name it (e.g., 'Do you want me to check the warranty in Water Heater Manual?'). "
                "Do not read or extract document text unless the user has explicitly granted AI access for that document. "
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
        msg = assistant.content or ""
        if should_greet and greet_name and msg.strip():
            msg = f"Hi {greet_name} — {msg.lstrip()}"
        return {"tool": None, "result": None, "assistant_message": msg}

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
    elif tool_name == "add_inventory_items":
        items_in = args.get("items")
        items_list = items_in if isinstance(items_in, list) else []

        normalized: list[dict] = []
        for idx, it in enumerate(items_list):
            if not isinstance(it, dict):
                continue

            name = (it.get("name") or "").strip()
            if not name:
                continue

            category = (it.get("category") or "").strip() or "Unsorted"
            location = (it.get("location") or "").strip() or "Unsorted"
            quantity = it.get("quantity")
            if quantity is None:
                quantity = 1

            normalized.append(
                {
                    **it,
                    "name": name,
                    "category": category,
                    "location": location,
                    "quantity": quantity,
                }
            )

        inserted: list[dict] = []
        failures: list[dict] = []

        try:
            inserted, failures = bulk_create_items(user_id=user_id, items=normalized)
        except Exception:
            logger.exception("bulk_create_items failed; falling back to per-item inserts")
            for idx, it in enumerate(normalized):
                if not isinstance(it, dict):
                    failures.append({"index": idx, "reason": "invalid item"})
                    continue
                try:
                    created = add_item(user_id=user_id, item=it)
                    inserted.append(created)
                except Exception:
                    logger.exception("add_item failed during bulk fallback")
                    failures.append({"index": idx, "reason": "insert failed"})

        try:
            create_activity(
                user_id=user_id,
                summary=f"Added {len(inserted)} items to inventory",
                metadata={"type": "bulk_add", "inserted": len(inserted), "failures": len(failures)},
                actor_name=first_name,
            )
        except Exception:
            logger.exception("Failed to write bulk_add activity")

        result = {"inserted": inserted, "failures": failures}
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
    elif tool_name == "grant_document_ai_access":
        storage_path = str(args.get("storage_path") or "").strip()
        if not storage_path:
            result = {"ok": False, "error": "missing_storage_path"}
        else:
            ok = grant_ai_access(user_id=user_id, storage_path=storage_path)
            result = {"ok": bool(ok)}
    elif tool_name == "read_document_text":
        storage_path = str(args.get("storage_path") or "").strip()
        if not storage_path:
            result = {"ok": False, "error": "missing_storage_path"}
        elif not get_ai_access_granted(user_id=user_id, storage_path=storage_path):
            result = {"ok": False, "error": "permission_required"}
        else:
            try:
                supabase = get_supabase_admin()
                raw = supabase.storage.from_("documents").download(storage_path)
                text, _truncated = extract_text_from_upload(filename=storage_path, mime_type=None, content=raw)
                if not text:
                    result = {"ok": True, "text": ""}
                else:
                    result = {"ok": True, "text": text[:12000]}
            except Exception:
                logger.exception("Failed to read document text")
                result = {"ok": False, "error": "read_failed"}
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
    if should_greet and greet_name and final_msg.strip():
        final_msg = f"Hi {greet_name} — {final_msg.lstrip()}"
    return {"tool": tool_name, "result": result, "assistant_message": final_msg}
