"""Additive world-chat API; legacy inventory chat remains unchanged."""
import asyncio
import json
import logging
from uuid import UUID, uuid4, uuid5, NAMESPACE_URL
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field
from app.core.limiter import limiter
from app.core.auth import AuthenticatedUser, get_current_user
from app.services import world_chat as world
from app.services import chat_sources
from app.services.supabase_client import get_supabase_raw
from app.services.completion_stream import async_iterate, CompletionStreamError
from app.services.limits import check_and_increment_chat, check_and_increment_scan, ChatLimitExceeded, ScanLimitExceeded, TeamSoftCapExceeded
from app.api.routes.ai import _authorized_stream

router = APIRouter(prefix='/worlds/{world_id}', tags=['world-chat'])
logger = logging.getLogger(__name__)


class Question(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    conversation_id: UUID | None = None
    supports_item_actions: bool = True
    supports_item_management: bool = False
    supports_capture: bool = False
    supports_photo_attachment: bool = False
    supports_task_actions: bool = False
    request_id: UUID | None = None
    sources: chat_sources.SourceList = Field(default_factory=list)


@router.get('/chat-sources')
def sources(world_id: str, inventory_id: UUID, kind: str,
            query: str = Query('', max_length=100), offset: int = Query(0, ge=0, le=10000),
            user: AuthenticatedUser = Depends(get_current_user)):
    return JSONResponse(chat_sources.search(user.user_id, world.world_key(world_id), str(inventory_id), kind, query, offset), headers={'Cache-Control': 'private, no-store'})


@router.post('/chat-files')
@limiter.limit('10/minute')
async def file_source(request: Request, world_id: str, file: UploadFile = File(...),
                      user: AuthenticatedUser = Depends(get_current_user)):
    await asyncio.to_thread(world.authorize, user.user_id, world.world_key(world_id))
    content = await file.read(chat_sources.MAX_BYTES + 1)
    # No inventory record, persistent file, or save destination is created here.
    result = await asyncio.to_thread(chat_sources.extract, file.filename or '', content)
    return JSONResponse(result, headers={'Cache-Control': 'private, no-store'})


@router.get('/directory')
def directory(world_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return world.directory(user.user_id, world.world_key(world_id))


@router.get('/spaces')
def spaces(world_id: str, user: AuthenticatedUser = Depends(get_current_user)):
    return world.spaces(user.user_id, world.world_key(world_id))


@router.get('/resources/{inventory_id}/{kind}/{resource_id}')
def resource(world_id: str, inventory_id: UUID, kind: str, resource_id: UUID,
             user: AuthenticatedUser = Depends(get_current_user)):
    return world.resolve_resource(user.user_id, world.world_key(world_id), str(inventory_id), kind, str(resource_id))


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
    # Hydrate references with the canonical draft, never a stale saved snapshot.
    from app.services.chat_capture import load
    for row in rows:
        context = row.get('answer_context') or {}
        capture_id = context.get('chat_capture_id')
        if capture_id:
            context['chat_capture'] = load(user.user_id, world.world_key(world_id), str(conversation_id), capture_id)['answer_context']['chat_capture']
    return {'conversation': value, 'messages': [row for row in rows if not any((row.get('answer_context') or {}).get(flag) for flag in ('direct_receipt', 'attachment_receipt'))]}


@router.delete('/conversations/{conversation_id}')
def delete_conversation(world_id: str, conversation_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    world.conversation(user.user_id, world.world_key(world_id), str(conversation_id))
    get_supabase_raw().table('conversations').delete().eq('id', str(conversation_id)).eq('user_id', user.user_id).eq('world_key', world.world_key(world_id)).execute()
    return {'deleted': True}


def encode(event):
    return 'data: ' + json.dumps(event) + '\n\n'


async def answer(actor, key, message, conversation_id, photo=None, *, supports_item_management=False, supports_capture=False, auto_extract=False, sources=None, supports_photo_attachment=False, supports_task_actions=False, request_id=None):
    key = await asyncio.to_thread(world.authorize, actor, key)
    source_evidence = await asyncio.to_thread(chat_sources.resolve, actor, key, sources) if sources else []
    try:
        await asyncio.to_thread(check_and_increment_chat, actor)
    except (ChatLimitExceeded, TeamSoftCapExceeded):
        raise HTTPException(403, 'Your chat allowance has been reached. Check your account settings.') from None
    turn_id = str(uuid5(NAMESPACE_URL, f'findez:request:{actor}:{key}:{request_id}')) if request_id else str(uuid4())
    cid, history = await asyncio.to_thread(world.prepare, actor, key, message, conversation_id, **({'turn_id': turn_id} if supports_task_actions else {}))
    async def generate():
        stored = None
        saved = False
        save_started = False
        matching = None
        stage = 'load_draft'
        try:
            yield encode({'type': 'status', 'message': 'Understanding your request…', 'conversation_id': cid})
            from app.services.chat_item_actions import use_photo, photo_facts
            from app.services import chat_capture
            draft_row = await asyncio.to_thread(chat_capture.load, actor, key, cid) if supports_capture and not photo else None
            draft = draft_row['answer_context']['chat_capture'] if draft_row else None
            retained = ({'items': [r['item'] for r in draft['items']], 'source_url': draft['source_url']} if draft else
                        None if photo else await asyncio.to_thread(world.latest_photo, actor, key, cid))
            if supports_photo_attachment and not photo:
                retained = await asyncio.to_thread(world.latest_photo, actor, key, cid) or retained
            if draft and draft.get('source_kind') == 'text':
                retained = None
            evidence = photo_facts(retained) if supports_photo_attachment or not draft or draft['status'] != 'saved' else {}
            from app.services import chat_vision
            image_content = None
            if photo:
                from app.services.storage import upload_image
                yield encode({'type': 'status', 'message': 'Preparing your photo…'})
                stored = await asyncio.to_thread(upload_image, user_id=actor, filename=f'ask-{uuid4().hex}.jpg', content=photo)
                retained = {'items': [], 'source_url': stored.url}
                if auto_extract:
                    stage = 'extract_photo'
                    yield encode({'type': 'status', 'message': 'Extracting items...'})
                    await asyncio.to_thread(check_and_increment_scan, actor)
                    from app.services.photo_extraction import extract_inventory_items
                    progress = asyncio.Queue()
                    loop = asyncio.get_running_loop()
                    def report(message):
                        loop.call_soon_threadsafe(progress.put_nowait, message)
                    extraction = asyncio.create_task(extract_inventory_items(
                        filename='photo.jpg', image_bytes=photo, content_type='image/jpeg',
                        user_id=actor, source_frame_url=stored.url, on_progress=report))
                    try:
                        while not extraction.done() or not progress.empty():
                            try:
                                update = await asyncio.wait_for(progress.get(), timeout=0.2)
                            except asyncio.TimeoutError:
                                continue
                            yield encode({'type': 'status', 'message': update})
                        result = await extraction
                    finally:
                        # A worker thread cannot be cancelled mid-upload. Settle it
                        # before source cleanup; do not leave an unobserved task.
                        if not extraction.done():
                            await asyncio.shield(extraction)
                    from app.services.item_photos import _storage_path
                    for item in result.get('items', [])[:20]:
                        clean = {k: item.get(k) for k in ('name', 'category', 'quantity', 'confidence', 'brand', 'part_number')}
                        if item.get('image_url'):
                            clean['crop_path'] = _storage_path(user_id=actor, image_url=item['image_url'])
                        retained['items'].append(clean)
                    if supports_capture:
                        draft = await asyncio.to_thread(chat_capture.create, actor, key, cid, result.get('items', []), stored.url, result.get('summary'))
                        saved = True
                        yield encode({'type': 'capture', 'conversation_id': cid, 'answer_context': {'chat_capture': draft}})
                    evidence = {**photo_facts(retained), 'note': 'Uncertain observations are not verified identities or stock counts.'}
                else:
                    stage = 'read_chat_photo'
                    yield encode({'type': 'status', 'message': 'Looking at your photo...'})
                    retained.update(mode='chat', source_path=stored.path)
                    image_content = chat_vision.image_part(photo)
                    evidence = photo_facts(retained)
                    if supports_task_actions:
                        await asyncio.to_thread(chat_vision.retain, actor, key, cid, turn_id, retained)
                        saved = True
            elif retained and retained.get('mode') == 'chat':
                draft = None
                stage = 'load_chat_photo'
                image_content = await asyncio.to_thread(chat_vision.retained_image, actor, retained)
            yield encode({'type': 'status', 'message': 'Loading your conversation context...'})
            stage = 'chat_reply'
            from app.services.world_user_context import load as load_user_context
            user_context = await asyncio.to_thread(load_user_context, actor) if supports_task_actions else None
            with use_photo(retained), chat_capture.use_capture(actor, key, cid, draft, enabled=supports_capture) as capture:
                async for event in async_iterate(world.stream_turn(actor, key, message, history, cid, evidence, supports_item_management=supports_item_management, **({'supports_task_actions': True, 'turn_id': turn_id, 'user_context': user_context} if supports_task_actions else {}), **({'supports_photo_attachment': True} if supports_photo_attachment else {}), **({'source_evidence': source_evidence} if source_evidence else {}), **({'image_content': image_content} if image_content else {}))):
                    if event['type'] == 'done':
                        if stored:
                            event['answer_context'].update({'photo_path': stored.path, 'photo_url': stored.url, 'chat_photo': retained})
                        if source_evidence:
                            event['answer_context']['selected_sources'] = [{k: v for k, v in s.items() if k in ('kind', 'name', 'inventory_id', 'resource_id', 'truncated')} for s in source_evidence]
                            event['answer_context'].setdefault('sources', []).extend({'kind': {'space': 'spaces', 'item': 'inventory', 'file': 'document'}.get(s['kind'], s['kind']), 'label': s['name'], 'detail': 'Selected excerpt' if s.get('truncated') else 'Selected for this message'} for s in source_evidence)
                        stage = 'save_reply'
                        save_started = True
                        await asyncio.to_thread(world.save_answer, actor, key, cid, event['assistant_message'], event['answer_context'])
                        saved = True
                        if supports_capture and capture['draft']:
                            event['answer_context']['chat_capture'] = capture['draft']
                    yield encode(event)
            yield 'data: [DONE]\n\n'
        except (ScanLimitExceeded, TeamSoftCapExceeded):
            yield encode({'type': 'error', 'message': 'Your photo allowance has been reached. Check your account settings.'})
        except asyncio.CancelledError:
            raise
        except Exception as error:
            # No exception messages, prompts, URLs, credentials or customer IDs.
            import traceback
            frames = traceback.extract_tb(error.__traceback__)
            location = frames[-1].name if frames else 'unknown'
            logger.warning('World chat failed stage=%s error_type=%s location=%s reason=%s',
                           stage, type(error).__name__, location,
                           error.code if isinstance(error, CompletionStreamError) else 'unclassified')
            yield encode({'type': 'error', 'code': 'history_save_failed' if stage == 'save_reply' else 'world_chat_failed', 'conversation_id': cid, 'message': 'I could not finish this response. Retry to check the result of this request.'})
        finally:
            if matching is not None:
                if not matching.done():
                    matching.cancel()
                await asyncio.gather(matching, return_exceptions=True)
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
    return await answer(user.user_id, world.world_key(world_id), body.message, str(body.conversation_id) if body.conversation_id else None, supports_item_management=body.supports_item_management, supports_capture=body.supports_capture, sources=body.sources, supports_photo_attachment=body.supports_photo_attachment, supports_task_actions=body.supports_task_actions, request_id=body.request_id)


@router.post('/ai_photo_question')
@limiter.limit('10/minute')
async def photo(request: Request, world_id: str, file: UploadFile = File(...), message: str = Form('', max_length=8000),
                conversation_id: UUID | None = Form(None), supports_item_management: bool = Form(False), supports_capture: bool = Form(False), auto_extract: bool = Form(False), supports_photo_attachment: bool = Form(False), supports_task_actions: bool = Form(False), request_id: UUID | None = Form(None), sources: str = Form('[]', max_length=110000), user: AuthenticatedUser = Depends(get_current_user)):
    try:
        selected_sources = chat_sources.source_adapter.validate_json(sources)
    except ValueError:
        raise HTTPException(422, 'Choose valid chat sources.') from None
    from app.services.item_photos import _jpeg_bytes, MAX_ITEM_PHOTO_BYTES
    raw = await file.read(MAX_ITEM_PHOTO_BYTES + 1)
    if len(raw) > MAX_ITEM_PHOTO_BYTES:
        raise HTTPException(413, 'Choose a photo smaller than 10 MB.')
    try:
        jpeg = await asyncio.to_thread(_jpeg_bytes, raw)
    except ValueError:
        raise HTTPException(422, 'Choose a valid photo smaller than 10 MB.') from None
    return await answer(user.user_id, world.world_key(world_id), message.strip() or 'Help me with this photo. Ask whether I want to identify, find or save its contents if that is unclear.', str(conversation_id) if conversation_id else None, jpeg, supports_item_management=supports_item_management, supports_capture=supports_capture, auto_extract=auto_extract, sources=selected_sources, supports_photo_attachment=supports_photo_attachment, supports_task_actions=supports_task_actions, request_id=request_id)


class Decision(BaseModel):
    decision: str = Field(pattern='^(confirm|cancel)$')
    supports_task_actions: bool = False


@router.post('/structure-actions/{action_id}')
@limiter.limit('20/minute')
def decide(request: Request, world_id: str, action_id: UUID, body: Decision, user: AuthenticatedUser = Depends(get_current_user)):
    key = world.authorize(user.user_id, world.world_key(world_id))
    from app.services.limits import resolve_effective_limits
    owners = {user.user_id}
    for workspace in world.directory(user.user_id, key)['workspaces']:
        owners.add(world._workspace(workspace['workspace_id'], user.user_id)['owner_user_id'])
    limits = {owner: resolve_effective_limits(owner)[0] for owner in owners}
    space_limits = {owner: value.get('spaces') for owner, value in limits.items()}
    try:
        if body.supports_task_actions:
            from app.services.world_tasks import confirm
            result = confirm(user.user_id, key, str(action_id), body.decision, space_limits,
                {owner: value.get('items') for owner, value in limits.items()})
        else:
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
    from app.services.chat_capture import attach_created_destination
    # Creation already has a durable receipt. If the draft changed concurrently,
    # keep that successful receipt and let its destination be chosen in the card.
    try:
        capture = attach_created_destination(user.user_id, key, result)
    except HTTPException:
        return {'action': result, 'capture_warning': 'Space created. Your draft changed; choose the destination in the draft to continue.'}
    return {'action': result, **({'capture': capture} if capture else {})}


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
        cards = (messages[0].get('answer_context') or {}).get('pending_actions', [])
        card = next((c for c in cards if c.get('id') == str(action_id)), {})
        if card.get('version') == 2:
            from app.services.world_item_changes import change_action as change_item
            result = change_item(actor=user.user_id, world=key, inventory=str(inventory_id), action_id=str(action_id), decision=body.decision)
        else:
            result = change_action(actor=user.user_id, action_id=str(action_id), decision=body.decision)
    return {'action': result}


class CaptureEdit(BaseModel):
    revision: int = Field(ge=1)
    changes: dict


class CaptureSave(BaseModel):
    revision: int = Field(ge=1)
    allow_duplicates: bool = False


@router.get('/conversations/{conversation_id}/captures/{capture_id}')
def capture_draft(world_id: str, conversation_id: UUID, capture_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_capture import load
    return {'capture': load(user.user_id, world.world_key(world_id), str(conversation_id), str(capture_id))['answer_context']['chat_capture']}


@router.patch('/conversations/{conversation_id}/captures/{capture_id}')
@limiter.limit('60/minute')
def edit_capture(request: Request, world_id: str, conversation_id: UUID, capture_id: UUID, body: CaptureEdit, user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_capture import edit, DraftEdit
    from pydantic import ValidationError
    try:
        changes = DraftEdit.model_validate(body.changes)
    except ValidationError:
        raise HTTPException(422, 'Check the extracted item details.') from None
    return {'capture': edit(user.user_id, world.world_key(world_id), str(conversation_id), str(capture_id), body.revision, changes)}


@router.post('/conversations/{conversation_id}/captures/{capture_id}/save')
@limiter.limit('60/minute')
def save_capture(request: Request, world_id: str, conversation_id: UUID, capture_id: UUID, body: CaptureSave, user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_capture import save
    try:
        return {'capture': save(user.user_id, world.world_key(world_id), str(conversation_id), str(capture_id), body.revision, body.allow_duplicates)}
    except HTTPException:
        raise
    except Exception as error:
        import traceback
        frames = traceback.extract_tb(error.__traceback__)
        logger.warning('Chat capture save unconfirmed error_type=%s location=%s',
                       type(error).__name__, frames[-1].name if frames else 'unknown')
        raise HTTPException(503, 'Saving could not be confirmed. Refresh and retry this same draft safely.') from None


@router.post('/captures/spreadsheet')
@limiter.limit("5/minute")
async def spreadsheet_draft(request: Request, world_id: str, file: UploadFile = File(...),
                            conversation_id: UUID | None = Form(default=None),
                            user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.spreadsheet_import import MAX_IMPORT_BYTES, parse_import_tables, build_import_items
    from app.services.limits import check_and_increment_import
    from app.services.usage_service import check_limit, increment_usage
    key = await asyncio.to_thread(world.authorize, user.user_id, world.world_key(world_id))
    if conversation_id:
        await asyncio.to_thread(world.conversation, user.user_id, key, str(conversation_id))
    raw = await file.read(MAX_IMPORT_BYTES + 1)
    try:
        tables = await asyncio.to_thread(parse_import_tables, raw, file.filename or '')
        items = await asyncio.to_thread(build_import_items, tables, filename=file.filename or '', location='')
    except ValueError as error:
        raise HTTPException(413 if len(raw) > MAX_IMPORT_BYTES else 422, str(error)) from None
    if not items or len(items) > 10000:
        raise HTTPException(422, 'Choose a spreadsheet with 1 to 10,000 items per chat draft.')
    # Fail before creating a conversation or charging for an invalid draft.
    from app.schemas.inventory import ExtractedInventoryItem
    from pydantic import ValidationError
    try:
        items = [ExtractedInventoryItem.model_validate(item).model_dump(exclude_none=True) for item in items]
    except ValidationError:
        raise HTTPException(422, 'Some spreadsheet values exceed item limits. Shorten long names or notes and check quantities.') from None
    try:
        await asyncio.to_thread(check_and_increment_import, user.user_id)
    except TeamSoftCapExceeded:
        raise HTTPException(403, 'Your workspace import allowance has been reached.') from None
    allowance = await check_limit(user.user_id, 'spreadsheet_import')
    if not allowance['allowed']:
        raise HTTPException(403, 'Your spreadsheet import allowance has been reached.')
    await increment_usage(user.user_id, 'spreadsheet_import')
    return await _capture_draft(user.user_id, key, conversation_id, items, 'spreadsheet',
                               'Extract the items from this spreadsheet and help me choose where to save them.')


class BarcodeDraft(BaseModel):
    barcode: str = Field(min_length=1, max_length=100)
    conversation_id: UUID | None = None


@router.post('/captures/barcode')
@limiter.limit("15/minute")
async def barcode_draft(request: Request, world_id: str, body: BarcodeDraft,
                        user: AuthenticatedUser = Depends(get_current_user)):
    from app.api.routes.items import lookup_barcode_product
    from app.services.usage_service import check_limit
    key = await asyncio.to_thread(world.authorize, user.user_id, world.world_key(world_id))
    if body.conversation_id:
        await asyncio.to_thread(world.conversation, user.user_id, key, str(body.conversation_id))
    code = body.barcode.strip()
    if not code:
        raise HTTPException(422, 'Scan or enter a barcode.')
    if not (await check_limit(user.user_id, 'barcode_scan'))['allowed']:
        raise HTTPException(403, 'Your barcode allowance has been reached.')
    product = await lookup_barcode_product(code, user.user_id)
    unknown = not product.name or product.name.lower() == 'unknown item'
    item = {'name': product.name or 'Unknown item', 'category': product.category or 'Other',
            'quantity': 1, 'barcode': code, 'brand': product.brand, 'part_number': product.model,
            'image_url': product.image_url,
            'scan_evidence': {'needs_review': unknown,
                              'review_reasons': ['Confirm the identity of this barcode.'] if unknown else []}}
    return await _capture_draft(user.user_id, key, body.conversation_id, [item], 'barcode',
                               f'Extract barcode {code} and help me choose where to save it.')


async def _capture_draft(actor, key, conversation_id, items, kind, prompt):
    from app.services import chat_capture
    cid, _ = await asyncio.to_thread(world.prepare, actor, key, prompt, str(conversation_id) if conversation_id else None)
    draft = await asyncio.to_thread(chat_capture.create, actor, key, cid, items, None, source_kind=kind)
    return {'conversation_id': cid, 'capture': draft}


class PhotoDecision(BaseModel):
    decision: str = Field(pattern=r'^(confirm|cancel)$')
    inventory_id: UUID | None = None
    item_id: UUID | None = None


@router.get('/conversations/{conversation_id}/photo-attachments/{attachment_id}')
def photo_attachment(world_id: str, conversation_id: UUID, attachment_id: UUID,
                     user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_photo_attachment import load
    return {'attachment': load(user.user_id, world.world_key(world_id), str(conversation_id), str(attachment_id))['answer_context']['photo_attachment']}


@router.post('/conversations/{conversation_id}/photo-attachments/{attachment_id}')
@limiter.limit('20/minute')
def attach_photo(request: Request, world_id: str, conversation_id: UUID, attachment_id: UUID, body: PhotoDecision,
                 user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.chat_photo_attachment import decide
    return {'attachment': decide(user.user_id, world.world_key(world_id), str(conversation_id), str(attachment_id),
        body.decision, str(body.inventory_id) if body.inventory_id else None, str(body.item_id) if body.item_id else None)}
