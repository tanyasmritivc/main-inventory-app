from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import queue
import re
import threading
import time
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor, TimeoutError as _FuturesTimeoutError

from openai import OpenAI

from app.core.config import get_settings
from app.services.documents_repo import create_activity, list_recent_activity
from app.services.documents_repo import grant_ai_access, list_documents
from app.services.items_repo import add_item, bulk_create_items, delete_item, search_items_basic, update_item
from app.services.supabase_client import get_supabase_admin
from app.services.document_text_extractor import extract_text_from_upload


logger = logging.getLogger(__name__)


class _AIStreamTimeout(Exception):
    pass


def _call_with_timeout(fn, *, timeout_s: float):
    with ThreadPoolExecutor(max_workers=1) as ex:
        fut = ex.submit(fn)
        try:
            return fut.result(timeout=timeout_s)
        except _FuturesTimeoutError as e:
            raise _AIStreamTimeout("timeout") from e


def _chat_create_low_latency(client: OpenAI, **kwargs):
    # Prefer the lowest-latency settings; fall back gracefully if params aren't supported.
    base = {
        **kwargs,
    }
    try:
        return client.chat.completions.create(
            **base,
            reasoning_effort="low",
            max_output_tokens=300,
        )
    except TypeError:
        try:
            return client.chat.completions.create(
                **base,
                reasoning_effort="low",
                max_completion_tokens=300,
            )
        except TypeError:
            return client.chat.completions.create(
                **base,
                max_completion_tokens=300,
            )


def _iter_stream_with_deadlines(
    stream,
    *,
    first_token_timeout_s: float,
    total_timeout_s: float,
):
    q: queue.Queue = queue.Queue()
    sentinel = object()

    def _worker():
        try:
            for ch in stream:
                q.put(ch)
        except Exception as e:
            q.put(e)
        finally:
            q.put(sentinel)

    t = threading.Thread(target=_worker, daemon=True)
    t.start()

    start = _now_s()
    first = True
    while True:
        now = _now_s()
        deadline = start + (first_token_timeout_s if first else total_timeout_s)
        remaining = deadline - now
        if remaining <= 0:
            try:
                close_fn = getattr(stream, "close", None)
                if callable(close_fn):
                    close_fn()
            except Exception:
                pass
            raise _AIStreamTimeout("timeout")

        try:
            item = q.get(timeout=remaining)
        except queue.Empty as e:
            try:
                close_fn = getattr(stream, "close", None)
                if callable(close_fn):
                    close_fn()
            except Exception:
                pass
            raise _AIStreamTimeout("timeout") from e

        if item is sentinel:
            break
        if isinstance(item, Exception):
            raise item
        first = False
        yield item


@dataclass
class _SessionState:
    last_item_id: str | None = None
    last_item_name: str | None = None
    greeted: bool = False
    pending_action: str | None = None
    pending_item_id: str | None = None
    pending_item_name: str | None = None
    pending_quantity: int | None = None
    updated_at: float = 0.0
    items_cache: list[dict] | None = None
    items_cache_at: float = 0.0


_SESSION_LOCK = threading.Lock()
_SESSION: dict[str, _SessionState] = {}
_SESSION_TTL_S = 60 * 30
_ITEMS_CACHE_TTL_S = 10.0


def _now_s() -> float:
    return time.time()


def _get_state(user_id: str) -> _SessionState:
    now = _now_s()
    with _SESSION_LOCK:
        st = _SESSION.get(user_id)
        if st is None or (st.updated_at and (now - st.updated_at) > _SESSION_TTL_S):
            st = _SessionState(updated_at=now)
            _SESSION[user_id] = st
        else:
            st.updated_at = now
        return st


def _clear_pending(st: _SessionState) -> None:
    st.pending_action = None
    st.pending_item_id = None
    st.pending_item_name = None
    st.pending_quantity = None


