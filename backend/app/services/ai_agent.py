from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import re
import threading
import time
from collections.abc import Iterator
from typing import Any

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import list_recent_activity, list_documents
from app.services.items_repo import add_item, delete_item, search_items_basic, update_item


logger = logging.getLogger(__name__)


# =========================
# CLIENT
# =========================

def _get_openai_client() -> OpenAI:
    try:
        return OpenAI(api_key=get_settings().openai_api_key)
    except Exception as e:
        logger.exception("Failed to initialize OpenAI client")
        raise RuntimeError("AI client initialization failed") from e


# =========================
# SIMPLE MEMORY
# =========================

@dataclass
class _SessionState:
    last_item_name: str | None = None
    updated_at: float = 0.0


_SESSION: dict[str, _SessionState] = {}
_LOCK = threading.Lock()


def _get_state(user_id: str) -> _SessionState:
    with _LOCK:
        if user_id not in _SESSION:
            _SESSION[user_id] = _SessionState(updated_at=time.time())
        return _SESSION[user_id]


# =========================
# AI-FIRST INTENT PARSING
# =========================

_INTENT_SYS_PROMPT = (
    "You are the intelligent brain of an AI-first inventory assistant.\n\n"
    "Your job is to understand the user’s message exactly like a human would — not by matching keywords, but by interpreting meaning.\n\n"
    "You MUST behave like ChatGPT:\n"
    "- No keyword matching\n"
    "- No trigger-based logic\n"
    "- No rigid rules\n"
    "- Pure natural language understanding\n\n"
    "---\n\n"
    "SUPPORTED INTENTS (choose ONE):\n"
    "- add → user wants to add items\n"
    "- delete → user wants to remove items\n"
    "- update → user wants to modify items\n"
    "- query → user is asking about inventory\n"
    "- plan → user wants to build something or figure out what they need\n\n"
    "CRITICAL UNDERSTANDING RULES:\n"
    "- If user says what they HAVE → this is NOT add\n"
    "- If user is asking what they NEED → this is ALWAYS plan\n"
    "- If uncertain → default to query\n\n"
    "You MUST handle messy grammar, casual language, incomplete sentences, and multiple items in one request.\n\n"
    "You MUST:\n"
    "- normalize item names (pen vs pens → pen)\n"
    "- extract quantities\n"
    "- extract locations (e.g. third drawer → drawer 3)\n"
    "- extract attributes (e.g. type 4 screws)\n\n"
    "OUTPUT FORMAT (STRICT JSON ONLY; no extra text):\n"
    "{\n"
    '  "action": "add" | "delete" | "update" | "query" | "plan",\n'
    '  "items": [{"name": string, "quantity": number, "location": string|null, "attributes": string|null}],\n'
    '  "query": string|null,\n'
    '  "updates": object|null\n'
    "}"
)


def _extract_json_object(text: str) -> dict | None:
    if not text:
        return None

    s = text.strip()
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z0-9_-]*\n", "", s)
        s = re.sub(r"\n```$", "", s).strip()

    try:
        obj = json.loads(s)
        return obj if isinstance(obj, dict) else None
    except Exception:
        pass

    # Fallback: best-effort extract first JSON object.
    start = s.find("{")
    end = s.rfind("}")
    if start >= 0 and end > start:
        try:
            obj = json.loads(s[start : end + 1])
            return obj if isinstance(obj, dict) else None
        except Exception:
            return None

    return None


def _normalize_intent(*, raw: dict | None, message: str) -> dict:
    if not isinstance(raw, dict):
        return {
            "action": "query",
            "items": [],
            "query": message,
            "updates": None,
        }

    action = raw.get("action")
    if action == "remove":
        action = "delete"
    if action not in {"add", "delete", "update", "query", "plan"}:
        action = "query"

    items_in = raw.get("items")
    items: list[dict] = []
    if isinstance(items_in, list):
        for it in items_in:
            if not isinstance(it, dict):
                continue
            name = it.get("name")
            if not isinstance(name, str) or not name.strip():
                continue

            qty = it.get("quantity", 1)
            if not isinstance(qty, (int, float)):
                qty = 1

            loc = it.get("location")
            if loc is not None and not isinstance(loc, str):
                loc = None

            attrs = it.get("attributes")
            if attrs is not None and not isinstance(attrs, str):
                attrs = None

            items.append(
                {
                    "name": name.strip(),
                    "quantity": float(qty),
                    "location": loc.strip() if isinstance(loc, str) and loc.strip() else None,
                    "attributes": attrs.strip() if isinstance(attrs, str) and attrs.strip() else None,
                }
            )

    query = raw.get("query")
    if query is not None and not isinstance(query, str):
        query = None
    query_s = query.strip() if isinstance(query, str) and query.strip() else None

    updates = raw.get("updates")
    if updates is not None and not isinstance(updates, dict):
        updates = None

    return {
        "action": action,
        "items": items,
        "query": query_s,
        "updates": updates,
    }


