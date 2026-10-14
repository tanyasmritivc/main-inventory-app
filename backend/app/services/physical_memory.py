"""Authorized, deterministic physical-memory retrieval. No model or write tools."""
import re
from datetime import datetime, timezone

from fastapi import HTTPException
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_admin

ERRORS = {
    "permission": (403, "You do not have permission to use this Team's physical memory."),
    "catalog_unavailable": (409, "This catalog entry is unavailable. Refresh before confirming."),
    "missing": (404, "This physical memory is unavailable."),
    "destination": (409, "This Space or bin is no longer available to this Team."),
    "revision_conflict": (409, "Someone changed this location. Refresh it before saving again."),
    "destination_conflict": (409, "This location is already recorded. Refresh and update its confirmation."),
    "label_conflict": (409, "Use the saved FindEZ name for this memory."),
    "barcode_conflict": (409, "The entered barcode no longer matches this variant. Refresh the catalog."),
    "idempotency_conflict": (409, "This save identifier belongs to a different change."),
}


def enabled():
    return get_settings().physical_memory_enabled


def available(team_id):
    if not enabled():
        return False
    db = get_supabase_admin()
    return bool(db.table("physical_memories").select("memory_id").eq("team_id", team_id).limit(1).execute().data or
        db.table("shopify_connections").select("connection_id").eq("team_id", team_id).in_("status", ["connected", "reconnect_required"]).limit(1).execute().data)


def call(operation, **params):
    try:
        result = get_supabase_admin().rpc("physical_" + operation, {"p_" + k: v for k, v in params.items()}).execute().data
    except Exception:
        raise HTTPException(503, "Physical memory could not be loaded or saved. Try again.") from None
    if not isinstance(result, dict):
        raise HTTPException(503, "Physical memory could not be loaded. Try again.")
    if result.get("error"):
        status, message = ERRORS.get(result["error"], (503, "Physical memory could not be saved. Try again."))
        raise HTTPException(status, message)
    return result


STOP_WORDS = frozenset("where is are the a an my our can i we find locate please show me in items products stored keep do have which what was last seen on size storage sku barcode product item this that".split())


def plan(question):
    """Bounded name/SKU/barcode/location grammar. Unsupported intent stays honest."""
    question = question.strip().rstrip("?.!")
    if re.search(r"\b(delete|remove|move|adjust|change|update|fulfill|fulfil|set|add)\b", question, re.I):
        return None
    barcode = None
    match = re.fullmatch(r"(?:barcode\s*[: ]\s*)?(\d{6,255})", question, re.I)
    if match:
        barcode = match[1]
    bin_name, space = None, None
    match = re.search(r'\bin\s+(?:storage\s+)?(bin|space)\s+["\']?(.+?)["\']?$', question, re.I)
    if match:
        value = match[2].strip('"\' ')
        bin_name, space = (value, None) if match[1].lower() == "bin" else (None, value)
        question = question[:match.start()]
    words = re.findall(r"[\w-]+", question.lower())
    tokens = [word for word in words if word not in STOP_WORDS]
    if len(tokens) > 30:
        return None
    if not tokens and not barcode and not bin_name and not space:
        return None
    return {"tokens": [] if barcode else tokens[:30], "barcode": barcode, "bin": bin_name, "space": space}


def lookup(team, actor, *, question, barcode=None, memory_id=None, connection_id=None, variant_gid=None):
    filters = plan(question) if not barcode else {"tokens": [], "barcode": barcode, "bin": None, "space": None}
    if memory_id or variant_gid:
        filters = filters or {"tokens": [], "barcode": None, "bin": None, "space": None}
    if filters is None:
        return {"candidates": [], "truncated": False, "unsupported": True}
    result = call("lookup", team=team, actor=actor, **filters, memory=memory_id, connection=connection_id, variant=variant_gid)
    # SQL overfetches one candidate to signal ambiguity, never silently chooses.
    result["candidates"] = result["candidates"][:20]
    return result


