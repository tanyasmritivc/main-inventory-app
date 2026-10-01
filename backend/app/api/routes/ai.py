import asyncio
import json as json_module
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_gateway, bad_request
from app.core.limiter import limiter
from app.schemas.ai import AICommandRequest, AICommandResponse
from app.services.ai_agent import (
    iter_ai_command_events_async,
    iter_ai_command_sse,
    iter_ai_command_sse_async,
    run_ai_command,
)
from app.services.ai_memory import (
    extract_and_save_memory,
    fetch_similar_history,
    fetch_user_memory,
    log_query,
    save_conversation,
)
from app.services.documents_repo import create_activity
from app.services.ask_photo_questions import answer_photo_question, remember_photo_answer
from app.services.find_pipeline import FindPipelineError
from app.services.item_photos import MAX_ITEM_PHOTO_BYTES, _jpeg_bytes
from app.services.ai_service import iter_assist_file_analysis_sse
from app.services.supabase_client import get_supabase_admin
from app.services.limits import ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded, check_and_increment_chat, check_and_increment_scan

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


def _prepare_ask_conversation(*, user_id: str, message: str, conversation_id: str | None) -> str:
    client = get_supabase_admin()
    if conversation_id:
        rows = client.table('conversations').select('id').eq('id', conversation_id).eq('user_id', user_id).limit(1).execute().data
        if not rows:
            raise HTTPException(404, 'This conversation is unavailable. Start a new chat.')
    else:
        rows = client.table('conversations').insert({'user_id': user_id, 'title': message[:60]}).execute().data
        conversation_id = ((rows or [{}])[0]).get('id')
        if not conversation_id:
            raise RuntimeError('Conversation insert returned no identity')
    client.table('messages').insert({'conversation_id': conversation_id, 'role': 'user', 'content': message}).execute()
    return conversation_id


def _save_ask_answer(*, conversation_id: str, answer: dict) -> None:
    client = get_supabase_admin()
    client.table('messages').insert({
        'conversation_id': conversation_id, 'role': 'assistant',
        'content': answer['assistant_message'], 'answer_context': answer.get('answer_context'),
    }).execute()
    client.table('conversations').update({'updated_at': datetime.now(timezone.utc).isoformat()}).eq('id', conversation_id).execute()


