from __future__ import annotations

import asyncio
import json as json_module
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse
from jose import jwt as _jose_jwt

from app.core.auth import (
    AuthenticatedUser,
    _cache_first_name,
    _get_cached_first_name,
    _jwks_cache,
    _select_jwk,
    get_current_user,
)
from app.core.config import get_settings
from app.core.errors import bad_gateway, bad_request
from app.core.limiter import limiter
from app.schemas.ai import AICommandRequest, AICommandResponse
from app.services.ai_agent import (
    iter_ai_command_events_async,
    iter_ai_command_sse,
    iter_ai_command_sse_async,
    run_ai_command,
)
from app.services.documents_repo import create_activity
from app.services.openai_service import iter_assist_file_analysis_sse
from app.services.supabase_client import get_supabase_admin
from app.services.usage_service import check_limit, increment_usage

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


def _wrap_sse(gen):
    done_sent = False
    try:
        for chunk in gen:
            if not done_sent and isinstance(chunk, str) and '"type": "done"' in chunk:
                done_sent = True
            yield chunk
    except Exception:
        logger.exception("AI command stream generator failed")
    finally:
        if not done_sent:
            yield 'event: end\n'
            yield 'data: {"type":"done","tool":null,"result":null,"assistant_message":"Let me think about that..."}\n\n'


