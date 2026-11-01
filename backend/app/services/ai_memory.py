"""Legacy chat analytics helpers and compatibility entry points.

Durable personalization now uses account_memory and memory_context. Automatic
fact extraction and historical-answer RAG are deliberately disabled; existing
query signals omit content; historical-answer duplication is disabled. Existing
owned conversations remain the chat history source.
"""

import asyncio
import logging

logger = logging.getLogger(__name__)


# ── Layer 1: User Memory ─────────────────────────────────────────────────────

async def fetch_user_memory(user_id: str) -> str:
    """Compatibility entry point; typed context is loaded by both agent paths."""
    return ""


async def extract_and_save_memory(user_id: str, question: str, answer: str) -> None:
    """Legacy automatic extraction is disabled. Explicit memory API owns writes.

    Neither assistant text nor uploaded content is evidence of a confirmed user
    preference. Keep this callable for older route/test contracts, without a model
    call, write, or deferred candidate that could resurrect forgotten memory.
    """
    return None


# ── Layer 2: Query Analytics ─────────────────────────────────────────────────

def _classify_query(query: str) -> str:
    text = query.lower()
    if any(w in text for w in ("where", "location", "find")):
        return "location_lookup"
    if any(w in text for w in ("how many", "quantity", "count", "stock")):
        return "quantity_check"
    if any(w in text for w in ("low", "restock", "running out", "need")):
        return "restock_alert"
    if any(w in text for w in ("add", "new", "create")):
        return "add_item"
    return "general"


async def log_query(user_id: str, query_text: str, space_id: str | None = None) -> None:
    """Background: classify the query and insert a row into query_logs."""
    def _sync() -> None:
        import httpx
        from app.services.supabase_client import create_supabase_admin
        sb = create_supabase_admin()
        row: dict = {
            "user_id": user_id,
            "query_text": "[content omitted]",
            "query_type": _classify_query(query_text),
        }
        if space_id:
            row["space_id"] = space_id
        try:
            sb.table("query_logs").insert(row).execute()
        except httpx.ReadError:
            logger.warning("Query signal outcome unknown; not retrying the insert")

    try:
        await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("log_query failed")


# ── Layer 3: Conversation History RAG ────────────────────────────────────────

async def fetch_similar_history(user_id: str, current_question: str, limit: int = 3) -> str:
    """Historical answer text is not durable preference or current item evidence."""
    return ""


async def save_conversation(user_id: str, question: str, answer: str, space_id: str | None = None) -> None:
    """Compatibility no-op: owned messages already persist the conversation.

    Do not create another permanent raw Q&A copy for disabled history RAG.
    Historical rows are retained until an approved retention/deletion operation.
    """
    return None
