import asyncio
import ipaddress
import io
import json
import logging
import time
from collections import Counter
from typing import Any
from urllib.parse import urlparse
from uuid import uuid4

import httpx
from PIL import Image

from app.core.config import get_settings
from app.services.storage import upload_image


logger = logging.getLogger(__name__)


class FindPipelineError(Exception):
    def __init__(self, public_message: str, *, status_code: int = 503) -> None:
        super().__init__(public_message)
        self.public_message = public_message
        self.status_code = status_code


def _validated_base_url(raw_url: str, *, allow_insecure_http: bool = False) -> str:
    url = raw_url.rstrip("/")
    parsed = urlparse(url)
    if parsed.scheme == "https":
        return url
    if parsed.scheme != "http" or not parsed.hostname:
        raise FindPipelineError("Photo analysis is not configured.")

    try:
        host = ipaddress.ip_address(parsed.hostname)
    except ValueError:
        host = None
    if parsed.hostname in {"localhost", "127.0.0.1", "::1"} or (
        host is not None and (host.is_private or host.is_loopback)
    ):
        return url
    if allow_insecure_http:
        logger.warning(
            "FIND is configured over plain HTTP; enable TLS or a private route as soon as available"
        )
        return url
    raise FindPipelineError(
        "Photo analysis is waiting for a secure pipeline connection."
    )


def _clean_string(value: Any, *, limit: int) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = " ".join(value.split()).strip()
    return cleaned[:limit] or None


def _public_reasoning(identity: dict[str, Any]) -> str | None:
    """Describe the visible basis for a result without exposing internals.

    Pipeline-provided free text is intentionally not returned to clients. It can
    contain implementation names, infrastructure details, or debugging prose.
    """
    name = _clean_string(identity.get("name"), limit=200)
    vendor = _clean_string(identity.get("vendor"), limit=100)
    sku = _clean_string(identity.get("sku"), limit=100)
    if bool(identity.get("unknown")) or not name:
        return "The visible details were not distinctive enough for a reliable identification."
    details: list[str] = []
    if vendor:
        details.append(f"brand markings match {vendor}")
    if sku:
        details.append(f"the visible part number is {sku}")
    if details:
        return f"Identified as {name} because " + " and ".join(details) + "."
    return (
        f"Visible shape, markings, and surrounding context support the identification {name}."
    )


def _category(value: Any) -> str:
    raw = str(value or "other").strip().lower()
    categories = {
        "fastener": "Hardware",
        "standoff": "Hardware",
        "structure": "Robot Parts",
        "motion": "Robot Parts",
        "wheel": "Robot Parts",
        "motor": "Robot Parts",
        "electronics": "Electronics",
        "battery": "Batteries",
        "cable": "Electronics",
        "tool": "Tools",
        "consumable": "Supplies",
        "packaging": "Supplies",
        "game": "Other",
        "other": "Other",
    }
    return categories.get(raw, "Other")


def _notes(item: dict[str, Any], identity: dict[str, Any]) -> str | None:
    parts: list[str] = []
    reasoning = _public_reasoning(identity)
    if reasoning:
        parts.append(reasoning)

    dimensions = item.get("dimensions")
    if isinstance(dimensions, dict):
        size = dimensions.get("obb_mm")
        if isinstance(size, list) and len(size) >= 2:
            try:
                long_mm = round(float(size[0]), 2)
                short_mm = round(float(size[1]), 2)
                confidence = _clean_string(dimensions.get("confidence"), limit=20)
                suffix = f" ({confidence} confidence)" if confidence else ""
                parts.append(f"Measured {long_mm} × {short_mm} mm{suffix}.")
            except (TypeError, ValueError):
                pass

    ocr = item.get("ocr")
    if isinstance(ocr, dict):
        text = _clean_string(ocr.get("text"), limit=500)
        if text:
            parts.append(f"Visible text: {text}")

    errors = item.get("errors")
    if isinstance(errors, list) and errors:
        parts.append("Some analysis branches were incomplete; review this item.")
    return " ".join(parts)[:2000] or None


def _confidence(value: Any) -> float | None:
    try:
        return max(0.0, min(1.0, float(value)))
    except (TypeError, ValueError):
        return None


