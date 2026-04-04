from __future__ import annotations

from dataclasses import dataclass
import anyio
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

    # Extract domain and action with fallbacks
    domain = _safe_str(raw.get("domain")).strip()
    action = _safe_str(raw.get("action")).strip()
    
    # Allow flexible domain/action with fallbacks
    if domain not in {"inventory", "documents", "general"}:
        domain = "general"
    if action not in {"add", "update", "delete", "query"}:
        action = "query"

    # Handle items more permissively
    items_in = raw.get("items")
    items: list[dict] = []
    
    if isinstance(items_in, list):
        for it in items_in:
            if not isinstance(it, dict):
                continue
            name = _safe_str(it.get("name")).strip()
            if not name:
                continue
            
            # Be permissive with quantity - default to 1 if invalid
            qty = it.get("quantity", 1)
            if not isinstance(qty, (int, float)):
                try:
                    qty = float(str(qty))
                except:
                    qty = 1
            
            # Be permissive with location
            loc = it.get("location")
            if loc is not None and not isinstance(loc, str):
                loc = None
            
            # Be permissive with spec flags
            q_spec = it.get("quantity_is_specified", True)
            l_spec = it.get("location_is_specified", True)
            if not isinstance(q_spec, bool):
                q_spec = True
            if not isinstance(l_spec, bool):
                l_spec = True
            
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

    # Handle query permissively
    query = raw.get("query")
    if query is not None and not isinstance(query, str):
        query = None
    query_s = query.strip() if isinstance(query, str) else None

    # Handle updates permissively
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
                continue  # Skip invalid updates instead of failing
            cleaned[k] = v
        updates = cleaned

    # Handle document permissively
    doc = raw.get("document")
    if doc is not None and not isinstance(doc, dict):
        doc = None

    if isinstance(doc, dict):
        op = doc.get("operation")
        sp = doc.get("storage_path")
        if op is not None and not isinstance(op, str):
            op = None
        if sp is not None and not isinstance(sp, str):
            sp = None
        if isinstance(op, str) and op.strip() and op.strip() not in {"read_text", "grant_access"}:
            op = None  # Skip invalid operations instead of failing
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

    # Remove strict requirements - allow everything through
    # Only fail if completely invalid JSON structure
    return (out, None)


