from __future__ import annotations

import re
from io import BytesIO


def _clean_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = re.sub(r"[ \t\f\v]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_text_from_pdf(*, pdf_bytes: bytes, max_chars: int = 200_000) -> tuple[str, bool]:
    from pypdf import PdfReader

    reader = PdfReader(BytesIO(pdf_bytes))
    parts: list[str] = []
    for page in reader.pages:
        try:
            t = page.extract_text() or ""
        except Exception:
            t = ""
        if t:
            parts.append(t)
        if sum(len(p) for p in parts) >= max_chars:
            break

    raw = "\n\n".join(parts)
    cleaned = _clean_text(raw)

    truncated = len(cleaned) > max_chars
    if truncated:
        cleaned = cleaned[:max_chars]

    return cleaned, truncated


def extract_text_from_upload(*, filename: str, mime_type: str | None, content: bytes) -> tuple[str | None, bool]:
    mime = (mime_type or "").lower().strip()
    name = (filename or "").lower()

    if mime == "application/pdf" or name.endswith(".pdf"):
        try:
            text, truncated = extract_text_from_pdf(pdf_bytes=content)
            return (text if text.strip() else None), truncated
        except Exception:
            return None, False

    if mime == "text/plain" or name.endswith(".txt") or name.endswith(".md") or name.endswith(".csv"):
        try:
            text = content.decode("utf-8", errors="replace")
        except Exception:
            return None, False

        cleaned = _clean_text(text)
        truncated = len(cleaned) > 200_000
        if truncated:
            cleaned = cleaned[:200_000]
        return (cleaned if cleaned.strip() else None), truncated

    return None, False
