import logging

from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)

_BRAND_ALIASES = {
    "rev": "rev robotics",
    "revrobotics": "rev robotics",
    "ion": "rev robotics",
    "wcp": "westcoast products",
    "ctre": "cross the road electronics",
}


def _normalized_brand(value: str | None) -> str:
    normalized = " ".join((value or "").lower().replace("®", "").split())
    compact = normalized.replace(" ", "")
    return _BRAND_ALIASES.get(normalized, _BRAND_ALIASES.get(compact, normalized))


def barcode_candidates(value: str) -> list[str]:
    """Equivalent scan representations, preserving the raw value first.

    UPC-A scanners commonly emit the same symbol as EAN-13 with a leading zero.
    GTIN-14 readers can add two leading zeros. Only zero-padding is normalized;
    meaningful digits and alphanumeric manufacturer SKUs are never rewritten.
    """
    raw = value.strip()
    candidates = [raw] if raw else []
    upc = None
    if raw.isascii() and raw.isdigit():
        if len(raw) == 12:
            upc = raw
        elif len(raw) == 13 and raw.startswith("0"):
            upc = raw[1:]
        elif len(raw) == 14 and raw.startswith("00"):
            upc = raw[2:]
    if upc:
        for equivalent in (upc, f"0{upc}", f"00{upc}"):
            if equivalent not in candidates:
                candidates.append(equivalent)
    return candidates


def lookup_in_catalog(barcode: str) -> dict | None:
    """Check parts_catalog table for a known barcode. Returns dict or None."""
    try:
        supabase = get_supabase_admin()
        candidates = barcode_candidates(barcode)
        result = supabase.table("parts_catalog").select("*").in_("barcode", candidates).execute()
        rows = result.data if result else []
        if not rows:
            alias_result = (
                supabase.table("part_catalog_barcodes")
                .select("catalog_id")
                .in_("barcode", candidates)
                .limit(1)
                .execute()
            )
            aliases = alias_result.data if alias_result else []
            if aliases:
                product_result = (
                    supabase.table("parts_catalog")
                    .select("*")
                    .eq("catalog_id", aliases[0]["catalog_id"])
                    .limit(1)
                    .execute()
                )
                rows = product_result.data if product_result else []
        if rows:
            row = rows[0]
            return {
                "name": row.get("canonical_name"),
                "brand": row.get("brand"),
                "category": row.get("category"),
                "subcategory": row.get("subcategory"),
                "part_number": row.get("part_number"),
                "description": row.get("description"),
                "image_url": row.get("image_url"),
                "source": "findez_catalog",
                "confidence": "high"
            }
        return None
    except Exception:
        return None


def lookup_verified_part(*, brand: str | None, part_number: str | None) -> dict | None:
    """Return manufacturer-verified data only for an exact brand + part-number match."""
    if not brand or not part_number:
        return None
    wanted_brand = _normalized_brand(brand)
    wanted_part = part_number.strip().lower()
    if not wanted_brand or not wanted_part:
        return None

    try:
        result = (
            get_supabase_admin()
            .table("parts_catalog")
            .select(
                "catalog_id,canonical_name,brand,category,subcategory,part_number,"
                "description,product_url,source_url,specifications,compatibility,"
                "verification_status"
            )
            .eq("verification_status", "verified")
            .ilike("part_number", part_number.strip())
            .execute()
        )
        for row in result.data or []:
            if _normalized_brand(row.get("brand")) != wanted_brand:
                continue
            if str(row.get("part_number") or "").strip().lower() != wanted_part:
                continue
            return row
    except Exception:
        logger.exception("Verified catalog lookup failed")
    return None


def verified_catalog_id_for_identity(*, brand: str | None, part_number: str | None) -> str | None:
    match = lookup_verified_part(brand=brand, part_number=part_number)
    catalog_id = match.get("catalog_id") if match else None
    return str(catalog_id) if catalog_id else None