def _ai_parse_intent(*, client: OpenAI, model: str, message: str, context: dict) -> tuple[dict | None, str | None]:
    # Stage 1: Free-form understanding
    understanding_sys = (
        "You are FindEZ Assist's understanding layer. Your job is to interpret the user's natural language and reason about what they actually want. "
        "Think freely about meaning, context, and intent. Don't worry about structure yet - just understand deeply. "
        "Consider: What items are they talking about? How many? Where should these items go? What action do they want? "
        "Handle messy grammar, casual phrasing, implied quantities, and unclear locations. Make reasonable inferences. "
        "If something is genuinely ambiguous, note it briefly."
    )

    try:
        understanding_resp = _chat_create_high_accuracy(
            client,
            model=model,
            messages=[
                {"role": "system", "content": understanding_sys},
                {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
                {"role": "user", "content": message},
            ],
            max_completion_tokens=300,
            temperature=0.3,
        )
        understanding = getattr(understanding_resp.choices[0].message, "content", "") or ""
    except Exception:
        logger.exception("Assist understanding stage failed")
        understanding = ""

    # Stage 2: Convert understanding to structured intent
    structuring_sys = (
        "You are FindEZ Assist's intent structurer. Convert the AI's understanding into structured JSON. "
        "First understand the user's intent deeply. Then convert it into structured JSON. "
        "Prioritize correct meaning over strict formatting. "
        "You may return structured JSON directly in the response. "
        "You are NOT required to use a tool call if unnecessary. "
        "Based on the understanding, extract: domain, action, items with name/quantity/location, query, updates, document. "
        "CRITICAL: Never embed location inside item name. Always separate them. "
        "Normalize item names (trim filler, prefer singular like pens->pen). "
        # "Normalize locations to canonical form (e.g., 'third drawer' -> 'drawer 3')."
        "If quantity not explicitly stated, quantity=1 and quantity_is_specified=false. "
        "If location not explicitly stated, location=null and location_is_specified=false. "
        "Use scope='all' only when clearly requested (all/every). "
        "For general conversation, domain='general', action='query', items=[], query=null. "
        "You MUST use memory when the user refers to previous items (e.g. 'them', 'those', 'it')."
    )

    try:
        structuring_resp = _chat_create_high_accuracy(
            client,
            model=model,
            messages=[
                {"role": "system", "content": structuring_sys},
                {"role": "system", "content": f"USER_CONTEXT_JSON:\n{json.dumps(context, ensure_ascii=False)}"},
                {"role": "user", "content": message},
                {"role": "assistant", "content": f"AI Understanding:\n{understanding}"},
            ],
            tools=[_INTENT_TOOL],
            tool_choice="auto",
        )
    except Exception:
        logger.exception("Assist intent structuring failed")
        return (None, "structure_failed")

    message = structuring_resp.choices[0].message
    tool_calls = getattr(message, "tool_calls", None) or []
    content = getattr(message, "content", None)
    
    raw = None
    if tool_calls:
        # Try tool call first
        try:
            raw = json.loads(tool_calls[0].function.arguments)
        except Exception:
            pass
    
    if raw is None and content:
        # Fallback: parse raw JSON from content
        try:
            raw = json.loads(content)
        except Exception:
            return (None, "no_structured_output")
    
    if raw is None:
        return (None, "no_structured_output")

    intent, intent_err = _validate_intent(raw)
    if intent is None:
        return (None, intent_err)
    
    return (intent, None)


def _semantic_cleanup(intent: dict) -> dict:
    LOCATION_WORDS = ["drawer", "box", "shelf", "cabinet", "bin", "closet", "bag", "container"]
    
    for item in intent.get("items", []):
        name = item.get("name", "")
        location = item.get("location")
        
        # Check if location words are in the item name
        for w in LOCATION_WORDS:
            if w in name.lower():
                # Remove location words from item name
                name = re.sub(rf"\b{w}\b.*", "", name, flags=re.IGNORECASE).strip()
                item["name"] = name
                
                # If location is missing, assign the extracted location word
                if not location:
                    # Try to extract the full location phrase
                    match = re.search(rf"\b{w}\b.*", name.lower(), flags=re.IGNORECASE)
                    if match:
                        extracted_loc = match.group(0)
                        item["location"] = extracted_loc
                    else:
                        item["location"] = w
                break
    
    return intent


def _get_openai_client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


async def reason_about_request(message: str, context: dict) -> dict:
    client = _get_openai_client()
    model = get_settings().openai_model
    
    system_prompt = (
        "You are an intelligent reasoning layer for an inventory assistant.\n\n"
        "Think about the user's request BEFORE execution.\n\n"
        "Decide:\n"
        "- what the user REALLY wants\n"
        "- if it is safe to execute immediately\n"
        "- if clarification is needed\n\n"
        "Return STRICT JSON ONLY:\n\n"
        "{\n"
        '  "intent": "add" | "remove" | "update" | "query" | "plan" | "unknown",\n'
        '  "confidence": number (0-1),\n'
        '  "needs_clarification": boolean,\n'
        '  "reasoning": string\n'
        "}"
    )
    
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": message}
        ],
        temperature=0.2,
        max_tokens=300
    )
    
    content = resp.choices[0].message.content.strip()
    
    try:
        return json.loads(content)
    except:
        return {
            "intent": "unknown",
            "confidence": 0.0,
            "needs_clarification": False,
            "reasoning": "failed_to_parse"
        }


