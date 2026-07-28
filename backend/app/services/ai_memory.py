"""Three-layer AI memory system for FindEZ.

Layer 1 — User Memory: persistent key-value facts extracted from conversations.
Layer 2 — Query Analytics: classify and log every query.
Layer 3 — Conversation History RAG: store Q&A pairs and retrieve similar ones.

All functions are async; blocking Supabase/OpenAI calls run via asyncio.to_thread
so they never block the event loop.
"""
from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


# ── Layer 1: User Memory ─────────────────────────────────────────────────────

async def fetch_user_memory(user_id: str) -> str:
    """Return a formatted string of known user facts, or '' if none exist yet."""
    def _sync() -> str:
        from app.services.supabase_client import get_supabase_admin
        sb = get_supabase_admin()
        resp = (
            sb.table("user_memory")
            .select("key, value")
            .eq("user_id", user_id)
            .execute()
        )
        rows = resp.data or []
        if not rows:
            return ""
        parts = [
            f"{r['key']}: {r['value']}"
            for r in rows
            if r.get("key") and r.get("value")
        ]
        return ("What I know about this user: " + ", ".join(parts)) if parts else ""

    try:
        return await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("fetch_user_memory failed")
        return ""


async def extract_and_save_memory(user_id: str, question: str, answer: str) -> None:
    """Background: ask gpt-4o-mini to extract key facts and upsert into user_memory."""
    def _sync() -> None:
        from app.core.config import get_settings
        from app.services.supabase_client import get_supabase_admin
        from openai import OpenAI

        client = OpenAI(api_key=get_settings().openai_api_key)
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You extract key facts about a user from their inventory conversations. "
                        "Output ONLY a JSON object with short key-value pairs. "
                        "Keys should be snake_case facts like: team_type, main_space_name, "
                        "frequently_tracked_items, preferred_query_style, organization_name. "
                        "Max 6 keys. Only include facts that are clearly stated. Output {} if nothing."
                    ),
                },
                {
                    "role": "user",
                    "content": f"Question: {question[:1000]}\nAnswer: {answer[:2000]}",
                },
            ],
            temperature=0,
            max_completion_tokens=200,
        )
        raw = (resp.choices[0].message.content or "{}").strip()
        # Strip markdown code fences if the model wraps the JSON
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
        try:
            facts: dict = json.loads(raw)
        except Exception:
            return
        if not isinstance(facts, dict) or not facts:
            return

        sb = get_supabase_admin()
        now = datetime.now(timezone.utc).isoformat()
        for key, value in facts.items():
            if not isinstance(key, str) or not isinstance(value, (str, int, float, bool)):
                continue
            try:
                sb.table("user_memory").upsert(
                    {
                        "user_id": user_id,
                        "key": str(key)[:100],
                        "value": str(value)[:500],
                        "updated_at": now,
                    },
                    on_conflict="user_id,key",
                ).execute()
            except Exception:
                logger.exception("Failed to upsert user_memory key=%s", key)

    try:
        await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("extract_and_save_memory failed")


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
        from app.services.supabase_client import get_supabase_admin
        sb = get_supabase_admin()
        row: dict = {
            "user_id": user_id,
            "query_text": query_text[:1000],
            "query_type": _classify_query(query_text),
        }
        if space_id:
            row["space_id"] = space_id
        sb.table("query_logs").insert(row).execute()

    try:
        await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("log_query failed")


# ── Layer 3: Conversation History RAG ────────────────────────────────────────

async def fetch_similar_history(
    user_id: str, current_question: str, limit: int = 3
) -> str:
    """Return formatted past Q&A pairs similar to current_question, or ''."""
    def _sync() -> str:
        from app.services.supabase_client import get_supabase_admin
        sb = get_supabase_admin()
        try:
            resp = (
                sb.table("conversation_history")
                .select("question, answer")
                .eq("user_id", user_id)
                .text_search("question", current_question, config="english")
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
        except Exception:
            # Full-text search unavailable — fall back to most recent entries
            resp = (
                sb.table("conversation_history")
                .select("question, answer")
                .eq("user_id", user_id)
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
        rows = resp.data or []
        if not rows:
            return ""
        lines = [
            f"Q: {r['question']}\nA: {r['answer']}"
            for r in rows
            if r.get("question") and r.get("answer")
        ]
        return ("Relevant past conversations:\n" + "\n".join(lines)) if lines else ""

    try:
        return await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("fetch_similar_history failed")
        return ""


async def save_conversation(
    user_id: str, question: str, answer: str, space_id: str | None = None
) -> None:
    """Background: store this Q&A pair in conversation_history."""
    def _sync() -> None:
        from app.services.supabase_client import get_supabase_admin
        sb = get_supabase_admin()
        row: dict = {
            "user_id": user_id,
            "question": question[:2000],
            "answer": answer[:4000],
        }
        if space_id:
            row["space_id"] = space_id
        sb.table("conversation_history").insert(row).execute()

    try:
        await asyncio.to_thread(_sync)
    except Exception:
        logger.exception("save_conversation failed")
