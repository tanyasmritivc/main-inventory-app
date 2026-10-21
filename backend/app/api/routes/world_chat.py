"""Additive world-chat API; legacy inventory chat remains unchanged."""
import asyncio
import json
import logging
from uuid import UUID
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from app.core.limiter import limiter
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import world_chat as world
from app.services.supabase_client import get_supabase_raw
from app.services.completion_stream import async_iterate
from app.services.limits import check_and_increment_chat, check_and_increment_scan, ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded
from app.api.routes.ai import _authorized_stream

router = APIRouter(prefix='/worlds/{world_id}', tags=['world-chat'])
logger = logging.getLogger(__name__)


class Question(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    conversation_id: UUID | None = None
    supports_item_actions: bool = True


@router.get('/directory')
def directory(world_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return world.directory(user.user_id, world.world_key(world_id))


@router.get('/spaces')
def spaces(world_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return world.spaces(user.user_id, world.world_key(world_id))


@router.get('/conversations')
def conversations(world_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return world.conversations(user.user_id, world.world_key(world_id)).order('updated_at', desc=True).limit(50).execute().data or []


@router.get('/conversations/{conversation_id}')
def conversation(world_id: str, conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    value = world.conversation(user.user_id, world.world_key(world_id), str(conversation_id))
    rows = get_supabase_raw().table('messages').select('id,role,content,created_at,answer_context').eq('conversation_id', str(conversation_id)).order('created_at').execute().data or []
    from app.services.ask_photo_questions import refresh_photo_context
    for row in rows:
        if row.get('answer_context'):
            row['answer_context'] = refresh_photo_context(row['answer_context'], user.user_id)
    return {'conversation': value, 'messages': rows}


@router.delete('/conversations/{conversation_id}')
def delete_conversation(world_id: str, conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    world.conversation(user.user_id, world.world_key(world_id), str(conversation_id))
    get_supabase_raw().table('conversations').delete().eq('id', str(conversation_id)).eq('user_id', user.user_id).eq('world_key', world.world_key(world_id)).execute()
    return {'deleted': True}


def encode(event):
    return 'data: ' + json.dumps(event) + '\n\n'


async def answer(actor, key, message, conversation_id, photo=None):
    key = await asyncio.to_thread(world.authorize, actor, key)
    try:
        await asyncio.to_thread(check_and_increment_chat, actor)
    except (ChatLimitExceeded, TeamSoftCapExceeded):
        raise HTTPException(403, 'Your chat allowance has been reached. Check your account settings.') from None
    cid, history = await asyncio.to_thread(world.prepare, actor, key, message, conversation_id)
    async def generate():
        stored = None
        saved = False
        save_started = False
        try:
            from app.services.chat_item_actions import use_photo, photo_facts
            retained = await asyncio.to_thread(world.latest_photo, actor, key, cid)
            evidence = photo_facts(retained)
            if photo:
                from app.services.storage import upload_image
                from app.services.find_pipeline import extract_inventory_items_with_find
                from uuid import uuid4
                yield encode({'type': 'status', 'message': 'Reading your photo...'})
                await asyncio.to_thread(check_and_increment_scan, actor)
                stored = await asyncio.to_thread(upload_image, user_id=actor, filename=f'ask-{uuid4().hex}.jpg', content=photo)
                result = await extract_inventory_items_with_find(filename='photo.jpg', image_bytes=photo, content_type='image/jpeg', user_id=actor, source_frame_url=stored.url)
                from app.services.item_photos import _storage_path
                retained = {'items': [], 'source_url': stored.url}
                for item in result.get('items', [])[:20]:
                    clean = {k: item.get(k) for k in ('name', 'category', 'quantity', 'confidence', 'brand', 'part_number')}
                    if item.get('image_url'):
                        clean['crop_path'] = _storage_path(user_id=actor, image_url=item['image_url'])
                    retained['items'].append(clean)
                evidence = {**photo_facts(retained), 'saved_photos': await world.photo_matches(actor, key, photo),
                    'note': 'Uncertain observations are not verified identities or stock counts.'}
            with use_photo(retained):
                async for event in async_iterate(world.stream_turn(actor, key, message, history, cid, evidence)):
                    if event['type'] == 'done':
                        if stored:
                            event['answer_context'].update({'photo_path': stored.path, 'photo_url': stored.url, 'chat_photo': retained})
                        save_started = True
                        await asyncio.to_thread(world.save_answer, actor, key, cid, event['assistant_message'], event['answer_context'])
                        saved = True
                    yield encode(event)
            yield 'data: [DONE]\n\n'
        except (ScanLimitExceeded, TeamSoftCapExceeded):
            yield encode({'type': 'error', 'message': 'Your photo allowance has been reached. Check your account settings.'})
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.warning('World chat failed; provider details omitted')
            yield encode({'type': 'error', 'code': 'world_chat_failed', 'message': 'Your request could not be completed. Please try again.'})
        finally:
            if stored and not saved and not save_started:
                from app.services.storage import delete_image
                try:
                    await asyncio.to_thread(delete_image, path=stored.path)
                except Exception:
                    logger.warning('World photo cleanup pending')
    return StreamingResponse(_authorized_stream(generate()), media_type='text/event-stream',
        headers={'Cache-Control': 'no-store, no-transform', 'X-Accel-Buffering': 'no'})


@router.post('/ai_command')
@limiter.limit('20/minute')
async def command(request: Request, world_id: str, body: Question, user: AuthenticatedUser = Depends(get_current_user)):
    return await answer(user.user_id, world.world_key(world_id), body.message, str(body.conversation_id) if body.conversation_id else None)


@router.post('/ai_photo_question')
@limiter.limit('10/minute')
async def photo(request: Request, world_id: str, file: UploadFile = File(...), message: str = Form('', max_length=8000),
                conversation_id: UUID | None = Form(None), user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.item_photos import _jpeg_bytes, MAX_ITEM_PHOTO_BYTES
    raw = await file.read(MAX_ITEM_PHOTO_BYTES + 1)
    if len(raw) > MAX_ITEM_PHOTO_BYTES:
        raise HTTPException(413, 'Choose a photo smaller than 10 MB.')
    try:
        jpeg = await asyncio.to_thread(_jpeg_bytes, raw)
    except ValueError:
        raise HTTPException(422, 'Choose a valid photo smaller than 10 MB.') from None
    return await answer(user.user_id, world.world_key(world_id), message.strip() or 'Help me with this photo. Ask whether I want to identify, find or save its contents if that is unclear.', str(conversation_id) if conversation_id else None, jpeg)


class Decision(BaseModel):
    decision: str = Field(pattern='^(confirm|cancel)$')


@router.post('/structure-actions/{action_id}')
@limiter.limit('20/minute')
def decide(request: Request, world_id: str, action_id: UUID, body: Decision, user: AuthenticatedUser = Depends(get_current_user)):
    key = world.authorize(user.user_id, world.world_key(world_id))
    from app.services.limits import resolve_effective_limits
    owners = {user.user_id}
    for workspace in world.directory(user.user_id, key)['workspaces']:
        owners.add(world._workspace(workspace['workspace_id'], user.user_id)['owner_user_id'])
    space_limits = {owner: resolve_effective_limits(owner)[0].get('spaces') for owner in owners}
    try:
        result = get_supabase_raw().rpc('findez_world_structure_action', {
            'p_actor': user.user_id, 'p_world': key, 'p_action': str(action_id), 'p_decision': body.decision, 'p_space_limits': space_limits}).execute().data
    except Exception as error:
        code = getattr(error, 'code', None)
        if code == '42501':
            raise HTTPException(403, 'Your access changed. Review the destination again.') from None
        if code in ('P0002', '23514', '23505', '22023', '22P02'):
            raise HTTPException(409, 'This proposal expired or its destination changed. Ask again to review a new proposal.') from None
        raise HTTPException(502, 'This change could not be confirmed. Retry the same card safely.') from None
    if not isinstance(result, dict) or result.get('id') != str(action_id) or result.get('status') not in ('confirmed', 'cancelled'):
        raise HTTPException(503, 'The result could not be confirmed. Retry the same card safely.')
    return {'action': result}


@router.post('/inventories/{inventory_id}/ai_actions/{action_id}')
@limiter.limit('20/minute')
def item_decision(request: Request, world_id: str, inventory_id: UUID, action_id: UUID, body: Decision,
                  user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_item_actions import change_action
    key = world.authorize(user.user_id, world.world_key(world_id))
    # Fetch the card only in this author's selected world; legacy cards cannot be
    # smuggled into this endpoint through a target inventory parameter.
    rows = world.conversations(user.user_id, key).execute().data or []
    ids = [r['id'] for r in rows]
    messages = get_supabase_raw().table('messages').select('answer_context').in_('conversation_id', ids).contains('answer_context', {'pending_actions': [{'id': str(action_id), 'world': key}]}).limit(1).execute().data if ids else []
    if not messages:
        raise HTTPException(404, 'This action is unavailable in this organization.')
    with world.in_inventory(user.user_id, key, str(inventory_id)):
        result = change_action(actor=user.user_id, action_id=str(action_id), decision=body.decision)
    return {'action': result}