def link_verified_barcode_alias(*, barcode: str, catalog_id: str) -> bool:
    """Attach a confirmed scan code without ever stealing another part's barcode.

    The caller resolves the identity server-side; the service-only transaction
    rechecks verification and serializes assignment with community writes.
    """
    wanted_barcode = barcode.strip()
    if not wanted_barcode or not catalog_id:
        return False

    return get_supabase_admin().rpc("findez_link_verified_barcode_alias", {
        "p_barcode": wanted_barcode, "p_catalog_id": catalog_id,
    }).execute().data is True


def enrich_scan_items_from_verified_catalog(items: list[dict]) -> list[dict]:
    """Overlay authoritative identity fields; never treat community rows as verified."""
    enriched: list[dict] = []
    for original in items:
        item = dict(original)
        match = lookup_verified_part(
            brand=item.get("brand"),
            part_number=item.get("part_number"),
        )
        if match:
            item.update({
                "name": match.get("canonical_name") or item.get("name"),
                "brand": match.get("brand") or item.get("brand"),
                "category": match.get("category") or item.get("category"),
                "subcategory": match.get("subcategory") or item.get("subcategory"),
                "part_number": match.get("part_number") or item.get("part_number"),
                "catalog_match": {
                    "catalog_id": str(match.get("catalog_id")),
                    "verified": True,
                    "source": "manufacturer",
                    "product_url": match.get("product_url"),
                    "source_url": match.get("source_url"),
                    "specifications": match.get("specifications") or {},
                    "compatibility": match.get("compatibility") or {},
                },
            })
        enriched.append(item)
    return enriched


def get_verified_catalog_part(catalog_id: str) -> dict | None:
    try:
        result = (
            get_supabase_admin()
            .table("parts_catalog")
            .select(
                "catalog_id,canonical_name,brand,category,subcategory,part_number,"
                "description,product_url,source_url,specifications,compatibility,"
                "verification_status"
            )
            .eq("catalog_id", catalog_id)
            .eq("verification_status", "verified")
            .maybe_single()
            .execute()
        )
        return result.data if result and result.data else None
    except Exception:
        logger.exception("Verified catalog detail lookup failed")
        return None


def get_compatible_catalog_parts(catalog_id: str, *, limit: int = 12) -> dict:
    """Return verified products sharing an exact manufacturer-published interface."""
    client = get_supabase_admin()
    target = (
        client.table("parts_catalog")
        .select("compatibility_keys")
        .eq("catalog_id", catalog_id)
        .eq("verification_status", "verified")
        .limit(1)
        .execute()
    )
    target_rows = target.data or []
    keys = list(target_rows[0].get("compatibility_keys") or []) if target_rows else []
    if not keys:
        return {"interfaces": [], "matches": []}
    result = (
        client.table("parts_catalog")
        .select("catalog_id,canonical_name,brand,part_number,product_url,compatibility_keys")
        .eq("verification_status", "verified")
        .overlaps("compatibility_keys", keys)
        .limit(limit + 1)
        .execute()
    )
    matches = []
    for row in result.data or []:
        if str(row.get("catalog_id")) == catalog_id:
            continue
        shared = [key.split(":", 1)[-1] for key in keys if key in (row.get("compatibility_keys") or [])]
        if shared:
            matches.append({**row, "shared_interfaces": shared})
        if len(matches) >= limit:
            break
    return {"interfaces": [key.split(":", 1)[-1] for key in keys], "matches": matches}


def save_to_catalog(barcode: str, data: dict, source: str = "user") -> bool:
    """Best-effort community lookup cache, never an authoritative item save.

    Only the service-only transaction can write; verified identities and existing
    aliases are protected there even when a caller supplies untrusted fields.
    """
    try:
        if not barcode or not data.get("name"):
            return False
        fields = {field: data.get(field) for field in (
            "name", "brand", "category", "subcategory", "part_number",
        )}
        return get_supabase_admin().rpc("findez_save_community_catalog", {
            "p_barcode": barcode, "p_data": fields, "p_source": source,
        }).execute().data is True
    except Exception:
        logger.warning("Community catalog update unavailable; inventory data unchanged")
        return False