@router.post('/ai_photo_question', response_model=None)
@limiter.limit('10/minute')
async def ai_photo_question_route(
    request: Request,
    file: UploadFile = File(...),
    message: str = Form('What is in this photo? Do I already have it?', max_length=2000),
    conversation_id: str | None = Form(None, max_length=100),
    user: AuthenticatedUser = Depends(get_current_user),
) -> StreamingResponse:
    raw = await file.read(MAX_ITEM_PHOTO_BYTES + 1)
    if len(raw) > MAX_ITEM_PHOTO_BYTES:
        raise HTTPException(413, 'Choose a photo smaller than 10 MB.')
    try:
        jpeg = await asyncio.to_thread(_jpeg_bytes, raw)
    except ValueError:
        raise bad_request('Choose a valid photo smaller than 10 MB and 25 megapixels.')
    question = message.strip() or 'What is in this photo? Do I already have it?'
    if conversation_id:
        def check_owner():
            rows = get_supabase_admin().table('conversations').select('id').eq('id', conversation_id).eq('user_id', user.user_id).limit(1).execute().data
            if not rows:
                raise HTTPException(404, 'This conversation is unavailable. Start a new chat.')
        try:
            await asyncio.to_thread(check_owner)
        except HTTPException:
            raise
        except Exception:
            raise bad_gateway('Your conversation could not be checked. Please try again.')
    try:
        await asyncio.to_thread(check_and_increment_scan, user.user_id)
        await asyncio.to_thread(check_and_increment_chat, user.user_id)
    except (ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded):
        raise HTTPException(403, 'Your account photo or chat limit has been reached.')
    except Exception:
        raise bad_gateway('Your account limits could not be checked. Please try again.')
    try:
        conv_id = await asyncio.to_thread(_prepare_ask_conversation, user_id=user.user_id, message=question, conversation_id=conversation_id)
    except HTTPException:
        raise
    except Exception:
        logger.exception('Could not save the photo question')
        raise bad_gateway('Your photo question could not be saved. Please try again.')

    async def generate():
        task = asyncio.create_task(answer_photo_question(user_id=user.user_id, message=question, image_bytes=jpeg))
        try:
            yield b'data: {"type":"status","message":"Reading your photo..."}\n\n'
            while not task.done():
                await asyncio.wait({task}, timeout=5)
                if not task.done():
                    yield b'data: {"type":"status","message":"Photo analysis is still running..."}\n\n'
            answer = await task
            yield f"data: {json_module.dumps({'type': 'delta', 'delta': answer['assistant_message']})}\n\n".encode()
            try:
                await asyncio.to_thread(_save_ask_answer, conversation_id=conv_id, answer=answer)
            except Exception:
                logger.exception('Photo answer snapshot could not be saved')
                yield b'data: {"type":"error","code":"history_save_failed"}\n\n'
                yield b'data: [DONE]\n\n'
                return
            try:
                await asyncio.to_thread(remember_photo_answer, user_id=user.user_id, message=question, answer=answer['assistant_message'])
            except Exception:
                logger.warning('Photo follow-up memory unavailable; answer snapshot is saved')
            yield f"data: {json_module.dumps({'type': 'done', 'assistant_message': answer['assistant_message'], 'answer_context': answer.get('answer_context'), 'conversation_id': conv_id})}\n\n".encode()
            yield b'data: [DONE]\n\n'
        except FindPipelineError as exc:
            code = 'photo_timeout' if exc.status_code == 504 else 'photo_failed'
            yield f"data: {json_module.dumps({'type': 'error', 'code': code})}\n\n".encode()
            yield b'data: [DONE]\n\n'
        except Exception:
            logger.exception('Photo question could not be completed')
            yield b'data: {"type":"error","code":"photo_failed"}\n\n'
            yield b'data: [DONE]\n\n'
        finally:
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
    return StreamingResponse(generate(), media_type='text/event-stream', headers={'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no'})


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
@limiter.limit("20/minute")
async def ai_command_route(
    request: Request,
    payload: AICommandRequest,
    background_tasks: BackgroundTasks,
    user: AuthenticatedUser = Depends(get_current_user),
    stream: bool = False,
) -> AICommandResponse:
    try:
        check_and_increment_chat(user.user_id)
    except TeamSoftCapExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "TEAM_SOFT_CAP",
                "feature": exc.feature,
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": f"Your team has used {exc.current} of {exc.limit} {exc.feature} for this period.",
            },
        )
    except ChatLimitExceeded as exc:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "CHAT_LIMIT_REACHED",
                "current": exc.current,
                "limit": exc.limit,
                "resets_at": exc.resets_at,
                "message": f"You've used all {exc.limit} AI chat messages for this month. Resets {exc.resets_at[:10]}.",
            },
        )

    accept = (request.headers.get("accept") or "").lower()
    wants_stream = bool(stream) or ("text/event-stream" in accept)

    if wants_stream:
        try:
            # Never silently claim an answer was saved if its history write fails.
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
                        raise HTTPException(404, 'This conversation no longer exists or is not accessible. Start a new chat.')
                if not conv_id:
                    title = payload.message[:60]
                    res = (
                        supabase.table("conversations")
                        .insert({"user_id": user.user_id, "title": title})
                        .execute()
                    )
                    conv_id = ((res.data or [{}])[0]).get("id")
                    if not conv_id:
                        raise RuntimeError('Conversation insert returned no identity')
                if conv_id:
                    supabase.table("messages").insert({
                        "conversation_id": conv_id,
                        "role": "user",
                        "content": payload.message,
                    }).execute()
            except HTTPException:
                raise
            except Exception:
                logger.exception("Failed to set up conversation history")
                raise bad_gateway("Your chat could not be saved. Please try again.")

            # Fetch memory context (best-effort — failures are silent)
            memory_context = ""
            try:
                user_memory_str, similar_history_str = await asyncio.gather(
                    fetch_user_memory(user.user_id),
                    fetch_similar_history(user.user_id, payload.message),
                )
                if user_memory_str:
                    memory_context += f"\n\n{user_memory_str}"
                if similar_history_str:
                    memory_context += f"\n\n{similar_history_str}"
            except Exception:
                logger.exception("Memory context fetch failed — continuing without")
                memory_context = ""

            async def generate():
                delta_buffer: list[str] = []
                try:
                    async for item in iter_ai_command_events_async(
                        user_id=user.user_id,
                        message=payload.message,
                        first_name=user.first_name,
                        conversation_history=payload.conversation_history or None,
                        memory_context=memory_context or None,
                        conversation_id=conv_id,
                    ):
                        if item.get("type") == "delta":
                            content = item.get("delta") or ""
                            if content:
                                delta_buffer.append(content)
                                data = f"data: {json_module.dumps({'content': content})}\n\n"
                                padding = ":" + (" " * max(0, 1200 - len(data))) + "\n"
                                yield (data + padding).encode("utf-8")
                        elif item.get("type") == "done":
                            full_response = "".join(delta_buffer) or item.get("assistant_message") or "Something went wrong. Please try again."
                            answer_context = item.get("answer_context")
                            if conv_id:
                                try:
                                    sb = get_supabase_admin()
                                    sb.table("messages").insert({
                                        "conversation_id": conv_id,
                                        "role": "assistant",
                                        "content": full_response,
                                        "answer_context": answer_context,
                                    }).execute()
                                    sb.table("conversations").update({
                                        "updated_at": datetime.now(timezone.utc).isoformat(),
                                    }).eq("id", conv_id).execute()
                                except Exception:
                                    logger.exception("Failed to persist assistant message")
                                    yield b'data: {"type":"error","error":"Your answer could not be saved. Please try again."}\n\n'
                                    yield b"data: [DONE]\n\n"
                                    return
                            asyncio.create_task(extract_and_save_memory(user.user_id, payload.message, full_response))
                            asyncio.create_task(log_query(user.user_id, payload.message))
                            asyncio.create_task(save_conversation(user.user_id, payload.message, full_response))
                            nav_hint = item.get("nav_hint")
                            yield f"data: {json_module.dumps({'type': 'done', 'answer_context': answer_context, 'conversation_id': conv_id, 'nav_hint': nav_hint, 'assistant_message': full_response})}\n\n".encode("utf-8")
                    yield b"data: [DONE]\n\n"
                except Exception as exc:
                    logger.exception("AI streaming failed")
                    yield b'data: {"type":"error","error":"Ask is temporarily unavailable. Please try again."}\n\n'
                    yield b"data: [DONE]\n\n"

            return StreamingResponse(
                generate(),
                media_type="text/event-stream",
                headers={
                    "X-Accel-Buffering": "no",
                    "Cache-Control": "no-cache, no-transform",
                    "Connection": "keep-alive",
                },
            )
        except HTTPException:
            raise
        except Exception:
            logger.exception("AI command stream failed")
            raise bad_gateway("AI temporarily unavailable. Please try again.")

    try:
        out = run_ai_command(
            user_id=user.user_id,
            message=payload.message,
            first_name=user.first_name,
            conversation_history=payload.conversation_history or None,
            conversation_id=payload.conversation_id,
        )
    except Exception:
        logger.exception("AI command failed")
        raise bad_gateway("AI temporarily unavailable. Please try again.")

    try:
        create_activity(
            user_id=user.user_id,
            summary="Used Assist",
            metadata={"type": "ai_chat", "tool": out.get("tool"), "message": payload.message},
                    )
    except Exception:
        logger.exception("Failed to write ai_chat activity")

    assistant_message = out.get("assistant_message") or ""
    background_tasks.add_task(extract_and_save_memory, user.user_id, payload.message, assistant_message)
    background_tasks.add_task(log_query, user.user_id, payload.message)
    background_tasks.add_task(save_conversation, user.user_id, payload.message, assistant_message)

    return AICommandResponse(
        tool=out.get("tool"),
        result=out.get("result"),
        assistant_message=assistant_message or "Let me think about that...",
        answer_context=out.get("answer_context"),
    )


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