async def _ai_parse_intent(*, client: OpenAI, model: str, message: str, context: dict) -> dict:
    messages = [
        {"role": "system", "content": _INTENT_SYS_PROMPT},
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    try:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.2,
            max_tokens=450,
            response_format={"type": "json_object"},
        )
    except TypeError:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.2,
            max_tokens=450,
        )

    content = getattr(resp.choices[0].message, "content", None) or ""
    raw = _extract_json_object(content)
    return _normalize_intent(raw=raw, message=message)


def _execute_intent(*, intent: dict, user_id: str) -> dict:
    action = intent.get("action")
    items = intent.get("items") or []
    query = intent.get("query")
    updates = intent.get("updates")

    try:
        if action == "add":
            created: list[dict] = []
            for it in items:
                created.append(
                    add_item(
                        user_id=user_id,
                        name=it.get("name") or "",
                        quantity=int(it.get("quantity") or 1),
                        location=(it.get("location") or ""),
                        notes=(it.get("attributes") or ""),
                    )
                )
            return {"success": True, "action": "add", "items": created}

        if action == "delete":
            deleted: list[dict] = []
            for it in items:
                name = it.get("name") or ""
                qty = int(it.get("quantity") or 1)
                found = search_items_basic(user_id=user_id, query=name)
                for f in (found or [])[:qty]:
                    delete_item(user_id=user_id, item_id=f["id"])
                    deleted.append(f)
            return {"success": True, "action": "delete", "items": deleted}

        if action == "update":
            updated: list[dict] = []
            patch: dict[str, Any] = updates if isinstance(updates, dict) else {}
            for it in items:
                name = it.get("name") or ""
                found = search_items_basic(user_id=user_id, query=name)
                if not found:
                    continue

                item_patch = dict(patch)
                # If the model put updates on the item itself, honor them too.
                if it.get("location") is not None:
                    item_patch.setdefault("location", it.get("location"))
                if it.get("quantity") is not None:
                    item_patch.setdefault("quantity", int(it.get("quantity") or 1))
                if it.get("attributes") is not None:
                    item_patch.setdefault("notes", it.get("attributes"))

                for f in found[:1]:
                    updated.append(update_item(user_id=user_id, item_id=f["id"], updates=item_patch))
            return {"success": True, "action": "update", "items": updated}

        if action == "plan":
            all_items = search_items_basic(user_id=user_id, query="")

            # Convert inventory into readable format
            inventory_summary = [
                f"{item.get('quantity', 0)} {item.get('name', '')}"
                for item in all_items
            ]

            planning_prompt = (
                "You are an expert robotics and inventory assistant.\n\n"
                "The user wants to build something.\n\n"
                "You MUST:\n"
                "1. Understand the user's goal\n"
                "2. Compare it with their inventory\n"
                "3. Clearly list:\n"
                "   - What they ALREADY HAVE\n"
                "   - What they NEED\n"
                "4. Provide a simple step-by-step plan\n\n"
                "Rules:\n"
                "- Be specific\n"
                "- Do NOT hallucinate owned items\n"
                "- Be practical\n"
            )

            resp = _get_openai_client().chat.completions.create(
                model=get_settings().openai_model,
                messages=[
                    {"role": "system", "content": planning_prompt},
                    {"role": "system", "content": f"INVENTORY:\n{json.dumps(inventory_summary)}"},
                    {"role": "user", "content": query or ""}
                ],
                temperature=0.4,
                max_tokens=400
            )

            plan_text = resp.choices[0].message.content.strip()

            return {
                "success": True,
                "action": "plan",
                "plan": plan_text
            }

        # query (default)
        if isinstance(items, list) and items:
            results: list[dict] = []
            for it in items:
                results.extend(search_items_basic(user_id=user_id, query=(it.get("name") or "")) or [])
            return {"success": True, "action": "query", "items": results}

        if isinstance(query, str) and query.strip():
            results = search_items_basic(user_id=user_id, query=query)
            return {"success": True, "action": "query", "items": results}

        results = search_items_basic(user_id=user_id, query="")
        return {"success": True, "action": "query", "items": results}
    except Exception as e:
        logger.exception("Intent execution failed")
        return {"success": False, "error": str(e), "action": action, "items": []}


async def _generate_response(*, client: OpenAI, model: str, message: str, intent: dict, result: dict, context: dict) -> str:
    sys = (
        "You are a helpful inventory assistant. Respond naturally like ChatGPT. "
        "Be concise, accurate, and do not mention JSON, tools, or internal processing."
    )
    prompt = {
        "user_message": message,
        "intent": intent,
        "execution_result": result,
        "context": {
            "inventory_count": len(context.get("inventory") or []),
        },
    }

    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": sys},
                {"role": "user", "content": json.dumps(prompt, ensure_ascii=False)},
            ],
            temperature=0.4,
            max_tokens=220,
        )
        content = getattr(resp.choices[0].message, "content", None) or ""
        content = content.strip()
        return content or "Done."
    except Exception:
        logger.exception("Response generation failed")
        return "Done."