def _wrap_sse_with_conv(gen, conversation_id: str):
    """SSE wrapper that buffers assistant text and persists messages to the DB."""
    client = get_supabase_admin()
    done_sent = False
    delta_buffer: list[str] = []

    try:
        for chunk in gen:
            if not isinstance(chunk, str):
                yield chunk
                continue

            is_done = '"type": "done"' in chunk or '"type":"done"' in chunk
            is_delta = '"type": "delta"' in chunk or '"type":"delta"' in chunk

            if is_delta:
                for line in chunk.split('\n'):
                    if line.startswith('data:'):
                        try:
                            evt = json_module.loads(line[5:].strip())
                            d = evt.get('delta') or ''
                            if d:
                                delta_buffer.append(d)
                        except Exception:
                            pass

            if is_done:
                done_sent = True
                assistant_text = ''.join(delta_buffer)
                intercepted = False
                for line in chunk.split('\n'):
                    if not line.startswith('data:'):
                        continue
                    try:
                        evt = json_module.loads(line[5:].strip())
                        if evt.get('type') != 'done':
                            continue
                        full_msg = assistant_text or evt.get('assistant_message') or ''
                        try:
                            client.table("messages").insert({
                                "conversation_id": conversation_id,
                                "role": "assistant",
                                "content": full_msg,
                            }).execute()
                            client.table("conversations").update({
                                "updated_at": datetime.now(timezone.utc).isoformat(),
                            }).eq("id", conversation_id).execute()
                        except Exception:
                            logger.exception("Failed to persist assistant message")
                        evt['conversation_id'] = conversation_id
                        yield f'data: {json_module.dumps(evt)}\n\n'
                        intercepted = True
                        break
                    except Exception:
                        pass
                if not intercepted:
                    yield chunk
                continue

            yield chunk

    except Exception:
        logger.exception("AI command stream generator failed")
    finally:
        if not done_sent:
            assistant_text = ''.join(delta_buffer)
            try:
                client.table("messages").insert({
                    "conversation_id": conversation_id,
                    "role": "assistant",
                    "content": assistant_text,
                }).execute()
                client.table("conversations").update({
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", conversation_id).execute()
            except Exception:
                logger.exception("Failed to persist assistant message in fallback")
            done_evt = {
                "type": "done",
                "tool": None,
                "result": None,
                "assistant_message": assistant_text or "Let me think about that...",
                "conversation_id": conversation_id,
            }
            yield 'event: end\n'
            yield f'data: {json_module.dumps(done_evt)}\n\n'


async def _wrap_sse_async(async_gen):
    """Async version of _wrap_sse — passes through chunks from an async generator."""
    done_sent = False
    try:
        async for chunk in async_gen:
            if not done_sent and isinstance(chunk, str) and '"type": "done"' in chunk:
                done_sent = True
            yield chunk
    except Exception:
        logger.exception("AI command stream generator failed")
    finally:
        if not done_sent:
            yield 'event: end\n'
            yield 'data: {"type":"done","tool":null,"result":null,"assistant_message":"Let me think about that..."}\n\n'


async def _wrap_sse_with_conv_async(async_gen, conversation_id: str):
    """Async SSE wrapper that buffers assistant text and persists messages to DB."""
    client = get_supabase_admin()
    done_sent = False
    delta_buffer: list[str] = []

    try:
        async for chunk in async_gen:
            if not isinstance(chunk, str):
                yield chunk
                continue

            is_done = '"type": "done"' in chunk or '"type":"done"' in chunk
            is_delta = '"type": "delta"' in chunk or '"type":"delta"' in chunk

            if is_delta:
                for line in chunk.split('\n'):
                    if line.startswith('data:'):
                        try:
                            evt = json_module.loads(line[5:].strip())
                            d = evt.get('delta') or ''
                            if d:
                                delta_buffer.append(d)
                        except Exception:
                            pass

            if is_done:
                done_sent = True
                assistant_text = ''.join(delta_buffer)
                intercepted = False
                for line in chunk.split('\n'):
                    if not line.startswith('data:'):
                        continue
                    try:
                        evt = json_module.loads(line[5:].strip())
                        if evt.get('type') != 'done':
                            continue
                        full_msg = assistant_text or evt.get('assistant_message') or ''
                        try:
                            client.table("messages").insert({
                                "conversation_id": conversation_id,
                                "role": "assistant",
                                "content": full_msg,
                            }).execute()
                            client.table("conversations").update({
                                "updated_at": datetime.now(timezone.utc).isoformat(),
                            }).eq("id", conversation_id).execute()
                        except Exception:
                            logger.exception("Failed to persist assistant message")
                        evt['conversation_id'] = conversation_id
                        yield f'data: {json_module.dumps(evt)}\n\n'
                        intercepted = True
                        break
                    except Exception:
                        pass
                if not intercepted:
                    yield chunk
                continue

            yield chunk

    except Exception:
        logger.exception("AI command stream generator failed")
    finally:
        if not done_sent:
            assistant_text = ''.join(delta_buffer)
            try:
                client.table("messages").insert({
                    "conversation_id": conversation_id,
                    "role": "assistant",
                    "content": assistant_text,
                }).execute()
                client.table("conversations").update({
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", conversation_id).execute()
            except Exception:
                logger.exception("Failed to persist assistant message in fallback")
            done_evt = {
                "type": "done",
                "tool": None,
                "result": None,
                "assistant_message": assistant_text or "Let me think about that...",
                "conversation_id": conversation_id,
            }
            yield 'event: end\n'
            yield f'data: {json_module.dumps(done_evt)}\n\n'


@router.post("/ai_command", response_model=AICommandResponse)
@limiter.limit("15/minute")
async def ai_command_route(
    request: Request,
    payload: AICommandRequest,
    user: AuthenticatedUser = Depends(get_current_user),
    stream: bool = False,
) -> AICommandResponse:
    limit_check = await check_limit(user.user_id, "ai_chat")
    if not limit_check["allowed"]:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "limit_exceeded",
                "feature": "ai_chat",
                "feature_label": limit_check["feature_label"],
                "current": limit_check["current"],
                "limit": limit_check["limit"],
                "message": f"You've used all {limit_check['limit']} free AI chat messages this month.",
            },
        )

    accept = (request.headers.get("accept") or "").lower()
    wants_stream = bool(stream) or ("text/event-stream" in accept)

    if wants_stream:
        try:
            # Setup conversation persistence (best-effort — AI always works even if DB fails)
            conv_id: str | None = payload.conversation_id
            try:
                supabase = get_supabase_admin()
                if conv_id:
                    check = (
                        supabase.table("conversations")
                        .select("id")
                        .eq("id", conv_id)
                        .eq("user_id", user.user_id)
                        .limit(1)
                        .execute()
                    )
                    if not check.data:
                        conv_id = None
                if not conv_id:
                    title = payload.message[:60]
                    res = (
                        supabase.table("conversations")
                        .insert({"user_id": user.user_id, "title": title})
                        .execute()
                    )
                    conv_id = ((res.data or [{}])[0]).get("id")
                if conv_id:
                    supabase.table("messages").insert({
                        "conversation_id": conv_id,
                        "role": "user",
                        "content": payload.message,
                    }).execute()
            except Exception:
                logger.exception("Failed to setup conversation — continuing without persistence")
                conv_id = None

            gen = iter_ai_command_sse_async(user_id=user.user_id, message=payload.message, first_name=user.first_name, conversation_history=payload.conversation_history or None)
            wrapped = _wrap_sse_with_conv_async(gen, conv_id) if conv_id else _wrap_sse_async(gen)
            await increment_usage(user.user_id, "ai_chat")
            return StreamingResponse(
                wrapped,
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )
        except Exception:
            logger.exception("AI command stream failed")
            raise bad_gateway("AI temporarily unavailable. Please try again.")

    try:
        out = run_ai_command(user_id=user.user_id, message=payload.message, first_name=user.first_name, conversation_history=payload.conversation_history or None)
    except Exception:
        logger.exception("AI command failed")
        raise bad_gateway("AI temporarily unavailable. Please try again.")

    await increment_usage(user.user_id, "ai_chat")

    try:
        create_activity(
            user_id=user.user_id,
            summary="Used Assist",
            metadata={"type": "ai_chat", "tool": out.get("tool"), "message": payload.message},
                    )
    except Exception:
        logger.exception("Failed to write ai_chat activity")

    return AICommandResponse(
        tool=out.get("tool"),
        result=out.get("result"),
        assistant_message=out.get("assistant_message") or "Let me think about that...",
    )


@router.websocket("/ws/chat")
async def chat_websocket_route(
    websocket: WebSocket,
    token: str = Query(...),
) -> None:
    """WebSocket chat endpoint — same agent + persistence as /ai_command, streaming over WS."""
    # Verify JWT before accepting — invalid/missing token is rejected at protocol level (403)
    settings = get_settings()
    try:
        jwks = await _jwks_cache.get(str(settings.supabase_jwks_url))
        jwk = _select_jwk(jwks=jwks, token=token)
        claims = _jose_jwt.decode(
            token, jwk,
            algorithms=["ES256", "RS256"],
            audience=settings.supabase_jwt_audience,
            options={"verify_iss": False},
        )
    except Exception:
        await websocket.close(code=1008)
        return

    user_id = str(claims.get("sub") or "")
    if not user_id:
        await websocket.close(code=1008)
        return

    cached, first_name = _get_cached_first_name(user_id)
    if not cached:
        first_name = None
        try:
            supabase = get_supabase_admin()
            resp = supabase.table("profiles").select("first_name").eq("id", user_id).maybe_single().execute()
            d = resp.data if isinstance(resp.data, dict) else None
            fn = (d or {}).get("first_name")
            if isinstance(fn, str):
                fn = fn.strip()
                first_name = fn or None
        except Exception:
            pass
        _cache_first_name(user_id, first_name)

    user = AuthenticatedUser(user_id=user_id, first_name=first_name)

    await websocket.accept()
    try:
        # Monthly usage gate
        limit_check = await check_limit(user.user_id, "ai_chat")
        if not limit_check["allowed"]:
            await websocket.send_json({
                "type": "error",
                "error": "limit_exceeded",
                "feature": "ai_chat",
                "message": f"You've used all {limit_check['limit']} free AI chat messages this month.",
            })
            await websocket.close()
            return

        try:
            data = await asyncio.wait_for(websocket.receive_json(), timeout=30.0)
        except (asyncio.TimeoutError, Exception):
            await websocket.close(code=4008)
            return

        message = (data.get("message") or "").strip()
        if not message:
            await websocket.send_json({"type": "error", "message": "Empty message"})
            await websocket.close()
            return

        conv_id: str | None = data.get("conversation_id") or None
        conversation_history = data.get("conversation_history") or None

        # Conversation persistence setup (best-effort)
        try:
            supabase = get_supabase_admin()
            if conv_id:
                check = (
                    supabase.table("conversations")
                    .select("id")
                    .eq("id", conv_id)
                    .eq("user_id", user.user_id)
                    .limit(1)
                    .execute()
                )
                if not check.data:
                    conv_id = None
            if not conv_id:
                res = (
                    supabase.table("conversations")
                    .insert({"user_id": user.user_id, "title": message[:60]})
                    .execute()
                )
                conv_id = ((res.data or [{}])[0]).get("id")
            if conv_id:
                supabase.table("messages").insert({
                    "conversation_id": conv_id,
                    "role": "user",
                    "content": message,
                }).execute()
        except Exception:
            logger.exception("Failed to setup WebSocket conversation — continuing without persistence")
            conv_id = None

        # Stream tokens over WebSocket
        full_text = ""
        last_tool: str | None = None
        try:
            async for item in iter_ai_command_events_async(
                user_id=user.user_id,
                message=message,
                first_name=user.first_name,
                conversation_history=conversation_history,
            ):
                if item.get("type") == "delta":
                    d = item.get("delta") or ""
                    if d:
                        full_text += d
                        await websocket.send_json({"type": "delta", "delta": d})
                elif item.get("type") == "done":
                    last_tool = item.get("tool")
        except Exception:
            logger.exception("WebSocket agent streaming failed")

        # Persist assistant message (best-effort)
        if conv_id:
            try:
                supabase = get_supabase_admin()
                supabase.table("messages").insert({
                    "conversation_id": conv_id,
                    "role": "assistant",
                    "content": full_text or "Let me think about that...",
                }).execute()
                supabase.table("conversations").update({
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }).eq("id", conv_id).execute()
            except Exception:
                logger.exception("Failed to persist WebSocket assistant message")

        await increment_usage(user.user_id, "ai_chat")

        await websocket.send_json({
            "type": "done",
            "conversation_id": conv_id,
            "tool": last_tool,
            "assistant_message": full_text or "Let me think about that...",
        })

    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected")
    except Exception:
        logger.exception("WebSocket chat error")
        try:
            await websocket.send_json({"type": "error", "message": "Something went wrong. Please try again."})
        except Exception:
            pass
    finally:
        try:
            await websocket.close()
        except Exception:
            pass


@router.post("/ai_upload", response_model=None)
@limiter.limit("10/minute")
def ai_upload_route(
    request: Request,
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
) -> StreamingResponse:
    accept = (request.headers.get("accept") or "").lower()
    wants_stream = "text/event-stream" in accept
    if not wants_stream:
        raise bad_request("Streaming required")

    try:
        raw = file.file.read() if file.file is not None else b""
    except Exception:
        logger.exception("Failed to read uploaded file")
        raise bad_request("Invalid upload")

    def _wrap_sse(gen):
        done_sent = False
        try:
            for chunk in gen:
                if not done_sent and isinstance(chunk, str) and '"type": "done"' in chunk:
                    done_sent = True
                yield chunk
        except Exception:
            logger.exception("AI upload stream generator failed")
        finally:
            if not done_sent:
                yield 'event: end\n'
                yield 'data: {"type":"done","tool":null,"result":null,"assistant_message":""}\n\n'

    gen = iter_assist_file_analysis_sse(
        filename=file.filename or "upload",
        mime_type=file.content_type,
        content=raw,
    )
    wrapped = _wrap_sse(gen)
    return StreamingResponse(
        wrapped,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
