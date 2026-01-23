from __future__ import annotations

from pydantic import BaseModel


class DocumentRecord(BaseModel):
    document_id: str
    filename: str
    mime_type: str | None = None
    url: str | None = None
    created_at: str


class UploadDocumentResponse(BaseModel):
    document: DocumentRecord
    activity_summary: str


class ActivityEntry(BaseModel):
    activity_id: str
    summary: str
    created_at: str


class RecentActivityResponse(BaseModel):
    activities: list[ActivityEntry]
