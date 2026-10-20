"""Authenticated image delivery: a photo URL is a locator, never a grant."""
import mimetypes
from urllib.parse import unquote
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Response
from app.core.auth import AuthenticatedUser, get_current_user
from app.core.config import get_settings
from app.services.supabase_client import get_supabase_raw

router = APIRouter(tags=['private-images'])


def safe_image_path(value: str) -> str:
    if not value or len(value)>1024 or any(ord(c)<32 for c in value) or '\\' in value:
        raise HTTPException(400,'Invalid image path.')
    parts=value.split('/')
    try: UUID(parts[0])
    except ValueError: raise HTTPException(400,'Invalid image path.') from None
    if len(parts)<2 or any(p in ('','.','..') for p in parts) or unquote(value)!=value:
        raise HTTPException(400,'Invalid image path.')
    return value


@router.get('/media/item-image')
def item_image(path: str=Query(min_length=1,max_length=1024),user:AuthenticatedUser=Depends(get_current_user)):
    path=safe_image_path(path)
    client=get_supabase_raw()
    try:
        allowed=client.rpc('findez_can_read_item_image',{'p_actor':user.user_id,'p_path':path}).execute().data
    except Exception:
        raise HTTPException(503,'Image permissions could not be checked.') from None
    if allowed is not True:
        raise HTTPException(404,'Image not found or access was removed.')
    try:
        content=client.storage.from_(get_settings().supabase_storage_bucket).download(path)
    except Exception:
        raise HTTPException(404,'Image not found.') from None
    if not isinstance(content,bytes) or len(content)>25*1024*1024:
        raise HTTPException(413,'This image could not be displayed.')
    mime=mimetypes.guess_type(path)[0]
    if mime not in ('image/jpeg','image/png','image/webp','image/gif','image/heic','image/avif'):
        mime='application/octet-stream'
    return Response(content,media_type=mime,headers={
        'Cache-Control':'private, no-store, max-age=0','Pragma':'no-cache',
        'X-Content-Type-Options':'nosniff','Vary':'Authorization','Content-Disposition':'inline',
    })