async def parse_user_intent(message: str, context: dict) -> dict:
    """Parse user message into structured intent using OpenAI."""
    client = _get_openai_client()
    model = get_settings().openai_model
    
    system_prompt = (
        "You are an AI inventory assistant.\n\n"
        "Your job is to convert natural language into structured JSON.\n\n"
        "Rules:\n"
        "* ALWAYS return valid JSON\n"
        "* DO NOT include explanations\n"
        "* DO NOT include text outside JSON\n"
        "* Normalize items (pens → pen)\n"
        "* Convert locations (third drawer → drawer 3)\n"
        "* Extract attributes (type 4 screws → name=screw, attribute=type 4)\n"
        "* If quantity missing, default to 1\n"
        "* Support multiple items\n\n"
        "Return format:\n\n"
        "{\n"
        '"intent": "add" | "remove" | "update" | "query" | "plan",\n'
        '"items": [\n'
        '{\n'
        '"name": string,\n'
        '"quantity": number,\n'
        '"location": string | null,\n'
        '"attributes": string | null\n'
        "}\n"
        "],\n"
        '"query": string | null\n'
        "}"
    )
    
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": message}
            ],
            temperature=0.1,
            max_tokens=500
        )
        
        content = resp.choices[0].message.content
        if not content:
            raise ValueError("Empty response from OpenAI")
            
        # Extract JSON from response
        content = content.strip()
        if content.startswith("```json"):
            content = content[7:]
        if content.endswith("```"):
            content = content[:-3]
        content = content.strip()
        
        intent_data = json.loads(content)
        
        # Validate and normalize
        return _normalize_intent(intent_data)
        
    except Exception as e:
        logger.exception(f"Intent parsing failed: {e}")
        # Return safe fallback
        return {
            "intent": "query",
            "items": [],
            "query": message
        }


def _normalize_intent(intent: dict) -> dict:
    """Normalize and validate parsed intent."""
    # Ensure required fields
    if "intent" not in intent:
        intent["intent"] = "query"
    if "items" not in intent:
        intent["items"] = []
    if "query" not in intent:
        intent["query"] = None
    
    # Normalize items
    for item in intent.get("items", []):
        # Normalize name
        name = item.get("name", "").strip().lower()
        if name:
            # Basic singularization (simple rules)
            if name.endswith('s') and len(name) > 3:
                name = name[:-1]  # Remove trailing 's'
        item["name"] = name
        
        # Default quantity
        if not item.get("quantity"):
            item["quantity"] = 1
            
        # Normalize location
        location = item.get("location")
        if location:
            location = location.strip().lower()
            # Convert "third drawer" → "drawer 3"
            if "drawer" in location:
                parts = location.split()
                for i, part in enumerate(parts):
                    if part == "third":
                        parts[i] = "3"
                    elif part == "second":
                        parts[i] = "2"
                    elif part == "first":
                        parts[i] = "1"
                location = " ".join(parts)
        item["location"] = location
    
    return intent


async def generate_response(intent_data: dict, tool_result: dict, context: dict) -> str:
    """Generate natural response based on intent and tool execution results."""
    client = _get_openai_client()
    model = get_settings().openai_model
    
    system_prompt = (
        "You are a helpful inventory assistant.\n\n"
        "Generate a natural, human-like response.\n\n"
        "Rules:\n"
        "* Be concise\n"
        "* Be accurate\n"
        "* Reflect actual actions performed\n"
        "* DO NOT hallucinate\n"
        "* DO NOT mention JSON or tools"
    )
    
    # Build context message
    context_msg = f"User intent: {json.dumps(intent_data, indent=2)}\n\n"
    context_msg += f"Tool results: {json.dumps(tool_result, indent=2)}"
    
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": context_msg}
            ],
            temperature=0.3,
            max_tokens=200
        )
        
        content = resp.choices[0].message.content
        return content.strip() if content else "Done."
        
    except Exception as e:
        logger.exception(f"Response generation failed: {e}")
        # Return safe fallback
        intent = intent_data.get("intent", "query")
        if intent == "add":
            return "Items have been added to your inventory."
        elif intent == "remove":
            return "Items have been removed from your inventory."
        elif intent == "update":
            return "Items have been updated."
        elif intent == "query":
            return "Here are your search results."
        else:
            return "Request processed."


