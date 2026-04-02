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


def _chat_create_high_accuracy(client: OpenAI, **kwargs):
    base = {
        **kwargs,
    }
    try:
        return client.chat.completions.create(
            **base,
            reasoning_effort="high",
            max_output_tokens=900,
            temperature=0,
        )
    except TypeError:
        try:
            return client.chat.completions.create(
                **base,
                reasoning_effort="high",
                max_completion_tokens=900,
                temperature=0,
            )
        except TypeError:
            return client.chat.completions.create(
                **base,
                max_completion_tokens=900,
                temperature=0,
            )


_INTENT_TOOL = {
    "type": "function",
    "function": {
        "name": "parse_assist_intent",
        "description": "Convert the user's message into a strict structured JSON intent for Assist.",
        "parameters": {
            "type": "object",
            "properties": {
                "domain": {"type": "string", "enum": ["inventory", "documents", "general"]},
                "action": {"type": "string", "enum": ["add", "update", "delete", "query"]},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "quantity": {"type": "number"},
                            "location": {"type": ["string", "null"]},
                            "quantity_is_specified": {"type": "boolean"},
                            "location_is_specified": {"type": "boolean"},
                            "scope": {"type": "string", "enum": ["one", "all"]},
                        },
                        "required": [
                            "name",
                            "quantity",
                            "location",
                            "quantity_is_specified",
                            "location_is_specified",
                            "scope",
                        ],
                        "additionalProperties": False,
                    },
                },
                "query": {"type": ["string", "null"]},
                "updates": {
                    "type": ["object", "null"],
                    "properties": {
                        "name": {"type": ["string", "null"]},
                        "category": {"type": ["string", "null"]},
                        "quantity": {"type": ["number", "null"]},
                        "location": {"type": ["string", "null"]},
                        "barcode": {"type": ["string", "null"]},
                        "purchase_source": {"type": ["string", "null"]},
                        "notes": {"type": ["string", "null"]},
                    },
                    "additionalProperties": False,
                },
                "document": {
                    "type": ["object", "null"],
                    "properties": {
                        "operation": {"type": ["string", "null"], "enum": ["read_text", "grant_access"]},
                        "storage_path": {"type": ["string", "null"]},
                    },
                    "additionalProperties": False,
                },
            },
            "required": ["domain", "action", "items", "query", "updates", "document"],
            "additionalProperties": False,
        },
    },
}


def _safe_str(v: object) -> str:
    try:
        return str(v or "")
    except Exception:
        return ""


def _validate_intent(raw: object) -> tuple[dict | None, str | None]:
    if not isinstance(raw, dict):
        return (None, "intent_not_object")

    domain = _safe_str(raw.get("domain")).strip()
    action = _safe_str(raw.get("action")).strip()
    if domain not in {"inventory", "documents", "general"}:
        return (None, "bad_domain")
    if action not in {"add", "update", "delete", "query"}:
        return (None, "bad_action")

    items_in = raw.get("items")
    if not isinstance(items_in, list):
        return (None, "items_not_list")

    items: list[dict] = []
    for it in items_in:
        if not isinstance(it, dict):
            continue
        name = _safe_str(it.get("name")).strip()
        if not name:
            continue
        qty = it.get("quantity")
        if not isinstance(qty, (int, float)):
            return (None, "bad_quantity")
        loc = it.get("location")
        if loc is not None and not isinstance(loc, str):
            return (None, "bad_location")
        q_spec = it.get("quantity_is_specified")
        l_spec = it.get("location_is_specified")
        if not isinstance(q_spec, bool) or not isinstance(l_spec, bool):
            return (None, "bad_spec_flags")
        scope = _safe_str(it.get("scope")).strip() or "one"
        if scope not in {"one", "all"}:
            scope = "one"

        items.append(
            {
                "name": name,
                "quantity": float(qty),
                "location": (loc.strip() if isinstance(loc, str) and loc.strip() else None),
                "quantity_is_specified": q_spec,
                "location_is_specified": l_spec,
                "scope": scope,
            }
        )

    query = raw.get("query")
    if query is not None and not isinstance(query, str):
        query = None
    query_s = query.strip() if isinstance(query, str) else None

    updates = raw.get("updates")
    if updates is not None and not isinstance(updates, dict):
        updates = None

    if isinstance(updates, dict):
        allowed = {
            "name": (str,),
            "category": (str,),
            "quantity": (int, float),
            "location": (str,),
            "barcode": (str,),
            "purchase_source": (str,),
            "notes": (str,),
        }
        cleaned: dict = {}
        for k, v in updates.items():
            if k not in allowed:
                continue
            if v is None:
                cleaned[k] = None
                continue
            if not isinstance(v, allowed[k]):
                return (None, "bad_updates")
            cleaned[k] = v
        updates = cleaned

    doc = raw.get("document")
    if doc is not None and not isinstance(doc, dict):
        doc = None

    if isinstance(doc, dict):
        op = doc.get("operation")
        sp = doc.get("storage_path")
        if op is not None and not isinstance(op, str):
            return (None, "bad_document")
        if sp is not None and not isinstance(sp, str):
            return (None, "bad_document")
        if isinstance(op, str) and op.strip() and op.strip() not in {"read_text", "grant_access"}:
            return (None, "bad_document")
        doc = {
            "operation": op.strip() if isinstance(op, str) and op.strip() else None,
            "storage_path": sp.strip() if isinstance(sp, str) and sp.strip() else None,
        }

    out = {
        "domain": domain,
        "action": action,
        "items": items,
        "query": query_s if query_s else None,
        "updates": updates,
        "document": doc,
    }

    if domain == "inventory" and action == "add" and not items:
        return (None, "add_requires_items")
    if domain == "inventory" and action in {"update", "delete"} and (not items) and not out["query"]:
        return (None, "update_delete_requires_target")
    if domain == "inventory" and action == "query" and (not items) and not out["query"]:
        return (None, "query_requires_target")

    return (out, None)


