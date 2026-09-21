"""FindEZ AI helpers backed only by FIND and the FTCTools agent gateway."""

from __future__ import annotations

import asyncio
import io
import json
import logging
from collections.abc import Iterator
from uuid import uuid4

from PIL import Image

from app.services.agent_gateway_client import gateway_completion
from app.services.document_text_extractor import extract_text_from_upload
from app.services.find_pipeline import FindPipelineError, extract_inventory_items_with_find


logger = logging.getLogger(__name__)


def _evt(payload: dict) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


def _gateway_messages(messages: list[dict], *, max_tokens: int = 500, **kwargs):
    return gateway_completion(
        messages=messages,
        conversation_id=f"service-{uuid4()}",
        max_tokens=max_tokens,
        **kwargs,
    )


def _message_text(response) -> str:
    return (response.choices[0].message.content or "").strip()


def _tool_arguments(response) -> dict:
    calls = getattr(response.choices[0].message, "tool_calls", None) or []
    if not calls:
        return {}
    try:
        value = json.loads(calls[0].function.arguments or "{}")
    except (TypeError, ValueError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def _format_find_analysis(data: dict) -> str:
    items = data.get("items") or []
    if not items:
        return (
            "I could not identify an inventory item in this image.\n\n"
            "Would you like to try a clearer photo?"
        )
    lines = ["I found these items in the image:"]
    for item in items[:20]:
        name = str(item.get("name") or "Unidentified item").strip()
        quantity = item.get("quantity") or 1
        lines.append(f"• {name} x{quantity}")
    lines.extend(["", "Would you like me to add these to your inventory?"])
    return "\n".join(lines)


def _jpeg_for_find(content: bytes, filename: str) -> tuple[bytes, str]:
    try:
        image = Image.open(io.BytesIO(content))
        output = io.BytesIO()
        image.convert("RGB").save(output, format="JPEG", quality=85)
        return output.getvalue(), "converted.jpg"
    except Exception:
        return content, filename


def iter_assist_file_analysis_sse(
    *, filename: str, mime_type: str | None, content: bytes
) -> Iterator[str]:
    name = (filename or "").strip() or "upload"
    mt = (mime_type or "").strip().lower() or None
    is_image = bool(mt and mt.startswith("image/")) or name.lower().endswith(
        (".png", ".jpg", ".jpeg", ".webp", ".heic")
    )

    yield _evt({"type": "status", "message": "Analyzing file..."})

    if is_image:
        try:
            analysis_bytes, analysis_name = _jpeg_for_find(content, name)
            data = asyncio.run(
                extract_inventory_items_with_find(
                    filename=analysis_name,
                    image_bytes=analysis_bytes,
                    content_type="image/jpeg",
                )
            )
            assistant = _format_find_analysis(data)
        except FindPipelineError as exc:
            logger.warning("FIND upload analysis failed: %s", exc.public_message)
            assistant = exc.public_message
        except Exception:
            logger.exception("FIND upload analysis failed")
            assistant = "Photo analysis is temporarily unavailable. Please try again."
        yield _evt({"type": "delta", "delta": assistant})
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
        yield "event: done\n"
        yield "data: {}\n\n"
        return

    try:
        text, _truncated = extract_text_from_upload(
            filename=name, mime_type=mt, content=content
        )
    except Exception:
        logger.exception("Text extraction failed")
        text = ""

    clipped = (text or "").strip()[:12000]
    if not clipped:
        assistant = (
            "I could not extract readable text from this file. Try a text based PDF "
            "or a clearer scan."
        )
    else:
        try:
            response = _gateway_messages(
                [
                    {
                        "role": "system",
                        "content": (
                            "Summarize the supplied document accurately in 3 to 7 concise "
                            "bullets. Include visible dates, model numbers, amounts, and "
                            "identifiers. End with one useful follow-up question."
                        ),
                    },
                    {"role": "user", "content": f"Filename: {name}\n\n{clipped}"},
                ],
                max_tokens=450,
            )
            assistant = _message_text(response)
        except Exception:
            logger.exception("Gateway document summary failed")
            assistant = "Document analysis is temporarily unavailable. Please try again."

    yield _evt({"type": "delta", "delta": assistant})
    yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
    yield "event: done\n"
    yield "data: {}\n\n"


def parse_search_query_to_keywords(*, query: str) -> dict:
    if not (query or "").strip():
        return {"text": "", "category": None, "location": None}
    tool = {
        "type": "function",
        "function": {
            "name": "parse_inventory_search",
            "description": "Parse inventory search text and optional filters.",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "category": {"type": ["string", "null"]},
                    "location": {"type": ["string", "null"]},
                },
                "required": ["text"],
                "additionalProperties": False,
            },
        },
    }
    response = _gateway_messages(
        [
            {"role": "system", "content": "Convert the request into compact inventory search keywords."},
            {"role": "user", "content": query},
        ],
        tools=[tool],
        tool_choice={"type": "function", "function": {"name": "parse_inventory_search"}},
        parallel_tool_calls=False,
    )
    return _tool_arguments(response) or {"text": query, "category": None, "location": None}


def interpret_barcode(*, barcode: str) -> dict:
    tool = {
        "type": "function",
        "function": {
            "name": "barcode_to_item_guess",
            "description": "Return a cautious product guess from a barcode string.",
            "parameters": {
                "type": "object",
                "properties": {
                    "barcode": {"type": "string"},
                    "name": {"type": ["string", "null"]},
                    "category": {"type": ["string", "null"]},
                    "notes": {"type": ["string", "null"]},
                },
                "required": ["barcode"],
                "additionalProperties": False,
            },
        },
    }
    response = _gateway_messages(
        [
            {
                "role": "system",
                "content": (
                    "You do not have an online UPC database. Return null identity fields "
                    "when the barcode alone does not support a reliable product name."
                ),
            },
            {"role": "user", "content": f"Barcode: {barcode}"},
        ],
        tools=[tool],
        tool_choice={"type": "function", "function": {"name": "barcode_to_item_guess"}},
        parallel_tool_calls=False,
    )
    return _tool_arguments(response) or {
        "barcode": barcode,
        "name": None,
        "category": None,
        "notes": "No match",
    }


def summarize_activity(*, action: str, details: dict) -> str:
    response = _gateway_messages(
        [
            {"role": "system", "content": "Write one short factual activity log line."},
            {"role": "user", "content": json.dumps({"action": action, "details": details})},
        ],
        max_tokens=80,
    )
    return _message_text(response) or action