def _execute_intent(intent_data: dict, user_id: str, first_name: str) -> dict:
    """Execute the parsed intent by calling appropriate tools."""
    
    client = _get_openai_client()
    
    # Confidence safety check
    if isinstance(intent_data, dict) and intent_data.get("confidence") is not None:
        if intent_data.get("confidence") < 0.5:
            return {
                "success": False,
                "error": "low_confidence",
                "items": []
            }
    
    intent = intent_data.get("intent", "query")
    items = intent_data.get("items", [])
    
    # Add multi-action support
    if isinstance(intent_data.get("items"), list) and len(intent_data["items"]) > 1:
        results = []
        for item in intent_data["items"]:
            single_intent = {
                **intent_data,
                "items": [item]
            }
            res = _execute_intent(single_intent, user_id, first_name)
            results.append(res)
        return {"success": True, "multi": True, "results": results}
    
    try:
        if intent == "add":
            # Handle add with merging logic
            results = []
            for item in items:
                name = item.get("name", "")
                quantity = item.get("quantity", 1)
                location = item.get("location")
                attributes = item.get("attributes")
                
                # Check if item exists and merge
                existing = search_items_basic(user_id=user_id, query=name)
                if existing:
                    # Increment quantity of first matching item
                    existing_item = existing[0]
                    new_quantity = existing_item.get("quantity", 0) + quantity
                    updated = update_item(
                        user_id=user_id,
                        item_id=existing_item["id"],
                        updates={"quantity": new_quantity}
                    )
                    results.append(updated)
                else:
                    # Create new item
                    new_item = add_item(
                        user_id=user_id,
                        name=name,
                        quantity=quantity,
                        location=location or "",
                        notes=attributes or ""
                    )
                    results.append(new_item)
            
            # Add smart follow-up storage
            if items:
                last = items[0]
                st = _get_state(user_id)
                st.last_item_name = last.get("name")
                st.pending_action = intent
            
            return {"success": True, "items": results, "action": "added"}
            
        elif intent == "remove":
            # Handle remove
            results = []
            for item in items:
                name = item.get("name", "")
                quantity = item.get("quantity", 1)
                
                # Find and remove/update items
                existing = search_items_basic(user_id=user_id, query=name)
                for existing_item in existing[:quantity]:
                    deleted = delete_item(user_id=user_id, item_id=existing_item["id"])
                    if deleted:
                        results.append(existing_item)
            
            # Add smart follow-up storage
            if items:
                last = items[0]
                st = _get_state(user_id)
                st.last_item_name = last.get("name")
                st.pending_action = intent
            
            return {"success": True, "items": results, "action": "removed"}
            
        elif intent == "update":
            # Handle update
            results = []
            for item in items:
                name = item.get("name", "")
                updates = {}
                
                if item.get("location"):
                    updates["location"] = item["location"]
                if item.get("quantity"):
                    updates["quantity"] = item["quantity"]
                if item.get("attributes"):
                    updates["notes"] = item["attributes"]
                
                # Find and update items
                existing = search_items_basic(user_id=user_id, query=name)
                for existing_item in existing:
                    updated = update_item(
                        user_id=user_id,
                        item_id=existing_item["id"],
                        updates=updates
                    )
                    results.append(updated)
            
            # Add smart follow-up storage
            if items:
                last = items[0]
                st = _get_state(user_id)
                st.last_item_name = last.get("name")
                st.pending_action = intent
            
            return {"success": True, "items": results, "action": "updated"}
            
        elif intent == "query":
            # Handle search
            query = intent_data.get("query", "")
            if items:
                # Search for specific items
                results = []
                for item in items:
                    name = item.get("name", "")
                    found = search_items_basic(user_id=user_id, query=name)
                    results.extend(found)
                return {"success": True, "items": results, "action": "queried"}
            elif query:
                # General search
                results = search_items_basic(user_id=user_id, query=query)
                return {"success": True, "items": results, "action": "queried"}
            else:
                return {"success": True, "items": [], "action": "queried"}
                
        elif intent == "plan":
            all_items = search_items_basic(user_id=user_id, query="")
            
            planning_prompt = (
                "You are a robotics and inventory expert.\n\n"
                "User wants to build something.\n\n"
                "You MUST:\n"
                "1. List items they already have\n"
                "2. List missing items\n"
                "3. Give step-by-step build plan\n"
                "4. Be practical and realistic\n"
            )
            
            resp = client.chat.completions.create(
                model=get_settings().openai_model,
                messages=[
                    {"role": "system", "content": planning_prompt},
                    {"role": "system", "content": f"Inventory:\n{json.dumps(all_items)}"},
                    {"role": "user", "content": intent_data.get("query", "")}
                ],
                temperature=0.4,
                max_tokens=400
            )
            
            return {
                "success": True,
                "plan": resp.choices[0].message.content
            }
            
        else:
            return {"success": False, "error": "Unknown intent", "items": []}
            
    except Exception as e:
        logger.exception(f"Intent execution failed: {e}")
        return {"success": False, "error": str(e), "items": []}


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


