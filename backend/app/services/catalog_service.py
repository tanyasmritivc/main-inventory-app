from datetime import datetime, timezone

from app.services.supabase_client import get_supabase_client


def lookup_in_catalog(barcode: str) -> dict | None:
    """Check parts_catalog table for a known barcode. Returns dict or None."""
    try:
        supabase = get_supabase_client()
        result = supabase.table("parts_catalog").select("*").eq("barcode", barcode).single().execute()
        if result.data:
            return {
                "name": result.data.get("canonical_name"),
                "brand": result.data.get("brand"),
                "category": result.data.get("category"),
                "subcategory": result.data.get("subcategory"),
                "part_number": result.data.get("part_number"),
                "description": result.data.get("description"),
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
        supabase = get_supabase_client()
        existing = supabase.table("parts_catalog").select("catalog_id, confirmation_count").eq("barcode", barcode).single().execute()
        if existing.data:
            count = (existing.data.get("confirmation_count") or 1) + 1
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
        pass
