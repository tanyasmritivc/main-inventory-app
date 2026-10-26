"""Validate personal document bytes independently of multipart metadata."""
from io import BytesIO
from pathlib import Path
import warnings

from fastapi import HTTPException
from PIL import Image

MAX_DOCUMENT_BYTES = 25 * 1024 * 1024
_TYPES = {'.pdf': 'application/pdf', '.txt': 'text/plain', '.png': 'image/png',
          '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp'}


def validate_document(filename: str, claimed_type: str | None, content: bytes) -> str:
    if len(content) > MAX_DOCUMENT_BYTES:
        raise HTTPException(413, 'Document must be 25 MB or smaller.')
    expected = _TYPES.get(Path(filename).suffix.lower())
    claimed = (claimed_type or '').split(';')[0].strip().lower()
    if claimed == 'image/jpg':
        claimed = 'image/jpeg'
    if not expected or claimed not in ('', 'application/octet-stream', expected):
        raise HTTPException(400, 'Choose a PDF, text, PNG, JPEG, or WebP file.')
    try:
        if expected == 'application/pdf':
            if not content.startswith(b'%PDF-'):
                raise ValueError('Invalid PDF')
        elif expected == 'text/plain':
            content.decode('utf-8')
            if b'\x00' in content:
                raise ValueError('Binary content')
        else:
            with warnings.catch_warnings():
                warnings.simplefilter('error', Image.DecompressionBombWarning)
                with Image.open(BytesIO(content)) as image:
                    if Image.MIME.get(image.format) != expected or image.width * image.height > 25_000_000:
                        raise ValueError('Invalid image')
                    image.verify()
    except (ValueError, OSError, SyntaxError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(400, 'The file contents do not match its type or are too large to process.') from None
    return expected