def _scan_evidence(
    item: dict[str, Any],
    identity: dict[str, Any],
    *,
    measurement_assumption: str | None,
) -> dict[str, Any]:
    barcode = item.get("barcode")
    if not isinstance(barcode, dict):
        barcode = {}
    ocr = item.get("ocr")
    if not isinstance(ocr, dict):
        ocr = {}
    dimensions = item.get("dimensions")
    if not isinstance(dimensions, dict):
        dimensions = {}

    length_mm: float | None = None
    width_mm: float | None = None
    size = dimensions.get("obb_mm")
    if isinstance(size, list) and len(size) >= 2:
        try:
            length_mm = round(float(size[0]), 2)
            width_mm = round(float(size[1]), 2)
        except (TypeError, ValueError):
            length_mm = None
            width_mm = None

    errors = item.get("errors")
    identity_confidence = _confidence(identity.get("confidence"))
    review_reasons: list[str] = []
    warnings: list[str] = []
    if identity.get("unknown"):
        review_reasons.append("The item could not be identified reliably.")
    if item.get("low_confidence") or (
        identity_confidence is not None and identity_confidence < 0.65
    ):
        review_reasons.append("The identification confidence is low.")
    if isinstance(errors, list) and errors:
        review_reasons.append("Some details could not be read from this photo.")
        warnings.append("Only part of the photo analysis completed.")
    if not _clean_string(identity.get("name"), limit=200):
        review_reasons.append("A clear item name is still needed.")
    needs_review = bool(review_reasons)

    method = _clean_string(dimensions.get("method"), limit=20)
    if method:
        lowered_method = method.lower()
        if "ruler" in lowered_method or "reference" in lowered_method:
            method = "ruler"
        elif "scale" in lowered_method or "calibrat" in lowered_method:
            method = "calibrated scale"
        else:
            method = "visual estimate"
    return {
        "identification_reasoning": _public_reasoning(identity),
        "identity_confidence": identity_confidence,
        "ocr_text": _clean_string(ocr.get("text"), limit=500),
        "ocr_confidence": _confidence(ocr.get("mean_conf")),
        "length_mm": length_mm,
        "width_mm": width_mm,
        "measurement_confidence": _clean_string(
            dimensions.get("confidence"), limit=20
        ),
        "measurement_method": method,
        "measurement_assumption": measurement_assumption,
        "barcode_symbology": _clean_string(barcode.get("symbology"), limit=50),
        "barcode_confidence": _confidence(barcode.get("confidence")),
        "detection_confidence": _confidence(
            item.get("confidence") if item.get("confidence") is not None
            else item.get("mask_score")
        ),
        "review_reasons": list(dict.fromkeys(review_reasons)),
        "warnings": warnings,
        "needs_review": needs_review,
    }


def map_find_result(
    result: dict[str, Any], *, crop_urls: list[str | None] | None = None,
    source_frame_url: str | None = None,
) -> dict[str, Any]:
    mapped: list[dict[str, Any]] = []
    raw_items = result.get("items")
    if not isinstance(raw_items, list):
        raw_items = []

    scale = result.get("scale")
    measurement_assumption = (
        _clean_string(scale.get("assumption"), limit=500)
        if isinstance(scale, dict)
        else None
    )

    for index, raw_item in enumerate(raw_items):
        if not isinstance(raw_item, dict) or raw_item.get("reference"):
            continue
        identity = raw_item.get("identity")
        if not isinstance(identity, dict):
            identity = {}

        name = _clean_string(identity.get("name"), limit=200)
        if not name:
            name = "Unidentified item"

        barcode = raw_item.get("barcode")
        barcode_value = (
            _clean_string(barcode.get("value"), limit=100)
            if isinstance(barcode, dict)
            else None
        )
        confidence_value = _confidence(identity.get("confidence"))

        mapped.append(
            {
                "name": name,
                "category": _category(identity.get("category")),
                "subcategory": None,
                "quantity": 1,
                "brand": _clean_string(identity.get("vendor"), limit=100),
                "part_number": _clean_string(identity.get("sku"), limit=100),
                "barcode": barcode_value,
                "tags": None,
                "confidence": confidence_value,
                "image_url": (crop_urls[index] if crop_urls else None) or source_frame_url,
                "source_frame_url": source_frame_url,
                "notes": _notes(raw_item, identity),
                "location": None,
                "scan_evidence": _scan_evidence(
                    raw_item,
                    identity,
                    measurement_assumption=measurement_assumption,
                ),
            }
        )

    counts = Counter(item["category"] for item in mapped)
    return {
        "items": mapped,
        "summary": {
            "total_detected": len(mapped),
            "categories": dict(counts),
            "identified_count": result.get("identified_count"),
            "unknown_count": result.get("unknown_count"),
            "measured_count": result.get("measured_count"),
            "ocr_text_count": result.get("ocr_text_count"),
            "partial": bool(result.get("partial")),
        },
    }