async def iter_ai_command_sse(*, user_id: str, message: str, first_name: str | None = None) -> Iterator[str]:
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

    async def _emit_terminal_done() -> Iterator[str]:
        # Always end the stream with event: done + data: {}
        for item in _evt_event("done", "{}"):
            yield item

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
        client = _get_openai_client()

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

        # Add short-term memory handling
        previous_state = _get_state(user_id)
        context["memory"] = {
            "last_item_name": previous_state.last_item_name,
            "last_item_id": previous_state.last_item_id,
            "pending_action": previous_state.pending_action,
            "pending_quantity": previous_state.pending_quantity,
        }

        # Reasoning layer - think before parsing
        reasoning = await reason_about_request(message, context)
        
        # Clarification logic
        if reasoning.get("needs_clarification") or reasoning.get("confidence", 1) < 0.6:
            clarification_prompt = (
                "Ask a short, natural clarification question to the user.\n"
                "Be concise and conversational."
            )
            
            resp = client.chat.completions.create(
                model=settings.openai_model,
                messages=[
                    {"role": "system", "content": clarification_prompt},
                    {"role": "user", "content": message}
                ],
                temperature=0.3,
                max_tokens=100
            )
            
            clarification = resp.choices[0].message.content.strip()
            
            yield _evt({"type": "delta", "delta": clarification})
            yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": clarification})
            return

        intent, intent_err = _ai_parse_intent(
            client=client,
            model=settings.openai_model,
            message=message,
            context=context,
        )

        if isinstance(intent, dict):
            intent["confidence"] = reasoning.get("confidence", 1.0)

        # Override intent for planning / question-based queries
        msg_lower = message.lower()
        
        if any(q in msg_lower for q in [
            "what do i need",
            "what should i use", 
            "how do i build",
            "how to build",
            "help me build",
            "i want to build",
            "what do i need to build"
        ]):
            intent["action"] = "plan"
            intent["domain"] = "general"
            intent["items"] = []
            intent["query"] = message

        # Prevent "I have X items" from triggering add
        if msg_lower.startswith("i have"):
            if "what" in msg_lower or "need" in msg_lower:
                intent["action"] = "plan"

        # Resolve memory references (them, it, those)
        if isinstance(intent, dict):
            items = intent.get("items", [])
            if items:
                for item in items:
                    if item.get("name") in ["them", "it", "those"]:
                        prev = context.get("memory", {}).get("last_item_name")
                        if prev:
                            item["name"] = prev

        if intent is None:
            # Instead of blocking, create a fallback intent for general conversation
            intent = {
                "domain": "general",
                "action": "query", 
                "items": [],
                "query": message,
                "updates": None,
                "document": None,
            }

        tool_name: str | None = None
        tool_result: dict | list | None = None
        hard_failure = False

        domain = intent.get("domain")
        action = intent.get("action")

        tool_name = intent.get("action")
        tool_result = _execute_intent(intent, user_id, first_name)
        hard_failure = not tool_result.get("success", False)

        # Generate natural response using AI
        assistant_message = await generate_response(intent, tool_result, context)
        
        yield _evt({"type": "delta", "delta": assistant_message})
        yield _evt({
            "type": "done",
            "tool": tool_name,
            "result": tool_result,
            "assistant_message": assistant_message
        })

        done_sent = True
        async for item in _emit_terminal_done():
            yield item
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
            async for item in _emit_terminal_done():
                yield item
        else:
            async for item in _emit_terminal_done():
                yield item
