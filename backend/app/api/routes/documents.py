
import logging

import httpx
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Response, UploadFile
from fastapi import status
from pydantic import BaseModel, Field

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_gateway, bad_request, service_unavailable
from app.schemas.documents import ListDocumentsResponse, UploadDocumentResponse
from app.services.documents_repo import (
    create_activity,
    create_document,
    get_document,
    list_documents,
    rename_document,
    set_document_item_link,
)
from app.services.ai_service import summarize_activity
from app.services.storage import create_document_signed_url, document_path_in_scope, upload_document
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


class RenameDocumentRequest(BaseModel):
    storage_path: str = Field(max_length=500)
    display_name: str = Field(max_length=200)


class DocumentLinkRequest(BaseModel):
    storage_path: str = Field(max_length=500)
    item_id: str | None = Field(default=None, max_length=36)


class NoteRequest(BaseModel):
    storage_path: str = Field(max_length=500)
    text: str = Field(max_length=1_000_000)


@router.patch('/documents/note')
def update_note(payload: NoteRequest, user: AuthenticatedUser = Depends(get_current_user)):
    doc = get_document(user_id=user.user_id,storage_path=payload.storage_path)
    if not doc:
        raise HTTPException(404,'Note not found.')
    if doc.get('mime_type') != 'text/plain' and not str(doc.get('filename','')).lower().endswith('.txt'):
        raise HTTPException(422,'Choose a text note.')
    client = get_supabase_admin()
    content = payload.text.encode('utf-8')
    client.storage.from_('documents').update(payload.storage_path,content,file_options={'content-type':'text/plain'})
    rows = client.table('documents').update({'size_bytes':len(content)}).eq('user_id',user.user_id).eq('storage_path',payload.storage_path).execute().data or []
    return {'document':{**doc,**(rows[0] if rows else {})}}


@router.post("/documents/upload", response_model=UploadDocumentResponse)
async def upload_document_route(
    file: UploadFile = File(...),
    item_id: str | None = Form(None),
    user: AuthenticatedUser = Depends(get_current_user),
) -> UploadDocumentResponse:
    raw = await file.read()
    if not raw:
        raise bad_request("Empty file")

    filename = file.filename or "upload"
    content_type = (file.content_type or "").lower()
    allowed = {
        "application/pdf",
        "text/plain",
        "image/png",
        "image/jpg",
        "image/jpeg",
        "image/webp",
    }
    if content_type and content_type not in allowed:
        raise bad_request("Unsupported file type")

    try:
        from app.services.inventory_scope import current_inventory
        if item_id and current_inventory.get():
            get_supabase_admin().record('items','item_id',item_id.strip())
        stored = upload_document(user_id=user.user_id, filename=filename, content=raw)

        mime = (file.content_type or "").lower()
        file_type = "pdf" if (mime == "application/pdf" or filename.lower().endswith(".pdf")) else "image"

        doc = create_document(
            user_id=user.user_id,
            filename=filename,
            mime_type=file.content_type,
            storage_path=stored.path,
            file_type=file_type,
            size_bytes=len(raw),
            item_id=(item_id or "").strip() or None,
        )

        summary = summarize_activity(action="upload_document", details={"filename": filename, "mime_type": file.content_type})
        create_activity(user_id=user.user_id, summary=summary, metadata={"type": "upload_document", "storage_path": stored.path})

        return UploadDocumentResponse(document=doc, activity_summary=summary)
    except httpx.HTTPError:
        logger.exception("Upstream error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")
    except HTTPException:
        raise
    except Exception:
        logger.exception("Unhandled error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")


@router.get("/documents", response_model=ListDocumentsResponse)
def list_documents_route(
    user: AuthenticatedUser = Depends(get_current_user),
    item_id: str | None = None,
    limit: int = Query(default=200, ge=1, le=500),
) -> ListDocumentsResponse:
    docs = list_documents(user_id=user.user_id, limit=limit, item_id=item_id)
    return ListDocumentsResponse(documents=docs)


@router.get("/documents/open")
def open_document_route(
    response: Response,
    storage_path: str = Query(max_length=500),
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    path = (storage_path or "").strip()
    if not path or ".." in path:
        raise bad_request("Invalid storage path")
    try:
        doc=get_document(user_id=user.user_id,storage_path=path)
        if not doc or not document_path_in_scope(path,f"{doc.get('user_id') or user.user_id}/"):
            raise bad_request("Document not found")
        response.headers['Cache-Control']='private, no-store'
        return {"url": create_document_signed_url(storage_path=path)}
    except HTTPException:
        raise
    except Exception:
        logger.exception("Failed to open document")
        raise service_unavailable("Could not open document. Please try again.")


@router.patch("/documents/rename")
def rename_document_route(
    payload: RenameDocumentRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    storage_path = (payload.storage_path or "").strip()
    display_name = (payload.display_name or "").strip()
    if not storage_path:
        raise bad_request("Missing storage_path")
    if not display_name:
        raise bad_request("Missing display_name")

    try:
        doc = rename_document(user_id=user.user_id, storage_path=storage_path, display_name=display_name)
        if not doc:
            raise bad_request("Rename failed")
        return {"document": doc}
    except httpx.HTTPError:
        logger.exception("Upstream error during document rename")
        raise service_unavailable("Rename temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document rename")
        raise service_unavailable("Rename temporarily unavailable. Please try again.")


@router.patch("/documents/link")
def link_document_route(
    payload: DocumentLinkRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    storage_path = (payload.storage_path or "").strip()
    if not storage_path:
        raise bad_request("Missing storage_path")

    try:
        doc = set_document_item_link(user_id=user.user_id, storage_path=storage_path, item_id=payload.item_id)
        if not doc:
            raise bad_request("Update failed")
        return {"document": doc}
    except httpx.HTTPError:
        logger.exception("Upstream error during document link update")
        raise service_unavailable("Update temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document link update")
        raise service_unavailable("Update temporarily unavailable. Please try again.")


@router.delete("/documents", status_code=status.HTTP_204_NO_CONTENT)
def delete_document_route(
    storage_path: str = Query(max_length=500),
    user: AuthenticatedUser = Depends(get_current_user),
) -> Response:
    if not storage_path or not storage_path.strip():
        raise bad_request("Missing storage_path")
    if ".." in storage_path:
        raise bad_request("Invalid storage path")

    doc=get_document(user_id=user.user_id,storage_path=storage_path)
    if not doc or not document_path_in_scope(storage_path,f"{doc.get('user_id') or user.user_id}/"):
        raise HTTPException(404, "Document not found.")

    try:
        supabase = get_supabase_admin()
        from app.services.inventory_scope import current_inventory
        scope=current_inventory.get()
        raw = supabase.raw if scope else supabase
        # Historical uploads can have multiple rows referencing one object.
        # Removing one inventory's record must not break another's document.
        result=raw.table('documents').select('user_id,inventory_id,inventory_visibility',count='exact').eq('storage_path',storage_path).execute()
        references=result.data or []
        def selected(row):
            return (row.get('inventory_id')==scope.inventory_id and
                    (row.get('inventory_visibility')=='inventory' or row.get('user_id')==scope.actor_id)) if scope else row.get('user_id')==user.user_id
        # An unknown/truncated reference set is never treated as unreferenced.
        complete=result.count is not None and result.count==len(references)
        if complete and all(selected(row) for row in references):
            supabase.storage.from_('documents').remove([storage_path])
        supabase.table("documents").delete().eq("user_id", user.user_id).eq("storage_path", storage_path).execute()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except httpx.HTTPError:
        logger.exception("Upstream error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")
