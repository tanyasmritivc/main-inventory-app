"""Space-only question routes. Main world and legacy chat routes are unchanged."""
import asyncio
import json
import logging
from uuid import UUID
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field, TypeAdapter
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.api.routes.ai import _authorized_stream
from app.services import space_questions as service
from app.services.chat_sources import FileSource, MAX_BYTES, MAX_TOTAL_TEXT
from app.services.completion_stream import async_iterate
from app.services.item_photos import _jpeg_bytes
from app.services.limits import check_and_increment_chat, ChatLimitExceeded, TeamSoftCapExceeded
from app.services.supabase_client import get_supabase_admin

router = APIRouter(prefix='/space-chat/{space_id}', tags=['Space chat'])
logger = logging.getLogger(__name__)
file_sources = TypeAdapter(list[FileSource])


class Question(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    conversation_id: UUID | None = None
    sources: list[FileSource] = Field(default_factory=list, max_length=4)


def _sources(sources):
    if len(sources) > 4 or sum(len(s.text) for s in sources) > MAX_TOTAL_TEXT:
        raise HTTPException(422, 'Use up to four files with less text in total.')


async def respond(space_id, question, conversation_id, sources, photo=None):
    _sources(sources)
    evidence = await asyncio.to_thread(service.snapshot, space_id)
    if conversation_id:
        await asyncio.to_thread(service.conversation, space_id, conversation_id)
    try:
        await asyncio.to_thread(check_and_increment_chat, service.scope().actor_id)
    except (ChatLimitExceeded, TeamSoftCapExceeded):
        raise HTTPException(403, 'Your chat allowance has been reached.') from None
    cid, history = await asyncio.to_thread(service.prepare, space_id, question, conversation_id)

    def event(value):
        return ('data: ' + json.dumps(value) + '\n\n').encode()

    async def generate():
        yield event({'type': 'status', 'message': 'Checking this Space...', 'conversation_id': cid})
        try:
            async for item in async_iterate(service.answer(question, evidence, history, sources, photo)):
                if item['type'] == 'answer':
                    try:
                        done = await asyncio.to_thread(service.save, space_id, cid, item['text'], evidence)
                    except Exception:
                        logger.exception('Space answer history could not be saved')
                        yield event({'type': 'error', 'code': 'history_save_failed'})
                        return
                    yield event(done)
                else:
                    yield event(item)
        except Exception:
            logger.exception('Space answer could not be completed')
            yield event({'type': 'error', 'code': 'space_chat_failed'})
    return StreamingResponse(_authorized_stream(generate()), media_type='text/event-stream',
                             headers={'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no'})


@router.post('/ai_command')
@limiter.limit('20/minute')
async def question(request: Request, space_id: UUID, body: Question,
                   user: AuthenticatedUser = Depends(get_current_user)):
    return await respond(str(space_id), body.message, str(body.conversation_id) if body.conversation_id else None, body.sources)


@router.post('/ai_photo_question')
@limiter.limit('10/minute')
async def photo_question(request: Request, space_id: UUID, file: UploadFile = File(...),
                         message: str = Form('', max_length=8000), conversation_id: UUID | None = Form(None),
                         sources: str = Form('[]', max_length=110000),
                         user: AuthenticatedUser = Depends(get_current_user)):
    await asyncio.to_thread(service.space, str(space_id))
    raw = await file.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise HTTPException(413, 'Choose a photo smaller than 10 MB.')
    try:
        selected = file_sources.validate_json(sources)
        jpeg = await asyncio.to_thread(_jpeg_bytes, raw)
    except ValueError:
        raise HTTPException(422, 'Choose a valid photo and supported file attachments.') from None
    return await respond(str(space_id), message.strip() or 'Do I have anything like this in this Space?',
                         str(conversation_id) if conversation_id else None, selected, jpeg)


@router.post('/chat-files')
@limiter.limit('20/minute')
async def chat_file(request: Request, space_id: UUID, file: UploadFile = File(...),
                    user: AuthenticatedUser = Depends(get_current_user)):
    await asyncio.to_thread(service.space, str(space_id))
    return await asyncio.to_thread(service.file_text, file.filename or '', await file.read(MAX_BYTES + 1))


@router.get('/conversations')
def chats(space_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return service.list_conversations(str(space_id))


@router.get('/conversations/{conversation_id}')
def chat(space_id: UUID, conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    return {'conversation': service.conversation(str(space_id), str(conversation_id)),
            'messages': service.messages(str(space_id), str(conversation_id))}


@router.delete('/conversations/{conversation_id}')
def delete_chat(space_id: UUID, conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    service.conversation(str(space_id), str(conversation_id))
    get_supabase_admin().table('conversations').delete().eq('id', str(conversation_id)).execute()
    return {'deleted': True}
