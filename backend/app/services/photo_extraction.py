"""One provider switch for inventory extraction on every supported client."""

import asyncio
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
    source_frame_url=None
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
        return await asyncio.to_thread(extract, image_bytes, user_id, source_frame_url)
    except Exception as error:
        # Do not change providers silently or expose gateway content to clients.
        raise PhotoExtractionError(
            "Photo extraction could not finish. Try a closer photo with fewer objects.",
            status_code=503,
        ) from error
