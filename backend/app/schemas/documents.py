from __future__ import annotations

from pydantic import BaseModel


class DocumentRecord(BaseModel):
    storage_path: str
    user_id: str | None = None
    filename: str
    mime_type: str | None = None
    file_type: str | None = None
    size_bytes: int | None = None
    created_at: str | None = None


class UploadDocumentResponse(BaseModel):
    document: DocumentRecord
    activity_summary: str


class ListDocumentsResponse(BaseModel):
    documents: list[DocumentRecord]


class ActivityEntry(BaseModel):
    activity_id: str
    summary: str
    created_at: str


class RecentActivityResponse(BaseModel):
    activities: list[ActivityEntry]
