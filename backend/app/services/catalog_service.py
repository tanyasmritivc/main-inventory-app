import logging
from datetime import datetime, timezone

from app.services.supabase_client import get_supabase_admin

logger = logging.getLogger(__name__)


def lookup_in_catalog(barcode: str) -> dict | None:
    """Check parts_catalog table for a known barcode. Returns dict or None."""
    try:
        supabase = get_supabase_admin()
        result = supabase.table("parts_catalog").select("*").eq("barcode", barcode).execute()
        rows = result.data if result else []
        if rows:
            row = rows[0]
            return {
                "name": row.get("canonical_name"),
                "brand": row.get("brand"),
                "category": row.get("category"),
                "subcategory": row.get("subcategory"),
                "part_number": row.get("part_number"),
                "description": row.get("description"),
                "source": "findez_catalog",
                "confidence": "high"
            }
        return None
    except Exception:
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