def _crop_from_box(image_bytes: bytes, item: dict[str, Any]) -> bytes | None:
    box = next((item.get(key) for key in ("bbox", "mask_bbox", "bounding_box", "box")
                if item.get(key) is not None), None)
    if box is None and isinstance(item.get("mask"), dict):
        box = item["mask"].get("bbox")
    if box is None:
        return None
    try:
        with Image.open(io.BytesIO(image_bytes)) as image:
            width, height = image.size
            if isinstance(box, dict):
                x1 = float(box.get("x_min", box.get("x1", box.get("x", 0))))
                y1 = float(box.get("y_min", box.get("y1", box.get("y", 0))))
                x2 = float(box.get("x_max", box.get("x2", x1 + float(box.get("width", 0)))))
                y2 = float(box.get("y_max", box.get("y2", y1 + float(box.get("height", 0)))))
            elif isinstance(box, (list, tuple)) and len(box) == 4:
                x1, y1, x2, y2 = (float(value) for value in box)
            else:
                return None
            if max(abs(x1), abs(y1), abs(x2), abs(y2)) <= 1:
                x1, x2 = x1 * width, x2 * width
                y1, y2 = y1 * height, y2 * height
            bounds = (max(0, int(x1)), max(0, int(y1)),
                      min(width, int(x2)), min(height, int(y2)))
            if bounds[2] <= bounds[0] or bounds[3] <= bounds[1]:
                return None
            output = io.BytesIO()
            image.crop(bounds).convert("RGB").save(output, format="JPEG", quality=88)
            return output.getvalue()
    except (OSError, TypeError, ValueError):
        return None