def _norm(s: str) -> str:
    s = (s or "").strip().lower()
    s = re.sub(r"[^a-z0-9\s]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _best_item_match(items: list[dict], query: str) -> tuple[dict | None, float]:
    qn = _norm(query)
    if not qn:
        return (None, 0.0)

    # Simple matching only: lowercase comparison and substring match.
    # This intentionally avoids heavier similarity scoring.
    best: dict | None = None
    best_score = 0.0
    for it in items or []:
        name = str(it.get("name") or "")
        if not name:
            continue
        sn = _norm(name)
        if not sn:
            continue
        if qn == sn:
            return (it, 1.0)
        if qn in sn or sn in qn:
            # Prefer longer overlaps.
            score = min(0.99, max(0.8, len(qn) / max(1, len(sn))))
            if score > best_score:
                best_score = score
                best = it
    return (best, best_score)


def _list_recent_items_limited(*, user_id: str, limit: int = 50) -> list[dict]:
    # Use a limited query to avoid loading the entire inventory.
    try:
        supabase = get_supabase_admin()
        resp = (
            supabase.table("items")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        data = resp.data or []
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _get_items_for_match(*, user_id: str, st: _SessionState) -> list[dict]:
    now = _now_s()
    if st.items_cache is not None and (now - st.items_cache_at) <= _ITEMS_CACHE_TTL_S:
        return st.items_cache
    items = _list_recent_items_limited(user_id=user_id, limit=50)
    st.items_cache = items
    st.items_cache_at = now
    return items


_NUM_WORDS = {
    "a": 1,
    "an": 1,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
}


def _parse_int_token(tok: str) -> int | None:
    t = _norm(tok)
    if not t:
        return None
    if t.isdigit():
        try:
            return int(t)
        except Exception:
            return None
    return _NUM_WORDS.get(t)


def _extract_qty_and_rest(s: str) -> tuple[int | None, str]:
    s2 = s.strip()
    if not s2:
        return (None, "")

    m = re.match(r"^\s*(\d+)\s+(.+)$", s2)
    if m:
        try:
            return (int(m.group(1)), m.group(2).strip())
        except Exception:
            return (None, s2)

    parts = s2.split()
    if parts:
        n = _parse_int_token(parts[0])
        if n is not None and len(parts) > 1:
            return (n, " ".join(parts[1:]).strip())
    return (None, s2)


def _split_location(rest: str) -> tuple[str, str | None]:
    # Only treat a trailing "in <location>" as location, to avoid stealing words from the item name.
    s = rest.strip()
    low = _norm(s)
    if " in " not in f" {low} ":
        return (s, None)

    idx = low.rfind(" in ")
    if idx <= 0:
        return (s, None)
    left = s[:idx].strip()
    right = s[idx + 4 :].strip()
    if not left or not right:
        return (s, None)

    # Heuristic: location is short.
    if len(right.split()) > 4:
        return (s, None)
    return (left, right)


def _guess_category(name: str) -> str:
    n = _norm(name)
    if any(w in n for w in ["milk", "apple", "apples", "banana", "bananas", "bread", "cheese", "egg", "eggs", "yogurt"]):
        return "Food"
    if any(w in n for w in ["battery", "batteries", "duct tape", "tape", "screws", "nails", "drill", "hammer"]):
        return "Hardware"
    if any(w in n for w in ["soap", "detergent", "bleach", "cleaner", "paper towels", "towel"]):
        return "Household"
    return "Unsorted"


def _is_yes(s: str) -> bool:
    t = _norm(s)
    return t in {"yes", "y", "ok", "okay", "confirm", "confirmed", "do it"}


def _is_no(s: str) -> bool:
    t = _norm(s)
    return t in {"no", "n", "cancel", "stop", "never mind", "nevermind"}


def _is_most_recent_query(s: str) -> bool:
    t = _norm(s)
    return (
        "most recent item" in t
        or t in {"what did i add last", "what did i add last?", "what is the most recent item", "what is the most recent item?"}
        or "what did i add last" in t
        or "most recent" in t and "item" in t
    )


def _extract_name_after_verb(msg: str, verbs: list[str]) -> str | None:
    t = (msg or "").strip()
    low = _norm(t)
    for v in verbs:
        v2 = _norm(v)
        if low == v2:
            return ""
        if low.startswith(v2 + " "):
            return t[len(v) :].strip()
    return None


def _state_snapshot(st: _SessionState) -> dict:
    return {
        "last_item_id": st.last_item_id,
        "last_item_name": st.last_item_name,
        "pending_action": st.pending_action,
        "pending_item_id": st.pending_item_id,
        "pending_quantity": st.pending_quantity,
    }


def _update_state_from_tool(*, user_id: str, tool_name: str | None, result: object) -> None:
    if not tool_name:
        return
    st = _get_state(user_id)
    try:
        if tool_name == "add_inventory_item" and isinstance(result, dict):
            st.last_item_id = str(result.get("item_id") or "") or None
            st.last_item_name = str(result.get("name") or "") or None
            _clear_pending(st)
        elif tool_name == "add_inventory_items" and isinstance(result, dict):
            inserted = result.get("inserted")
            if isinstance(inserted, list) and inserted:
                last = inserted[0] if isinstance(inserted[0], dict) else None
                if last:
                    st.last_item_id = str(last.get("item_id") or "") or None
                    st.last_item_name = str(last.get("name") or "") or None
            _clear_pending(st)
        elif tool_name in {"update_inventory_items", "search_inventory"} and isinstance(result, dict):
            # update_inventory_items returns {updated:[...]} ; pick first.
            updated = result.get("updated")
            if isinstance(updated, list) and updated and isinstance(updated[0], dict):
                st.last_item_id = str(updated[0].get("item_id") or "") or None
                st.last_item_name = str(updated[0].get("name") or "") or None
            _clear_pending(st)
        elif tool_name in {"delete_inventory_item"} and isinstance(result, dict):
            _clear_pending(st)
        elif tool_name == "delete_inventory_items":
            _clear_pending(st)
    except Exception:
        return


def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None) -> Iterator[str]:
    def _evt(payload: dict) -> str:
        return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"

    print("AI request received")
    user_id = (user_id or "").strip()
    logger.info("AI request received user_id=%s", user_id)
    if not user_id:
        logger.error("AI request received with empty user_id")
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
        yield "event: done\n"
        yield "data: {}\n\n"
        return

    def _evt_event(name: str, data: str) -> Iterator[str]:
        yield f"event: {name}\n"
        yield f"data: {data}\n\n"

    def _emit_terminal_done() -> Iterator[str]:
        # Always end the stream with event: done + data: {}
        yield from _evt_event("done", "{}")

    request_start = _now_s()
    total_deadline = request_start + 20.0

    done_sent = False
    streamed_any_delta = False
    first_delta_sent = False
    tool_for_done: str | None = None
    result_for_done: dict | list | None = None
    assistant_message_for_done = ""

    try:
        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

        settings = get_settings()
        client = _client()

        # Load inventory items for context. This must be ready before the model stream starts,
        # otherwise the assistant may incorrectly think the inventory is empty.
        st = _get_state(user_id)
        now = _now_s()
        items: list[dict] = []
        items_source = "db"
        if st.items_cache is not None and (now - st.items_cache_at) <= _ITEMS_CACHE_TTL_S:
            items = st.items_cache
            items_source = "cache"
        else:
            try:
                items = search_items_basic(user_id=user_id, q="")[:50]
                st.items_cache = items
                st.items_cache_at = _now_s()
            except Exception:
                logger.exception("Assist failed to load inventory items for user_id=%s", user_id)
                items = []

        logger.info("Assist inventory count for user %s: %s (source=%s)", user_id, len(items), items_source)

        docs: list[dict] = []
        activity: list[dict] = []
        ctx_ready = threading.Event()

        def _fetch_context():
            nonlocal items, docs, activity
            try:
                fetched_docs = list_documents(user_id=user_id, limit=50)
                docs = fetched_docs if isinstance(fetched_docs, list) else []

                fetched_activity = list_recent_activity(user_id=user_id, limit=25)
                activity = fetched_activity if isinstance(fetched_activity, list) else []
            finally:
                ctx_ready.set()

        t_ctx = threading.Thread(target=_fetch_context, daemon=True)
        t_ctx.start()

        documents_for_ai: list[dict] = []
        for d in docs if isinstance(docs, list) else []:
            if not isinstance(d, dict):
                continue
            filename = (d.get("display_name") or d.get("filename") or "").strip() or "Untitled"
            storage_path = (d.get("storage_path") or "").strip()
            granted = True
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
        should_greet = bool(greet_name) and (not st.greeted)

        context = {
            "inventory_items": items,
            "documents": documents_for_ai,
            "recent_activity": activity,
            "session_state": _state_snapshot(_get_state(user_id)),
            "notes": {
                "documents_text": "Document contents are available.",
                "documents_naming": "When you refer to a document, ALWAYS use its human-readable name/filename (field: name/filename). Never refer to documents as IDs.",
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
                    "description": "Read and extract text from a document in the 'documents' storage bucket by storage_path.",
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
                    "You are FindEZ Assistant — a fast, highly intelligent, ChatGPT-like assistant that helps the user manage their belongings and inventory. "
                    "Your #1 job is to understand intent (not literal phrasing). Treat inventory items as concepts rather than exact string matches. "
                    "Examples like 'Do I have milk?', 'Is there milk in my inventory?', and 'Do I have something called milk?' all mean the same thing: check for milk. "
                    "Ignore filler words that do not change intent (e.g., 'something called', 'any', 'a', 'the', 'maybe', 'I think'). "
                    "Speak naturally and conversationally. Avoid robotic phrasing like 'I don't see something called X'. "
                    "Be concise by default. If the user wants detail, expand. "
                    "Always answer the user's question directly first. "
                    "Formatting: When listing multiple items or points, ALWAYS use bullet points with the '•' character, one per line. "
                    "When listing items, include quantities when known, e.g. '• Charging cable (2)'. "
                    "Follow-ups: When helpful, offer ONE short next step (e.g., add items, move items, link a document, show similar matches, or check items running low). "
                    "Use the provided tools to look up or change inventory/documents when needed; do not guess. Never invent items—only use data from USER_CONTEXT_JSON and tool results. "
                    "If the request is ambiguous or there are multiple plausible matches, ask a brief clarifying question."
                ),
            },
            {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
            {"role": "user", "content": message},
        ]

        assistant_content = ""
        streamed_prefix1 = False
        tool_calls_acc: dict[int, dict] = {}

        print("AI streaming started")
        logger.info("AI streaming started user_id=%s", user_id)

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

        stream1 = _call_with_timeout(
            lambda: _chat_create_low_latency(
                client,
                model=settings.openai_model,
                messages=messages,
                tools=tools,
                tool_choice="auto",
                stream=True,
            ),
            timeout_s=max(0.01, min(5.0, total_deadline - _now_s())),
        )

        total_window = max(0.01, total_deadline - _now_s())
        for chunk in _iter_stream_with_deadlines(stream1, first_token_timeout_s=total_window, total_timeout_s=total_window):
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
                    streamed_any_delta = True
                    if not first_delta_sent:
                        first_delta_sent = True
                        print("First token sent")
                        logger.info("AI first token sent user_id=%s", user_id)
                    yield _evt({"type": "delta", "delta": f"Hi {greet_name} — "})
                    st.greeted = True

                assistant_content += content
                if not tool_calls_acc:
                    streamed_any_delta = True
                    if not first_delta_sent:
                        first_delta_sent = True
                        print("First token sent")
                        logger.info("AI first token sent user_id=%s", user_id)
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

        if not tool_calls_list:
            final_msg = assistant_content or ""
            if greet_name and (not st.greeted) and final_msg.strip() and (not streamed_prefix1):
                final_msg = f"Hi {greet_name} — {final_msg.lstrip()}"
                st.greeted = True

            try:
                create_activity(
                    user_id=user_id,
                    summary="Used Assist",
                    metadata={"type": "ai_chat", "tool": None, "message": message},
                    actor_name=first_name,
                )
            except Exception:
                logger.exception("Failed to write ai_chat activity")

            assistant_message_for_done = final_msg
            yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": final_msg})
            done_sent = True
            print("Stream finished")
            logger.info("AI stream finished user_id=%s", user_id)
            yield from _emit_terminal_done()
            return

        tool_call = tool_calls_list[0]
        tool_name = (tool_call.get("function") or {}).get("name") or ""
        raw_args = (tool_call.get("function") or {}).get("arguments") or "{}"
        try:
            args = json.loads(raw_args)
        except Exception:
            args = {}

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

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

        _update_state_from_tool(user_id=user_id, tool_name=tool_name, result=result)

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

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
        if greet_name and (not st.greeted):
            final_msg = f"Hi {greet_name} — "
            streamed_any_delta = True
            if not first_delta_sent:
                first_delta_sent = True
                print("First token sent")
                logger.info("AI first token sent user_id=%s", user_id)
            yield _evt({"type": "delta", "delta": final_msg})
            st.greeted = True

        stream2 = _call_with_timeout(
            lambda: _chat_create_low_latency(
                client,
                model=settings.openai_model,
                messages=messages,
                stream=True,
            ),
            timeout_s=max(0.01, min(5.0, total_deadline - _now_s())),
        )

        total_window2 = max(0.01, total_deadline - _now_s())
        for chunk in _iter_stream_with_deadlines(stream2, first_token_timeout_s=total_window2, total_timeout_s=total_window2):
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
                streamed_any_delta = True
                if not first_delta_sent:
                    first_delta_sent = True
                    print("First token sent")
                    logger.info("AI first token sent user_id=%s", user_id)
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

        tool_for_done = tool_name
        result_for_done = result
        assistant_message_for_done = final_msg
        yield _evt({"type": "done", "tool": tool_name, "result": result, "assistant_message": final_msg})
        done_sent = True
        print("Stream finished")
        logger.info("AI stream finished user_id=%s", user_id)
        yield from _emit_terminal_done()
        return
    except _AIStreamTimeout:
        print("AI timeout triggered")
        logger.warning("AI timeout user_id=%s", user_id)
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
        done_sent = True
    except Exception:
        err = "unknown"
        try:
            err = str(message)
        except Exception:
            err = "unknown"
        print(f"AI error: {err}")
        logger.exception("AI streaming failed user_id=%s", user_id)
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
        done_sent = True
    finally:
        if not done_sent:
            yield _evt({"type": "done", "tool": tool_for_done, "result": result_for_done, "assistant_message": assistant_message_for_done})
            print("Stream finished")
            logger.info("AI stream finished user_id=%s", user_id)
            yield from _emit_terminal_done()
        else:
            yield from _emit_terminal_done()


def _client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


def run_ai_command(*, user_id: str, message: str, first_name: str | None = None) -> dict:
    settings = get_settings()
    client = _client()

    user_id = (user_id or "").strip()
    if not user_id:
        logger.error("run_ai_command called with empty user_id")
        return {"tool": None, "result": None, "assistant_message": ""}

    st = _get_state(user_id)

    items = search_items_basic(user_id=user_id, q="")[:50]
    logger.info("Assist inventory count for user %s: %s", user_id, len(items))
    docs = list_documents(user_id=user_id, limit=50)
    activity = list_recent_activity(user_id=user_id, limit=25)

    documents_for_ai: list[dict] = []
    for d in docs if isinstance(docs, list) else []:
        if not isinstance(d, dict):
            continue
        filename = (d.get("display_name") or d.get("filename") or "").strip() or "Untitled"
        storage_path = (d.get("storage_path") or "").strip()
        granted = True
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
    should_greet = bool(greet_name) and (not st.greeted)

    context = {
        "inventory_items": items,
        "documents": documents_for_ai,
        "recent_activity": activity,
        "session_state": _state_snapshot(_get_state(user_id)),
        "notes": {
            "documents_text": "Document contents are available.",
            "documents_naming": "When you refer to a document, ALWAYS use its human-readable name/filename (field: name/filename). Never refer to documents as IDs.",
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
                "description": "Read and extract text from a document in the 'documents' storage bucket by storage_path.",
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
                "You are FindEZ Assistant — a fast, highly intelligent, ChatGPT-like assistant that helps the user manage their belongings and inventory. "
                "Your #1 job is to understand intent (not literal phrasing). Treat inventory items as concepts rather than exact string matches. "
                "Examples like 'Do I have milk?', 'Is there milk in my inventory?', and 'Do I have something called milk?' all mean the same thing: check for milk. "
                "Ignore filler words that do not change intent (e.g., 'something called', 'any', 'a', 'the', 'maybe', 'I think'). "
                "Speak naturally and conversationally. Avoid robotic phrasing like 'I don't see something called X'. "
                "Be concise by default. If the user wants detail, expand. "
                "Formatting: When listing multiple items or points, ALWAYS use bullet points with the '•' character, one per line. "
                "When listing items, include quantities when known, e.g. '• Charging cable (2)'. "
                "Follow-ups: When helpful, offer ONE short next step (e.g., add items, move items, link a document, show similar matches, or check items running low). "
                "Use the provided tools to look up or change inventory/documents when needed; do not guess. Never invent items—only use data from USER_CONTEXT_JSON and tool results. "
                "If the request is ambiguous or there are multiple plausible matches, ask a brief clarifying question."
            ),
        },
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    request_start = _now_s()
    total_deadline = request_start + 20.0

    stream1 = _call_with_timeout(
        lambda: _chat_create_low_latency(
            client,
            model=settings.openai_model,
            messages=messages,
            tools=tools,
            tool_choice="auto",
            stream=True,
        ),
        timeout_s=max(0.01, min(5.0, total_deadline - _now_s())),
    )

    assistant_content = ""
    tool_calls_acc: dict[int, dict] = {}
    total_window = max(0.01, total_deadline - _now_s())
    for chunk in _iter_stream_with_deadlines(stream1, first_token_timeout_s=total_window, total_timeout_s=total_window):
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
            assistant_content += content

        d_tool_calls = getattr(delta, "tool_calls", None)
        if d_tool_calls:
            for tc in d_tool_calls:
                idx = getattr(tc, "index", 0)
                existing = tool_calls_acc.setdefault(idx, {"id": "", "function": {"name": "", "arguments": ""}})
                tc_id = getattr(tc, "id", None)
                if tc_id:
                    existing["id"] = tc_id
                fn = getattr(tc, "function", None)
                if fn is None:
                    continue
                name = getattr(fn, "name", None)
                args_part = getattr(fn, "arguments", None)
                if name:
                    existing["function"]["name"] = name
                if args_part:
                    existing["function"]["arguments"] = (existing["function"].get("arguments") or "") + args_part

    tool_calls_list = [tool_calls_acc[k] for k in sorted(tool_calls_acc.keys())] if tool_calls_acc else []
    if not tool_calls_list:
        msg = assistant_content or ""
        if greet_name and (not st.greeted) and msg.strip():
            msg = f"Hi {greet_name} — {msg.lstrip()}"
            st.greeted = True
        return {"tool": None, "result": None, "assistant_message": msg}

    tool_call = tool_calls_list[0]
    tool_name = (tool_call.get("function") or {}).get("name") or ""
    raw_args = (tool_call.get("function") or {}).get("arguments") or "{}"
    try:
        args = json.loads(raw_args)
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

    try:
        stream2 = _call_with_timeout(
            lambda: _chat_create_low_latency(
                client,
                model=settings.openai_model,
                messages=messages,
                stream=True,
            ),
            timeout_s=max(0.01, min(5.0, total_deadline - _now_s())),
        )

        final_msg = ""
        total_window2 = max(0.01, total_deadline - _now_s())
        for chunk in _iter_stream_with_deadlines(stream2, first_token_timeout_s=total_window2, total_timeout_s=total_window2):
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
    except Exception:
        logger.exception("OpenAI ai_command final call failed")
        raise

    if greet_name and (not st.greeted) and final_msg.strip():
        final_msg = f"Hi {greet_name} — {final_msg.lstrip()}"
        st.greeted = True
    return {"tool": tool_name, "result": result, "assistant_message": final_msg}
