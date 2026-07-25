from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_gateway, bad_request
from app.core.limiter import limiter
from app.schemas.ai import AICommandRequest, AICommandResponse
from app.services.ai_agent import iter_ai_command_sse, run_ai_command
from app.services.documents_repo import create_activity
from app.services.openai_service import iter_assist_file_analysis_sse
from app.services.usage_service import check_limit, increment_usage

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


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

            gen = iter_ai_command_sse(user_id=user.user_id, message=payload.message, first_name=user.first_name, conversation_history=payload.conversation_history or None)
            wrapped = _wrap_sse(gen)
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


@router.post("/ai_upload")
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
