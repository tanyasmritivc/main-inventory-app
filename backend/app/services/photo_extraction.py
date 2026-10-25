"""One provider switch for inventory extraction on every supported client."""

import asyncio
import logging
import httpx
from app.core.config import get_settings
from app.services.find_pipeline import (
    FindPipelineError,
    extract_inventory_items_with_find,
)

PhotoExtractionError = FindPipelineError  # Preserve existing HTTP error handling.


async def extract_inventory_items(
    *,
    filename,
    image_bytes,
    content_type="image/jpeg",
    user_id=None,
    source_frame_url=None,
    on_progress=None,
):
    settings = get_settings()
    if settings.findez_extraction_provider == "find":
        return await extract_inventory_items_with_find(
            filename=filename,
            image_bytes=image_bytes,
            content_type=content_type,
            user_id=user_id,
            source_frame_url=source_frame_url,
        )
    from app.services.glm_extraction import extract

    try:
        return await asyncio.to_thread(
            extract,
            image_bytes,
            user_id,
            source_frame_url,
            **({"on_progress": on_progress} if on_progress else {}),
        )
    except Exception as error:
        logging.getLogger(__name__).warning("Photo extraction failed: %s", type(error).__name__)
        message = (
            "Photo analysis took too long. Retry this photo, or take a closer photo of fewer items."
            if isinstance(error, (TimeoutError, httpx.TimeoutException)) else
            "Photo extraction could not finish. Retry this photo, or take a closer photo with fewer objects."
        )
        # Do not change providers silently or expose gateway content to clients.
        raise PhotoExtractionError(
            message,
            status_code=503,
        ) from error
