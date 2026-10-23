"""Direct multimodal chat. No FIND calls, inferred crops, or scan allowance."""
import base64
from fastapi import HTTPException
from app.services.storage import document_path_in_scope


def image_part(content):
    if not content or len(content) > 10 * 1024 * 1024:
        raise HTTPException(422, 'This photo could not be read. Attach it again.')
    return {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,' + base64.b64encode(content).decode('ascii')}}


def retained_image(actor, photo):
    # Never fetch arbitrary URLs supplied by a user/model. Conversation ownership
    # is checked before loading this server-owned storage locator.
    if not photo or photo.get('mode') != 'chat':
        return None
    path = photo.get('source_path', '')
    if not isinstance(path, str) or not document_path_in_scope(path, actor + '/'):
        raise HTTPException(403, 'This photo is unavailable in this conversation.')
    from app.core.config import get_settings
    from app.services.supabase_client import get_supabase_raw
    content = get_supabase_raw().storage.from_(get_settings().supabase_storage_bucket).download(path)
    return image_part(content)


def retain(actor, key, cid, turn_id, photo):
    from app.services import world_chat as world
    from app.services.supabase_client import get_supabase_raw
    world.conversation(actor, key, cid)
    result = (get_supabase_raw().table('messages').update({'answer_context': {'chat_photo': photo}})
              .eq('id', turn_id).eq('conversation_id', cid).eq('role', 'user').execute().data or [])
    if len(result) != 1:
        raise RuntimeError('The chat attachment could not be retained')
