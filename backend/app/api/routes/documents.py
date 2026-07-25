from __future__ import annotations

import logging

import httpx
from fastapi import APIRouter, Depends, File, Form, Response, UploadFile
from fastapi import status
from pydantic import BaseModel

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.errors import bad_gateway, bad_request, service_unavailable
from app.schemas.documents import ListDocumentsResponse, UploadDocumentResponse
from app.services.documents_repo import (
    create_activity,
    create_document,
    list_documents,
    rename_document,
    set_document_item_link,
)
from app.services.openai_service import summarize_activity
from app.services.storage import upload_document
from app.services.supabase_client import get_supabase_admin

router = APIRouter(tags=["inventory"])

logger = logging.getLogger(__name__)


class RenameDocumentRequest(BaseModel):
    storage_path: str
    display_name: str


class DocumentLinkRequest(BaseModel):
    storage_path: str
    item_id: str | None = None


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
    except Exception:
        logger.exception("Unhandled error during document upload")
        raise service_unavailable("Upload temporarily unavailable. Please try again.")


@router.get("/documents", response_model=ListDocumentsResponse)
def list_documents_route(
    user: AuthenticatedUser = Depends(get_current_user),
    item_id: str | None = None,
    limit: int = 200,
) -> ListDocumentsResponse:
    docs = list_documents(user_id=user.user_id, limit=limit, item_id=item_id)
    return ListDocumentsResponse(documents=docs)


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
    storage_path: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> Response:
    if not storage_path or not storage_path.strip():
        raise bad_request("Missing storage_path")

    try:
        supabase = get_supabase_admin()
        supabase.storage.from_("documents").remove([storage_path])
        supabase.table("documents").delete().eq("user_id", user.user_id).eq("storage_path", storage_path).execute()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except httpx.HTTPError:
        logger.exception("Upstream error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")
    except Exception:
        logger.exception("Unhandled error during document deletion")
        raise service_unavailable("Delete temporarily unavailable. Please try again.")