# =========================
# STREAM FUNCTION
# =========================

async def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None) -> Iterator[str]:

    def _evt(payload: dict) -> str:
        return f"data: {json.dumps(payload)}\n\n"

    if not user_id:
        yield _evt({
            "type": "done",
            "tool": None,
            "result": None,
            "assistant_message": "Missing user session."
        })
        return

    try:
        client = _get_openai_client()
        model = get_settings().openai_model

        # CONTEXT LOAD
        try:
            items = search_items_basic(user_id=user_id, query="")
        except Exception:
            logger.exception("Inventory load failed")
            items = []

        try:
            docs = list_documents(user_id=user_id)
        except Exception:
            logger.exception("Docs load failed")
            docs = []

        try:
            activity = list_recent_activity(user_id=user_id)
        except Exception:
            logger.exception("Activity load failed")
            activity = []

        context = {
            "inventory": items,
            "documents": docs,
            "activity": activity,
            "hint": "User builds FTC robots"
        }

        st = _get_state(user_id)
        context["memory"] = {"last_item_name": st.last_item_name}

        intent = await _ai_parse_intent(client=client, model=model, message=message, context=context)
        exec_result = _execute_intent(intent=intent, user_id=user_id)

        if intent.get("items"):
            try:
                st.last_item_name = intent["items"][0].get("name")
                st.updated_at = time.time()
            except Exception:
                pass

        assistant_message = await _generate_response(
            client=client,
            model=model,
            message=message,
            intent=intent,
            result=exec_result,
            context=context,
        )

        yield _evt({"type": "delta", "delta": assistant_message})
        yield _evt(
            {
                "type": "done",
                "tool": intent.get("action"),
                "result": exec_result,
                "assistant_message": assistant_message,
            }
        )

    except RuntimeError as e:
        yield _evt({
            "type": "done",
            "tool": None,
            "result": None,
            "assistant_message": str(e)
        })

    except Exception:
        logger.exception("Critical AI failure")
        yield _evt({
            "type": "done",
            "tool": None,
            "result": None,
            "assistant_message": "Something went wrong. Please try again."
        })


def run_ai_command(*, user_id: str, message: str, first_name: str | None = None) -> dict:
    client = _get_openai_client()
    model = get_settings().openai_model

    try:
        items = search_items_basic(user_id=user_id, query="")
    except Exception:
        logger.exception("Inventory load failed")
        items = []

    try:
        docs = list_documents(user_id=user_id)
    except Exception:
        logger.exception("Docs load failed")
        docs = []

    try:
        activity = list_recent_activity(user_id=user_id)
    except Exception:
        logger.exception("Activity load failed")
        activity = []

    context = {
        "inventory": items,
        "documents": docs,
        "activity": activity,
        "hint": "User builds FTC robots",
    }

    st = _get_state(user_id)
    context["memory"] = {"last_item_name": st.last_item_name}

    # This endpoint is sync; call the parser/response generators via the sync OpenAI client.
    intent = _normalize_intent(raw=_extract_json_object(_call_intent_sync(client=client, model=model, message=message, context=context)), message=message)
    exec_result = _execute_intent(intent=intent, user_id=user_id)

    if intent.get("items"):
        try:
            st.last_item_name = intent["items"][0].get("name")
            st.updated_at = time.time()
        except Exception:
            pass

    assistant_message = _call_response_sync(client=client, model=model, message=message, intent=intent, result=exec_result, context=context)
    return {"tool": intent.get("action"), "result": exec_result, "assistant_message": assistant_message}


def _call_intent_sync(*, client: OpenAI, model: str, message: str, context: dict) -> str:
    messages = [
        {"role": "system", "content": _INTENT_SYS_PROMPT},
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.2,
            max_tokens=450,
            response_format={"type": "json_object"},
        )
    except TypeError:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.2,
            max_tokens=450,
        )
    return getattr(resp.choices[0].message, "content", None) or ""


def _call_response_sync(*, client: OpenAI, model: str, message: str, intent: dict, result: dict, context: dict) -> str:
    sys = (
        "You are a helpful inventory assistant. Respond naturally like ChatGPT. "
        "Be concise, accurate, and do not mention JSON, tools, or internal processing."
    )
    prompt = {
        "user_message": message,
        "intent": intent,
        "execution_result": result,
        "context": {"inventory_count": len(context.get("inventory") or [])},
    }
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": sys},
                {"role": "user", "content": json.dumps(prompt, ensure_ascii=False)},
            ],
            temperature=0.4,
            max_tokens=220,
        )
        content = getattr(resp.choices[0].message, "content", None) or ""
        content = content.strip()
        return content or "Done."
    except Exception:
        logger.exception("Response generation failed")
        return "Done."