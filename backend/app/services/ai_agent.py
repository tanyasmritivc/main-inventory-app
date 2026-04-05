from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import re
import threading
import time
from collections.abc import Iterator

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
# AI BRAIN (UNCHANGED)
# =========================

async def ai_agent(client, model, message, context):
    system = """
You are FindEZ, an intelligent AI assistant.

You behave like ChatGPT BUT you can take real actions.

You:
- understand messy human language
- infer intent naturally
- help with robotics (FTC)
- manage inventory

---

If you want to take an action, write:

ACTION: add 3 pens to drawer 3

or

ACTION: remove 2 screws

---

Then continue speaking normally.

DO NOT output JSON.
Be natural.
"""

    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system},
                {"role": "system", "content": f"CONTEXT:\n{json.dumps(context)}"},
                {"role": "user", "content": message},
            ],
            temperature=0.5,
        )

        content = resp.choices[0].message.content
        if not content:
            raise ValueError("Empty AI response")

        return content

    except Exception as e:
        logger.exception("AI call failed")
        raise RuntimeError("AI processing failed") from e


# =========================
# ACTION EXTRACTION
# =========================

def extract_actions(text: str):
    actions = []

    try:
        for line in text.split("\n"):
            if "ACTION:" in line:
                action = line.split("ACTION:")[1].strip()
                if action:
                    actions.append(action)
    except Exception:
        logger.exception("Failed to extract actions")

    return actions


# =========================
# BASIC PARSER
# =========================

def parse_items(text: str):
    items = []

    try:
        matches = re.findall(r'(\d+)\s+([a-zA-Z0-9\s]+?)(?:\s+in\s+(.+))?$', text)

        if matches:
            for qty, name, loc in matches:
                items.append({
                    "name": name.strip(),
                    "quantity": int(qty),
                    "location": loc.strip() if loc else None
                })
        else:
            items.append({
                "name": text.strip(),
                "quantity": 1,
                "location": None
            })

    except Exception:
        logger.exception("Failed to parse items")
        items.append({
            "name": text.strip(),
            "quantity": 1,
            "location": None
        })

    return items


# =========================
# EXECUTION (SAFE)
# =========================

def execute_actions(actions, user_id):
    results = []
    errors = []

    for action in actions:
        try:
            a = action.lower()

            # ADD
            if "add" in a or "put" in a:
                items = parse_items(action)

                for it in items:
                    try:
                        created = add_item(
                            user_id=user_id,
                            name=it["name"],
                            quantity=it["quantity"],
                            location=it.get("location") or "",
                        )
                        results.append(created)
                    except Exception:
                        logger.exception("Add item failed")
                        errors.append({"action": action, "error": "add_failed"})

            # REMOVE
            elif "remove" in a or "delete" in a:
                items = parse_items(action)

                for it in items:
                    try:
                        found = search_items_basic(user_id=user_id, query=it["name"])

                        if not found:
                            errors.append({"action": action, "error": "item_not_found"})
                            continue

                        for f in found[: it["quantity"]]:
                            delete_item(user_id=user_id, item_id=f["id"])
                            results.append(f)

                    except Exception:
                        logger.exception("Remove item failed")
                        errors.append({"action": action, "error": "remove_failed"})

            # SEARCH
            elif "find" in a or "search" in a:
                try:
                    found = search_items_basic(user_id=user_id, query=action)
                    results.extend(found)
                except Exception:
                    logger.exception("Search failed")
                    errors.append({"action": action, "error": "search_failed"})

        except Exception:
            logger.exception("Action execution failed")
            errors.append({"action": action, "error": "unknown_error"})

    return {
        "success": len(errors) == 0,
        "results": results,
        "errors": errors
    }


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

        # CONTEXT LOAD (SAFE)
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
            "activity": activity
        }

        # AI CALL
        ai_text = await ai_agent(client, model, message, context)

        # ACTIONS
        actions = extract_actions(ai_text)

        # EXECUTION
        exec_result = execute_actions(actions, user_id)

        # RESPONSE
        yield _evt({"type": "delta", "delta": ai_text})

        yield _evt({
            "type": "done",
            "tool": "ai_agent",
            "result": exec_result,
            "assistant_message": ai_text
        })

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