import logging
from datetime import datetime, timezone

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


def lookup_in_catalog(barcode: str) -> dict | None:
    """Check parts_catalog table for a known barcode. Returns dict or None."""
    try:
        supabase = get_supabase_admin()
        result = supabase.table("parts_catalog").select("*").eq("barcode", barcode).execute()
        rows = result.data if result else []
        if not rows:
            alias_result = (
                supabase.table("part_catalog_barcodes")
                .select("catalog_id")
                .eq("barcode", barcode)
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

    The caller must resolve ``catalog_id`` server-side from an exact verified
    manufacturer + part number before calling this function.
    """
    wanted_barcode = barcode.strip()
    if not wanted_barcode or not catalog_id:
        return False

    client = get_supabase_admin()
    canonical_owner = (
        client.table("parts_catalog")
        .select("catalog_id")
        .eq("barcode", wanted_barcode)
        .limit(1)
        .execute()
    )
    canonical_rows = canonical_owner.data or []
    if canonical_rows and str(canonical_rows[0].get("catalog_id")) != catalog_id:
        logger.warning("Refusing to reassign canonical barcode %s", wanted_barcode)
        return False

    alias_owner = (
        client.table("part_catalog_barcodes")
        .select("catalog_id")
        .eq("barcode", wanted_barcode)
        .limit(1)
        .execute()
    )
    alias_rows = alias_owner.data or []
    if alias_rows:
        if str(alias_rows[0].get("catalog_id")) != catalog_id:
            logger.warning("Refusing to reassign barcode alias %s", wanted_barcode)
            return False
        return True

    client.table("part_catalog_barcodes").insert({
        "barcode": wanted_barcode,
        "catalog_id": catalog_id,
        "source": "user_confirmed_label",
    }).execute()
    return True


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


def save_to_catalog(barcode: str, data: dict, source: str = "user") -> None:
    """Upsert a confirmed part into parts_catalog. Never raises — silent fail."""
    try:
        if not barcode or not data.get("name"):
            return
        supabase = get_supabase_admin()
        existing_result = supabase.table("parts_catalog").select("catalog_id, confirmation_count").eq("barcode", barcode).execute()
        existing_rows = existing_result.data if existing_result else []
        if existing_rows:
            existing = existing_rows[0]
            count = (existing.get("confirmation_count") or 1) + 1
            supabase.table("parts_catalog").update({
                "canonical_name": data.get("name"),
                "brand": data.get("brand"),
                "category": data.get("category"),
                "subcategory": data.get("subcategory"),
                "part_number": data.get("part_number"),
                "source": source,
                "confirmation_count": count,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }).eq("barcode", barcode).execute()
        else:
            supabase.table("parts_catalog").insert({
                "barcode": barcode,
                "canonical_name": data.get("name"),
                "brand": data.get("brand"),
                "category": data.get("category"),
                "subcategory": data.get("subcategory"),
                "part_number": data.get("part_number"),
                "source": source,
                "confirmation_count": 1
            }).execute()
    except Exception:
        logger.error("Catalog save error", exc_info=True)
