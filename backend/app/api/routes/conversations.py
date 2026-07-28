
import logging

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth import AuthenticatedUser, get_current_user
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["conversations"])
logger = logging.getLogger(__name__)


@router.get("/conversations")
def list_conversations(user: AuthenticatedUser = Depends(get_current_user)):
    client = get_supabase_admin()
    res = (
        client.table("conversations")
        .select("id,title,updated_at,created_at")
        .eq("user_id", user.user_id)
        .order("updated_at", desc=True)
        .limit(50)
        .execute()
    )
    return res.data or []


@router.post("/conversations")
def create_conversation(user: AuthenticatedUser = Depends(get_current_user)):
    client = get_supabase_admin()
    res = (
        client.table("conversations")
        .insert({"user_id": user.user_id, "title": "New Chat"})
        .execute()
    )
    return (res.data or [{}])[0]


@router.get("/conversations/{conversation_id}")
def get_conversation(
    conversation_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    conv_res = (
        client.table("conversations")
        .select("id,title,created_at,updated_at")
        .eq("id", conversation_id)
        .eq("user_id", user.user_id)
        .limit(1)
        .execute()
    )
    if not conv_res.data:
        raise HTTPException(404, "Conversation not found")

    msgs_res = (
        client.table("messages")
        .select("id,role,content,created_at")
        .eq("conversation_id", conversation_id)
        .order("created_at", desc=False)
        .execute()
    )
    return {"conversation": conv_res.data[0], "messages": msgs_res.data or []}


@router.delete("/conversations/{conversation_id}")
def delete_conversation(
    conversation_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    client = get_supabase_admin()
    conv_res = (
        client.table("conversations")
        .select("id")
        .eq("id", conversation_id)
        .eq("user_id", user.user_id)
        .limit(1)
        .execute()
    )
    if not conv_res.data:
        raise HTTPException(404, "Conversation not found")

    client.table("conversations").delete().eq("id", conversation_id).execute()
    return {"deleted": True}