def _label(value):
    # Upstream catalog text is data, never executable Markdown or instructions.
    value = " ".join(str(value or "").split())[:200]
    return re.sub(r"([\\`*_{}\[\]<>()#!|])", r"\\\1", value)


def _facts(candidate):
    sources = []
    label = candidate.get("native_label") or f"{candidate.get('product_title', '')} / {candidate.get('variant_title', '')}"
    lines = [_label(label)]
    if candidate.get("catalog_deleted"):
        lines.append("Its Shopify catalog entry was removed. These independently confirmed FindEZ locations may need review.")
    if not candidate["placements"]:
        lines.append("No currently accessible physical location is confirmed. Catalog stock does not prove where the item is stored.")
    for placement in candidate["placements"]:
        location = placement["space_name"] + (" / " + placement["bin_name"] if placement.get("bin_name") else "")
        when = placement["confirmed_at"]
        count = placement.get("observed_count")
        count_text = "No physical count was recorded." if count is None else f"Observed count here: {count}."
        actor_label = placement["actor_label"]
        lines.append(f"- {_label(location)}. Confirmed by {_label(actor_label)} at {when}. {count_text}")
        try:
            days = (datetime.now(timezone.utc) - datetime.fromisoformat(when.replace("Z", "+00:00"))).days
            if days >= 7:
                lines.append(f"  This confirmation is {days} days old. Reconfirm to check the current location.")
        except (ValueError, TypeError):
            lines.append("  The confirmation time is unavailable; reconfirm this location.")
        sources.append({"kind": "spaces", "label": location[:200], "detail": f"Employee confirmation by {actor_label}; {when}. {count_text}"[:400]})
    if candidate.get("connection_id"):
        for stock in candidate["shopify_inventory"]:
            q = stock["quantities"]
            detail = f"{q.get('available', 'Unknown')} available / {q.get('on_hand', 'Unknown')} on hand. Synced {stock['synced_at']}."
            lines.append(f"Shopify reports {_label(stock['location_name'])}: {detail} This is a commerce snapshot, not a physical count.")
            sources.append({"kind": "inventory", "label": "Shopify: " + stock["location_name"][:180], "detail": detail})
        if candidate.get("tracked") is False:
            lines.append("Shopify does not track stock for this record.")
        elif not candidate["shopify_inventory"]:
            lines.append("No Shopify quantity snapshot is available.")
    return lines, sources


def answer(team, actor, payload):
    parsed = plan(payload["question"])
    writes = re.search(r"\b(delete|remove|move|adjust|change|update|fulfill|fulfil|set|add)\b", payload["question"], re.I)
    if writes or (parsed is None and not (payload.get("memory_id") or payload.get("variant_gid"))):
        result = {"candidates": [], "truncated": False, "unsupported": True}
    else:
        result = lookup(team, actor, **payload)
    sources, lines = [], []
    candidates = result["candidates"]
    is_list = bool(parsed and (parsed.get("bin") or parsed.get("space")) and
        re.match(r"\s*(show|list|what)\b", payload["question"], re.I))
    if result.get("unsupported"):
        kind = "unsupported"
        lines = ["Ask where a product is, or what is stored in a Space or bin. Save location changes with the confirmation form."]
    elif not candidates:
        kind = "unknown"
        lines = ["I couldn't find a matching record in this Team. Try its FindEZ name, SKU, or barcode."]
    elif len(candidates) > 1 and not is_list:
        kind = "clarification"
        lines = ["More than one record matches. Choose the product or variant you mean" + (", or narrow your search" if result["truncated"] else "") + "."]
    else:
        kind = "list" if is_list else "locations"
        if is_list:
            lines = ["These records have confirmed, accessible placements in that location."]
        for candidate in candidates:
            facts, evidence = _facts(candidate)
            lines.extend(facts)
            sources.extend(evidence)
        if result["truncated"]:
            lines.append("Showing the first 20 matching records. Narrow your search to see other matches.")
    return {"kind": kind, "assistant_message": "\n\n".join(lines), "result": result,
        "answer_context": {"sources": sources[:20], "rows": [], "rows_truncated": False, "checked_at": datetime.now(timezone.utc).isoformat()}}