class FindPipelineClient:
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        request_timeout_seconds: float = 30.0,
        job_timeout_seconds: float = 90.0,
        poll_interval_seconds: float = 0.75,
        allow_insecure_http: bool = False,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.base_url = _validated_base_url(
            base_url, allow_insecure_http=allow_insecure_http
        )
        self.api_key = api_key.strip()
        if not self.api_key:
            raise FindPipelineError("Photo analysis is not configured.")
        self.request_timeout_seconds = request_timeout_seconds
        self.job_timeout_seconds = job_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self._client = client

    @property
    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.api_key}"}

    async def _request(
        self,
        client: httpx.AsyncClient,
        method: str,
        path: str,
        **kwargs: Any,
    ) -> httpx.Response:
        try:
            response = await client.request(
                method,
                f"{self.base_url}{path}",
                headers=self._headers,
                **kwargs,
            )
        except httpx.TimeoutException as exc:
            raise FindPipelineError(
                "Photo analysis timed out. Please try again.", status_code=504
            ) from exc
        except httpx.HTTPError as exc:
            raise FindPipelineError(
                "Photo analysis is temporarily unavailable. Please try again."
            ) from exc

        if response.is_success:
            return response
        if response.status_code == 400:
            raise FindPipelineError(
                "That image could not be analyzed. Try a clear JPEG or PNG.",
                status_code=422,
            )
        if response.status_code == 401:
            raise FindPipelineError("Photo analysis is temporarily unavailable.")
        if response.status_code == 429:
            raise FindPipelineError(
                "Photo analysis is busy. Please try again shortly.", status_code=503
            )
        if response.status_code == 503:
            raise FindPipelineError(
                "Photo analysis is starting up. Please try again in a minute."
            )
        if response.status_code == 409:
            raise FindPipelineError(
                "Photo analysis is busy. Please try again shortly."
            )
        raise FindPipelineError(
            "Photo analysis is temporarily unavailable. Please try again."
        )

    async def extract(
        self,
        *,
        filename: str,
        image_bytes: bytes,
        content_type: str = "image/jpeg",
        space: str | None = None,
        user_id: str | None = None,
        source_frame_url: str | None = None,
    ) -> dict[str, Any]:
        owns_client = self._client is None
        client = self._client or httpx.AsyncClient(
            timeout=httpx.Timeout(self.request_timeout_seconds)
        )
        job_id: str | None = None
        try:
            upload = await self._request(
                client,
                "POST",
                "/v1/jobs",
                files={"image": (filename, image_bytes, content_type)},
                data={"space": space} if space else None,
            )
            created = upload.json()
            job_id = created.get("job_id") if isinstance(created, dict) else None
            if not isinstance(job_id, str) or not job_id:
                raise FindPipelineError("Photo analysis returned an invalid job.")

            await self._request(
                client,
                "POST",
                f"/v1/jobs/{job_id}/run",
                json={
                    "params": {
                        "segment": {
                            "background": "depth",
                            "vlm_proposals": "qwen3vl",
                        },
                        "identify": {},
                        "measure": {"enabled": True, "drop_references": True},
                    },
                    "stop_after": None,
                },
            )

            deadline = time.monotonic() + self.job_timeout_seconds
            while True:
                status_response = await self._request(
                    client, "GET", f"/v1/jobs/{job_id}"
                )
                status = status_response.json()
                if not isinstance(status, dict):
                    raise FindPipelineError("Photo analysis returned an invalid status.")
                if status.get("state") == "FAILED":
                    raise FindPipelineError(
                        "The image could not be segmented. Try a clearer photo.",
                        status_code=422,
                    )
                if status.get("done"):
                    break
                if time.monotonic() >= deadline:
                    raise FindPipelineError(
                        "Photo analysis timed out. Please try again.",
                        status_code=504,
                    )
                await asyncio.sleep(self.poll_interval_seconds)

            result_response = await self._request(
                client, "GET", f"/v1/jobs/{job_id}/result"
            )
            result = result_response.json()
            if not isinstance(result, dict):
                raise FindPipelineError("Photo analysis returned an invalid result.")
            crop_urls: list[str | None] = []
            if user_id:
                for index, raw_item in enumerate(result.get("items") or []):
                    if not isinstance(raw_item, dict) or raw_item.get("reference"):
                        crop_urls.append(None)
                        continue
                    crop = raw_item.get("crop")
                    crop_path = (crop.get("url") or crop.get("path")) if isinstance(crop, dict) else None
                    crop_path = raw_item.get("crop_url") or raw_item.get("crop_path") or crop_path
                    crop_bytes: bytes | None = None
                    if isinstance(crop_path, str):
                        parsed = urlparse(crop_path)
                        base = urlparse(self.base_url)
                        path = parsed.path if parsed.scheme else crop_path
                        if (not parsed.scheme or (parsed.scheme, parsed.netloc) == (base.scheme, base.netloc)) and path.startswith(f"/v1/jobs/{job_id}/"):
                            crop_response = await self._request(client, "GET", path)
                            crop_bytes = crop_response.content
                    if not crop_bytes:
                        crop_bytes = _crop_from_box(image_bytes, raw_item)
                    if not crop_bytes:
                        crop_urls.append(None)
                        continue
                    stored = await asyncio.to_thread(
                        upload_image, user_id=user_id,
                        filename=f"capture-{job_id}-{index}-{uuid4().hex}.jpg",
                        content=crop_bytes,
                    )
                    crop_urls.append(stored.url)
            return map_find_result(
                result, crop_urls=crop_urls or None,
                source_frame_url=source_frame_url,
            )
        except (json.JSONDecodeError, ValueError) as exc:
            raise FindPipelineError(
                "Photo analysis returned an invalid response. Please try again."
            ) from exc
        finally:
            if job_id:
                try:
                    await client.delete(
                        f"{self.base_url}/v1/jobs/{job_id}",
                        headers=self._headers,
                    )
                except httpx.HTTPError:
                    logger.warning("FIND job cleanup failed for job_id=%s", job_id)
            if owns_client:
                await client.aclose()


async def extract_inventory_items_with_find(
    *, filename: str, image_bytes: bytes, content_type: str = "image/jpeg",
    user_id: str | None = None, source_frame_url: str | None = None,
) -> dict[str, Any]:
    settings = get_settings()
    if settings.find_api_base_url is None or not settings.find_api_key:
        raise FindPipelineError("Photo analysis is not configured.")
    client = FindPipelineClient(
        base_url=str(settings.find_api_base_url),
        api_key=settings.find_api_key,
        request_timeout_seconds=settings.find_api_request_timeout_seconds,
        job_timeout_seconds=settings.find_api_job_timeout_seconds,
        poll_interval_seconds=settings.find_api_poll_interval_seconds,
        allow_insecure_http=settings.find_api_allow_insecure_http,
    )
    return await client.extract(
        filename=filename,
        image_bytes=image_bytes,
        content_type=content_type,
        user_id=user_id,
        source_frame_url=source_frame_url,
    )