def _ai_parse_intent(*, client: OpenAI, model: str, message: str, context: dict) -> tuple[dict | None, str | None]:
    sys = (
        "You are FindEZ Assist's intent parser. You MUST output a single tool call: parse_assist_intent. "
        "Return STRICT JSON that matches the schema. "
        "Never embed a location inside an item name. "
        "Normalize item names (trim filler, prefer singular like pens->pen). "
        "Normalize locations to a canonical numeric form when applicable (e.g., 'third drawer' -> 'drawer 3'). "
        "If quantity is not explicitly stated, quantity=1 and quantity_is_specified=false. "
        "If location is not explicitly stated, set location=null and location_is_specified=false. "
        "Use scope='all' only when clearly requested (all/every). "
        "For general conversation, domain='general', action='query', items=[], query=null."
    )

    try:
        resp = _chat_create_high_accuracy(
            client,
            model=model,
            messages=[
                {"role": "system", "content": sys},
                {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
                {"role": "user", "content": message},
            ],
            tools=[_INTENT_TOOL],
            tool_choice={"type": "function", "function": {"name": "parse_assist_intent"}},
        )
    except Exception:
        logger.exception("Assist intent parsing failed")
        return (None, "parse_failed")

    tool_calls = getattr(resp.choices[0].message, "tool_calls", None) or []
    if not tool_calls:
        return (None, "no_tool_call")

    try:
        raw = json.loads(tool_calls[0].function.arguments)
    except Exception:
        return (None, "bad_json")

    return _validate_intent(raw)


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


def _clean_leading_articles(s: str) -> str:
    out = (s or "").strip()
    out = re.sub(r"^(?:the|a|an|my)\s+", "", out, flags=re.IGNORECASE)
    return out.strip()


def _split_location_relaxed(rest: str) -> tuple[str, str | None]:
    s = (rest or "").strip()
    if not s:
        return ("", None)

    low = _norm(s)
    candidates = [
        " somewhere in ",
        " somewhere at ",
        " somewhere on ",
        " into ",
        " inside ",
        " to ",
        " in ",
        " at ",
        " on ",
    ]

    best_idx = -1
    best_token = ""
    for tok in candidates:
        i = low.rfind(tok)
        if i > best_idx:
            best_idx = i
            best_token = tok

    if best_idx <= 0:
        return (s, None)

    left = s[:best_idx].strip()
    right = s[best_idx + len(best_token) :].strip()
    if not left or not right:
        return (s, None)

    right = right.strip().strip(".!")
    right = _clean_leading_articles(right)
    return (left, right or None)


def _clean_item_name(raw: str) -> str:
    s = (raw or "").strip().strip(".!")
    s = _clean_leading_articles(s)
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def _parse_add_items_structured(user_message: str) -> list[dict]:
    text = (user_message or "").strip()
    if not text:
        return []

    m = re.match(r"^\s*(add|put|place|store|insert|stash|drop)\b\s*(.*)$", text, flags=re.IGNORECASE)
    body = (m.group(2) if m else text).strip()
    if not body:
        return []

    body = body.replace(";", " and ")

    global_loc = None
    mloc = re.search(r"\bsomewhere\s+(?:in|at|on)\s+(.+)$", body, flags=re.IGNORECASE)
    if mloc:
        global_loc = _clean_leading_articles((mloc.group(1) or "").strip()) or None

    if global_loc is None:
        left2, loc2 = _split_location_relaxed(body)
        if loc2 and (" and " in f" {_norm(left2)} " or "," in body or "&" in body):
            global_loc = loc2
            body = left2

    parts = [p.strip() for p in re.split(r"\s*(?:,|\band\b|&)\s*", body, flags=re.IGNORECASE) if p.strip()]
    if not parts:
        parts = [body]

    out: list[dict] = []
    for p in parts:
        p2 = re.sub(r"\bsomewhere\s+(?:in|at|on)\s+.+$", "", p, flags=re.IGNORECASE).strip()
        if not p2:
            continue

        left, loc = _split_location_relaxed(p2)
        qty, rest = _extract_qty_and_rest(left)
        if qty is None:
            qty = 1
        name = _clean_item_name(rest)
        if not name:
            continue

        out.append({"name": name, "quantity": int(qty), "location": loc or global_loc})

    return out


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
    total_deadline = request_start + 60.0

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

        ctx_ready.wait(timeout=2.5)

        documents_for_ai: list[dict] = []
        for d in docs if isinstance(docs, list) else []:
            if not isinstance(d, dict):
                continue
            filename = d.get("filename") or "Untitled"
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

        intent, intent_err = _ai_parse_intent(
            client=client,
            model=settings.openai_model,
            message=message,
            context=context,
        )

        if intent is None:
            fail_msg = "I couldn’t understand that request. Try rephrasing it with item names and (optionally) quantities and locations."
            yield _evt({"type": "delta", "delta": fail_msg})
            yield _evt({"type": "done", "tool": None, "result": {"error": intent_err or "parse_failed"}, "assistant_message": fail_msg})
            done_sent = True
            yield from _emit_terminal_done()
            return

        tool_name: str | None = None
        tool_result: dict | list | None = None
        hard_failure = False

        domain = intent.get("domain")
        action = intent.get("action")

        if domain == "inventory":
            if action == "add":
                tool_name = "add_inventory_items"
                yield _evt({"type": "status", "message": "Adding items…"})
                inserted: list[dict] = []
                merged: list[dict] = []
                failures: list[dict] = []
                for it in intent.get("items") or []:
                    if not isinstance(it, dict):
                        continue
                    name = _safe_str(it.get("name")).strip()
                    if not name:
                        continue
                    try:
                        delta_qty = int(float(it.get("quantity")))
                    except Exception:
                        delta_qty = 1
                    if delta_qty <= 0:
                        failures.append({"name": name, "reason": "quantity_must_be_positive"})
                        continue
                    location = it.get("location") if isinstance(it.get("location"), str) else None
                    location = location.strip() if isinstance(location, str) and location.strip() else "Unsorted"

                    try:
                        candidates = search_items_basic(user_id=user_id, q=name)
                    except Exception:
                        logger.exception("search_items_basic failed during merge")
                        candidates = []

                    match = None
                    for c in candidates if isinstance(candidates, list) else []:
                        if not isinstance(c, dict):
                            continue
                        if _norm(_safe_str(c.get("name"))) == _norm(name):
                            match = c
                            break

                    if match and _safe_str(match.get("item_id")).strip():
                        item_id = _safe_str(match.get("item_id")).strip()
                        prev_qty = match.get("quantity")
                        try:
                            prev_qty_i = int(prev_qty) if isinstance(prev_qty, (int, float)) else int(str(prev_qty))
                        except Exception:
                            prev_qty_i = 0
                        next_qty = prev_qty_i + delta_qty
                        try:
                            updated = update_item(user_id=user_id, item_id=item_id, updates={"quantity": next_qty})
                            if updated:
                                merged.append(updated)
                            else:
                                failures.append({"name": name, "reason": "merge_update_failed"})
                        except Exception:
                            logger.exception("update_item failed during merge")
                            failures.append({"name": name, "reason": "merge_update_failed"})
                    else:
                        try:
                            created = add_item(
                                user_id=user_id,
                                item={
                                    "name": name,
                                    "category": "Unsorted",
                                    "quantity": delta_qty,
                                    "location": location,
                                },
                            )
                            inserted.append(created)
                        except Exception:
                            logger.exception("add_item failed")
                            failures.append({"name": name, "reason": "insert_failed"})

                tool_result = {"inserted": inserted, "merged": merged, "failures": failures}

            elif action == "query":
                tool_name = "search_inventory"
                yield _evt({"type": "status", "message": "Checking your inventory…"})
                q = intent.get("query")
                if not q:
                    names = [
                        _safe_str(i.get("name")).strip()
                        for i in (intent.get("items") or [])
                        if isinstance(i, dict) and _safe_str(i.get("name")).strip()
                    ]
                    q = " ".join(names)
                try:
                    tool_result = search_items_basic(user_id=user_id, q=_safe_str(q))
                except Exception:
                    logger.exception("search_items_basic failed")
                    hard_failure = True
                    tool_result = {"ok": False, "error": "tool_failed"}

            elif action == "delete":
                tool_name = "delete_inventory_items"
                yield _evt({"type": "status", "message": "Removing items…"})
                deleted: list[str] = []
                failures: list[dict] = []
                for it in intent.get("items") or []:
                    if not isinstance(it, dict):
                        continue
                    name = _safe_str(it.get("name")).strip()
                    if not name:
                        continue
                    scope = _safe_str(it.get("scope")).strip() or "one"
                    limit = None if scope == "all" else 1
                    try:
                        candidates = search_items_basic(user_id=user_id, q=name)
                    except Exception:
                        candidates = []
                    picked = []
                    for c in candidates if isinstance(candidates, list) else []:
                        if not isinstance(c, dict):
                            continue
                        if _norm(_safe_str(c.get("name"))) == _norm(name):
                            picked.append(c)
                    if limit is not None:
                        picked = picked[:limit]
                    if not picked:
                        failures.append({"name": name, "reason": "not_found"})
                        continue
                    for c in picked:
                        item_id = _safe_str(c.get("item_id")).strip()
                        if not item_id:
                            failures.append({"name": name, "reason": "missing_item_id"})
                            continue
                        try:
                            ok = delete_item(user_id=user_id, item_id=item_id)
                            if ok:
                                deleted.append(item_id)
                            else:
                                failures.append({"name": name, "reason": "delete_failed"})
                        except Exception:
                            logger.exception("delete_item failed")
                            failures.append({"name": name, "reason": "delete_failed"})
                tool_result = {"deleted": deleted, "failures": failures}

            elif action == "update":
                tool_name = "update_inventory_items"
                yield _evt({"type": "status", "message": "Updating inventory…"})
                updated: list[dict] = []
                failures: list[dict] = []
                shared_updates = intent.get("updates") if isinstance(intent.get("updates"), dict) else {}
                for it in intent.get("items") or []:
                    if not isinstance(it, dict):
                        continue
                    name = _safe_str(it.get("name")).strip()
                    if not name:
                        continue
                    scope = _safe_str(it.get("scope")).strip() or "one"
                    limit = None if scope == "all" else 1

                    per_updates = {k: v for k, v in shared_updates.items() if v is not None} if isinstance(shared_updates, dict) else {}
                    if it.get("location_is_specified") is True and isinstance(it.get("location"), str) and it.get("location").strip() and "location" not in per_updates:
                        per_updates["location"] = it.get("location").strip()
                    if it.get("quantity_is_specified") is True and isinstance(it.get("quantity"), (int, float)) and "quantity" not in per_updates:
                        per_updates["quantity"] = int(float(it.get("quantity")))

                    if not per_updates:
                        failures.append({"name": name, "reason": "no_updates"})
                        continue

                    try:
                        candidates = search_items_basic(user_id=user_id, q=name)
                    except Exception:
                        candidates = []
                    picked = []
                    for c in candidates if isinstance(candidates, list) else []:
                        if not isinstance(c, dict):
                            continue
                        if _norm(_safe_str(c.get("name"))) == _norm(name):
                            picked.append(c)
                    if limit is not None:
                        picked = picked[:limit]
                    if not picked:
                        failures.append({"name": name, "reason": "not_found"})
                        continue
                    for c in picked:
                        item_id = _safe_str(c.get("item_id")).strip()
                        if not item_id:
                            failures.append({"name": name, "reason": "missing_item_id"})
                            continue
                        try:
                            out = update_item(user_id=user_id, item_id=item_id, updates=per_updates)
                            if out:
                                updated.append(out)
                            else:
                                failures.append({"name": name, "reason": "update_failed"})
                        except Exception:
                            logger.exception("update_item failed")
                            failures.append({"name": name, "reason": "update_failed"})
                tool_result = {"updated": updated, "failures": failures}

        elif domain == "documents":
            doc = intent.get("document") if isinstance(intent.get("document"), dict) else None
            op = _safe_str((doc or {}).get("operation")).strip()
            storage_path = _safe_str((doc or {}).get("storage_path")).strip()
            if op == "grant_access":
                tool_name = "grant_document_ai_access"
                yield _evt({"type": "status", "message": "Updating access…"})
                try:
                    ok = grant_ai_access(user_id=user_id, storage_path=storage_path)
                    tool_result = {"ok": bool(ok)}
                except Exception:
                    logger.exception("grant_ai_access failed")
                    hard_failure = True
                    tool_result = {"ok": False, "error": "tool_failed"}
            elif op == "read_text":
                tool_name = "read_document_text"
                yield _evt({"type": "status", "message": "Reading document…"})
                try:
                    supabase = get_supabase_admin()
                    raw = supabase.storage.from_("documents").download(storage_path)
                    text, _truncated = extract_text_from_upload(filename=storage_path, mime_type=None, content=raw)
                    tool_result = {"ok": True, "text": (text or "")[:12000]}
                except Exception:
                    logger.exception("read_document_text failed")
                    hard_failure = True
                    tool_result = {"ok": False, "error": "tool_failed"}
            else:
                tool_name = None
                tool_result = {"ok": False, "error": "unknown_document_operation"}
                hard_failure = True

        # domain == general => no tool execution

        _update_state_from_tool(user_id=user_id, tool_name=tool_name, result=tool_result)

        if hard_failure:
            fail_msg = "Could not complete that due to an error."
            yield _evt({"type": "delta", "delta": fail_msg})
            yield _evt({"type": "done", "tool": tool_name, "result": tool_result, "assistant_message": fail_msg})
            done_sent = True
            yield from _emit_terminal_done()
            return

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

        response_messages: list[dict] = [
            {
                "role": "system",
                "content": (
                    "You are FindEZ Assistant. Respond naturally. "
                    "IMPORTANT: You must base any success/failure confirmation ONLY on TOOL_RESULT_JSON. "
                    "Do NOT claim an add/update/delete succeeded unless TOOL_RESULT_JSON clearly indicates it did. "
                    "If TOOL_RESULT_JSON indicates zero items affected, say that it did not complete as requested. "
                    "Do not ask for confirmation; execute first, then report."
                ),
            },
            {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
            {"role": "system", "content": f"PARSED_INTENT_JSON:\n{json.dumps(intent, ensure_ascii=False)}"},
            {"role": "system", "content": f"TOOL_RESULT_JSON:\n{json.dumps(tool_result, ensure_ascii=False)}"},
            {"role": "user", "content": message},
        ]

        final_msg = ""
        stream2 = _call_with_timeout(
            lambda: _chat_create_low_latency(
                client,
                model=settings.openai_model,
                messages=response_messages,
                stream=True,
            ),
            timeout_s=max(0.01, min(8.0, total_deadline - _now_s())),
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
                yield _evt({"type": "delta", "delta": content})

        try:
            create_activity(
                user_id=user_id,
                summary="Used Assist",
                metadata={"type": "ai_chat", "tool": tool_name, "message": message, "intent": intent},
                actor_name=first_name,
            )
        except Exception:
            logger.exception("Failed to write ai_chat activity")

        yield _evt({"type": "done", "tool": tool_name, "result": tool_result, "assistant_message": final_msg})
        done_sent = True
        yield from _emit_terminal_done()
        return

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
            if final_msg.strip():
                chunk_size = 120
                for i in range(0, len(final_msg), chunk_size):
                    part = final_msg[i : i + chunk_size]
                    if not part:
                        continue
                    streamed_any_delta = True
                    if not first_delta_sent:
                        first_delta_sent = True
                        print("First token sent")
                        logger.info("AI first token sent user_id=%s", user_id)
                    yield _evt({"type": "delta", "delta": part})
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

        # AI-first: no heuristic parsing or string-based overrides before tool execution.

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

        status_msg = None
        if tool_name in {"add_inventory_item", "add_inventory_items"}:
            status_msg = "Adding items…"
        elif tool_name == "update_inventory_items":
            status_msg = "Updating inventory…"
        elif tool_name in {"delete_inventory_item", "delete_inventory_items"}:
            status_msg = "Removing items…"
        elif tool_name == "search_inventory":
            status_msg = "Checking your inventory…"
        elif tool_name == "read_document_text":
            status_msg = "Reading document…"
        elif tool_name == "grant_document_ai_access":
            status_msg = "Updating access…"

        if status_msg:
            yield _evt({"type": "status", "message": status_msg})
            if not first_delta_sent:
                first_delta_sent = True
                print("First token sent")
                logger.info("AI first token sent user_id=%s", user_id)

        result: dict | list | None
        tool_exception = None
        try:
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
        except Exception as e:
            tool_exception = e
            logger.exception("Tool execution failed tool=%s user_id=%s", tool_name, user_id)
            result = {"ok": False, "error": "tool_failed"}

        hard_failure = tool_exception is not None
        if not hard_failure and isinstance(result, dict):
            if result.get("error") in {"Unknown tool", "tool_failed"}:
                hard_failure = True
            if tool_name in {"grant_document_ai_access", "read_document_text"} and result.get("ok") is False:
                hard_failure = True

        _update_state_from_tool(user_id=user_id, tool_name=tool_name, result=result)

        if hard_failure:
            fail_msg = "That didn’t work. Please try again."
            tool_for_done = tool_name
            result_for_done = result
            assistant_message_for_done = fail_msg
            yield _evt({"type": "delta", "delta": fail_msg})
            yield _evt({"type": "done", "tool": tool_name, "result": result, "assistant_message": fail_msg})
            done_sent = True
            print("Stream finished")
            logger.info("AI stream finished user_id=%s", user_id)
            yield from _emit_terminal_done()
            return

        no_op_msg = None
        if tool_name == "add_inventory_items" and isinstance(result, dict):
            if not result.get("inserted"):
                no_op_msg = "I couldn’t add those items. Please try again."
        elif tool_name == "update_inventory_items" and isinstance(result, dict):
            if not result.get("updated"):
                no_op_msg = "I couldn’t update anything matching that."
        elif tool_name == "delete_inventory_items" and isinstance(result, dict):
            if not result.get("deleted"):
                no_op_msg = "I couldn’t find anything to remove."
        elif tool_name == "delete_inventory_item" and isinstance(result, dict):
            if result.get("deleted") is False:
                no_op_msg = "I couldn’t remove that item."

        if no_op_msg:
            tool_for_done = tool_name
            result_for_done = result
            assistant_message_for_done = no_op_msg
            yield _evt({"type": "delta", "delta": no_op_msg})
            yield _evt({"type": "done", "tool": tool_name, "result": result, "assistant_message": no_op_msg})
            done_sent = True
            print("Stream finished")
            logger.info("AI stream finished user_id=%s", user_id)
            yield from _emit_terminal_done()
            return

        if _now_s() > total_deadline:
            raise _AIStreamTimeout("timeout")

        # Do not include any pre-tool natural language content in the tool-call message.
        # This prevents pre-emptive confirmations from influencing the post-tool response.
        assistant_content_for_tool = ""
        messages.append(
            {
                "role": "assistant",
                "content": assistant_content_for_tool,
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

        messages.append(
            {
                "role": "system",
                "content": (
                    "IMPORTANT: You must base any success/failure confirmation ONLY on the tool result JSON. "
                    "Do NOT claim an add/update/delete succeeded unless the tool result clearly indicates it did. "
                    "If the result indicates zero items affected or deleted=false, say that it did not complete as requested."
                ),
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
        filename = d.get("filename") or "Untitled"
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

    intent, intent_err = _ai_parse_intent(
        client=client,
        model=settings.openai_model,
        message=message,
        context=context,
    )

    if intent is None:
        msg = "I couldn’t understand that request. Try rephrasing it with item names and (optionally) quantities and locations."
        return {"tool": None, "result": {"error": intent_err or "parse_failed"}, "assistant_message": msg}

    tool_name: str | None = None
    tool_result: dict | list | None = None
    hard_failure = False

    domain = intent.get("domain")
    action = intent.get("action")

    if domain == "inventory":
        if action == "add":
            tool_name = "add_inventory_items"
            inserted: list[dict] = []
            merged: list[dict] = []
            failures: list[dict] = []
            for it in intent.get("items") or []:
                if not isinstance(it, dict):
                    continue
                name = _safe_str(it.get("name")).strip()
                if not name:
                    continue
                try:
                    delta_qty = int(float(it.get("quantity")))
                except Exception:
                    delta_qty = 1
                if delta_qty <= 0:
                    failures.append({"name": name, "reason": "quantity_must_be_positive"})
                    continue
                location = it.get("location") if isinstance(it.get("location"), str) else None
                location = location.strip() if isinstance(location, str) and location.strip() else "Unsorted"

                try:
                    candidates = search_items_basic(user_id=user_id, q=name)
                except Exception:
                    logger.exception("search_items_basic failed during merge")
                    candidates = []

                match = None
                for c in candidates if isinstance(candidates, list) else []:
                    if not isinstance(c, dict):
                        continue
                    if _norm(_safe_str(c.get("name"))) == _norm(name):
                        match = c
                        break

                if match and _safe_str(match.get("item_id")).strip():
                    item_id = _safe_str(match.get("item_id")).strip()
                    prev_qty = match.get("quantity")
                    try:
                        prev_qty_i = int(prev_qty) if isinstance(prev_qty, (int, float)) else int(str(prev_qty))
                    except Exception:
                        prev_qty_i = 0
                    next_qty = prev_qty_i + delta_qty
                    try:
                        updated = update_item(user_id=user_id, item_id=item_id, updates={"quantity": next_qty})
                        if updated:
                            merged.append(updated)
                        else:
                            failures.append({"name": name, "reason": "merge_update_failed"})
                    except Exception:
                        logger.exception("update_item failed during merge")
                        failures.append({"name": name, "reason": "merge_update_failed"})
                else:
                    try:
                        created = add_item(
                            user_id=user_id,
                            item={
                                "name": name,
                                "category": "Unsorted",
                                "quantity": delta_qty,
                                "location": location,
                            },
                        )
                        inserted.append(created)
                    except Exception:
                        logger.exception("add_item failed")
                        failures.append({"name": name, "reason": "insert_failed"})

            tool_result = {"inserted": inserted, "merged": merged, "failures": failures}

        elif action == "query":
            tool_name = "search_inventory"
            q = intent.get("query")
            if not q:
                names = [
                    _safe_str(i.get("name")).strip()
                    for i in (intent.get("items") or [])
                    if isinstance(i, dict) and _safe_str(i.get("name")).strip()
                ]
                q = " ".join(names)
            try:
                tool_result = search_items_basic(user_id=user_id, q=_safe_str(q))
            except Exception:
                logger.exception("search_items_basic failed")
                hard_failure = True
                tool_result = {"ok": False, "error": "tool_failed"}

        elif action == "delete":
            tool_name = "delete_inventory_items"
            deleted: list[str] = []
            failures: list[dict] = []
            for it in intent.get("items") or []:
                if not isinstance(it, dict):
                    continue
                name = _safe_str(it.get("name")).strip()
                if not name:
                    continue
                scope = _safe_str(it.get("scope")).strip() or "one"
                limit = None if scope == "all" else 1
                try:
                    candidates = search_items_basic(user_id=user_id, q=name)
                except Exception:
                    candidates = []
                picked = []
                for c in candidates if isinstance(candidates, list) else []:
                    if not isinstance(c, dict):
                        continue
                    if _norm(_safe_str(c.get("name"))) == _norm(name):
                        picked.append(c)
                if limit is not None:
                    picked = picked[:limit]
                if not picked:
                    failures.append({"name": name, "reason": "not_found"})
                    continue
                for c in picked:
                    item_id = _safe_str(c.get("item_id")).strip()
                    if not item_id:
                        failures.append({"name": name, "reason": "missing_item_id"})
                        continue
                    try:
                        ok = delete_item(user_id=user_id, item_id=item_id)
                        if ok:
                            deleted.append(item_id)
                        else:
                            failures.append({"name": name, "reason": "delete_failed"})
                    except Exception:
                        logger.exception("delete_item failed")
                        failures.append({"name": name, "reason": "delete_failed"})
            tool_result = {"deleted": deleted, "failures": failures}

        elif action == "update":
            tool_name = "update_inventory_items"
            updated: list[dict] = []
            failures: list[dict] = []
            shared_updates = intent.get("updates") if isinstance(intent.get("updates"), dict) else {}
            for it in intent.get("items") or []:
                if not isinstance(it, dict):
                    continue
                name = _safe_str(it.get("name")).strip()
                if not name:
                    continue
                scope = _safe_str(it.get("scope")).strip() or "one"
                limit = None if scope == "all" else 1

                per_updates = {k: v for k, v in shared_updates.items() if v is not None} if isinstance(shared_updates, dict) else {}
                if it.get("location_is_specified") is True and isinstance(it.get("location"), str) and it.get("location").strip() and "location" not in per_updates:
                    per_updates["location"] = it.get("location").strip()
                if it.get("quantity_is_specified") is True and isinstance(it.get("quantity"), (int, float)) and "quantity" not in per_updates:
                    per_updates["quantity"] = int(float(it.get("quantity")))

                if not per_updates:
                    failures.append({"name": name, "reason": "no_updates"})
                    continue

                try:
                    candidates = search_items_basic(user_id=user_id, q=name)
                except Exception:
                    candidates = []
                picked = []
                for c in candidates if isinstance(candidates, list) else []:
                    if not isinstance(c, dict):
                        continue
                    if _norm(_safe_str(c.get("name"))) == _norm(name):
                        picked.append(c)
                if limit is not None:
                    picked = picked[:limit]
                if not picked:
                    failures.append({"name": name, "reason": "not_found"})
                    continue
                for c in picked:
                    item_id = _safe_str(c.get("item_id")).strip()
                    if not item_id:
                        failures.append({"name": name, "reason": "missing_item_id"})
                        continue
                    try:
                        out = update_item(user_id=user_id, item_id=item_id, updates=per_updates)
                        if out:
                            updated.append(out)
                        else:
                            failures.append({"name": name, "reason": "update_failed"})
                    except Exception:
                        logger.exception("update_item failed")
                        failures.append({"name": name, "reason": "update_failed"})
            tool_result = {"updated": updated, "failures": failures}

    elif domain == "documents":
        doc = intent.get("document") if isinstance(intent.get("document"), dict) else None
        op = _safe_str((doc or {}).get("operation")).strip()
        storage_path = _safe_str((doc or {}).get("storage_path")).strip()
        if op == "grant_access":
            tool_name = "grant_document_ai_access"
            try:
                ok = grant_ai_access(user_id=user_id, storage_path=storage_path)
                tool_result = {"ok": bool(ok)}
            except Exception:
                logger.exception("grant_ai_access failed")
                hard_failure = True
                tool_result = {"ok": False, "error": "tool_failed"}
        elif op == "read_text":
            tool_name = "read_document_text"
            try:
                supabase = get_supabase_admin()
                raw = supabase.storage.from_("documents").download(storage_path)
                text, _truncated = extract_text_from_upload(filename=storage_path, mime_type=None, content=raw)
                tool_result = {"ok": True, "text": (text or "")[:12000]}
            except Exception:
                logger.exception("read_document_text failed")
                hard_failure = True
                tool_result = {"ok": False, "error": "tool_failed"}
        else:
            tool_name = None
            tool_result = {"ok": False, "error": "unknown_document_operation"}
            hard_failure = True

    _update_state_from_tool(user_id=user_id, tool_name=tool_name, result=tool_result)

    if hard_failure:
        fail_msg = "Could not complete that due to an error."
        return {"tool": tool_name, "result": tool_result, "assistant_message": fail_msg}

    response_messages: list[dict] = [
        {
            "role": "system",
            "content": (
                "You are FindEZ Assistant. Respond naturally. "
                "IMPORTANT: You must base any success/failure confirmation ONLY on TOOL_RESULT_JSON. "
                "Do NOT claim an add/update/delete succeeded unless TOOL_RESULT_JSON clearly indicates it did. "
                "If TOOL_RESULT_JSON indicates zero items affected, say that it did not complete as requested. "
                "Do not ask for confirmation; execute first, then report."
            ),
        },
        {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
        {"role": "system", "content": f"PARSED_INTENT_JSON:\n{json.dumps(intent, ensure_ascii=False)}"},
        {"role": "system", "content": f"TOOL_RESULT_JSON:\n{json.dumps(tool_result, ensure_ascii=False)}"},
        {"role": "user", "content": message},
    ]

    try:
        resp2 = _chat_create_low_latency(
            client,
            model=settings.openai_model,
            messages=response_messages,
        )
        final_msg = _safe_str(resp2.choices[0].message.content)
    except Exception:
        logger.exception("OpenAI ai_command final call failed")
        final_msg = ""

    if greet_name and (not st.greeted) and final_msg.strip():
        final_msg = f"Hi {greet_name} — {final_msg.lstrip()}"
        st.greeted = True

    return {"tool": tool_name, "result": tool_result, "assistant_message": final_msg}
