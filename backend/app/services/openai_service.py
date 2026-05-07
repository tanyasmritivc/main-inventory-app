from __future__ import annotations

import base64
import json
import logging
from collections.abc import Iterator

from openai import OpenAI

from app.core.config import get_settings
from app.services.document_text_extractor import extract_text_from_upload


logger = logging.getLogger(__name__)


def _client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


def _evt(payload: dict) -> str:
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


def _chat_stream(client: OpenAI, **kwargs):
    try:
        return client.chat.completions.create(
            **kwargs,
            reasoning_effort="low",
            max_output_tokens=450,
        )
    except TypeError:
        try:
            return client.chat.completions.create(
                **kwargs,
                reasoning_effort="low",
                max_completion_tokens=450,
            )
        except TypeError:
            return client.chat.completions.create(
                **kwargs,
                max_completion_tokens=450,
            )


def iter_assist_file_analysis_sse(*, filename: str, mime_type: str | None, content: bytes) -> Iterator[str]:
    settings = get_settings()
    client = _client()

    name = (filename or "").strip() or "upload"
    mt = (mime_type or "").strip().lower() or None

    yield _evt({"type": "status", "message": "Analyzing file..."})

    is_image = bool(mt and mt.startswith("image/")) or name.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
    if is_image:
        b64 = base64.b64encode(content).decode("utf-8")
        messages = [
            {
                "role": "system",
                "content": (
                    "You are FindEZ Assistant — a smart, ChatGPT-like helper that manages the user's belongings. "
                    "The user uploaded an image. Analyze it visually. "
                    "Be concise and natural. "
                    "When you list items or observations, ALWAYS use bullet points with the '•' character, one per line. "
                    "If you recognize multiple items, start with: 'I found these items in the image:' then bullets. "
                    "If you are unsure, say so briefly. "
                    "Always end with ONE helpful follow-up suggestion, e.g. 'Would you like me to add these to your inventory?'."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": f"Analyze this image: {name}."},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                ],
            },
        ]

        assistant = ""
        try:
            stream = _chat_stream(
                client,
                model=settings.openai_vision_model,
                messages=messages,
                stream=True,
            )
            for chunk in stream:
                try:
                    choice = chunk.choices[0]
                except Exception:
                    continue
                delta = getattr(choice, "delta", None) or getattr(choice, "message", None)
                if delta is None:
                    continue
                content_part = getattr(delta, "content", None)
                if not content_part:
                    continue
                assistant += content_part
                yield _evt({"type": "delta", "delta": content_part})
        except Exception:
            logger.exception("OpenAI image analysis stream failed")
            yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
            yield 'event: done\n'
            yield 'data: {}\n\n'
            return

        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
        yield 'event: done\n'
        yield 'data: {}\n\n'
        return

    text = ""
    try:
        text, _truncated = extract_text_from_upload(filename=name, mime_type=mt, content=content)
    except Exception:
        logger.exception("Text extraction failed")
        text = ""

    clipped = (text or "").strip()[:12000]
    if not clipped:
        def _sniff_image_mime(b: bytes) -> str | None:
            if not b:
                return None
            if b.startswith(b"\x89PNG\r\n\x1a\n"):
                return "image/png"
            if b.startswith(b"\xff\xd8\xff"):
                return "image/jpeg"
            if b[:12].startswith(b"RIFF") and b[8:12] == b"WEBP":
                return "image/webp"
            return None

        sniffed = _sniff_image_mime(content)
        if sniffed:
            b64 = base64.b64encode(content).decode("utf-8")
            messages = [
                {
                    "role": "system",
                    "content": (
                        "You are FindEZ Assistant — a smart, ChatGPT-like helper that manages the user's belongings. "
                        "The user uploaded a document, but we could not extract text reliably. "
                        "Analyze the visible content and summarize it. "
                        "Rules: "
                        "1) Start with exactly: 'Summary of this document:' "
                        "2) Then 3–7 bullets using the '•' character, one per line. "
                        "3) Prefer short phrases, not long paragraphs. "
                        "4) Only include details you can actually see in the image. "
                        "5) End with ONE helpful follow-up question, on its own line, e.g. 'Would you like me to link this document to an item?'."
                    ),
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": f"Summarize this document image: {name}."},
                        {"type": "image_url", "image_url": {"url": f"data:{sniffed};base64,{b64}"}},
                    ],
                },
            ]

            assistant = ""
            try:
                stream = _chat_stream(
                    client,
                    model=settings.openai_vision_model,
                    messages=messages,
                    stream=True,
                )
                for chunk in stream:
                    try:
                        choice = chunk.choices[0]
                    except Exception:
                        continue
                    delta = getattr(choice, "delta", None) or getattr(choice, "message", None)
                    if delta is None:
                        continue
                    content_part = getattr(delta, "content", None)
                    if not content_part:
                        continue
                    assistant += content_part
                    yield _evt({"type": "delta", "delta": content_part})
            except Exception:
                logger.exception("OpenAI document vision fallback stream failed")
                yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
                yield 'event: done\n'
                yield 'data: {}\n\n'
                return

            yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
            yield 'event: done\n'
            yield 'data: {}\n\n'
            return

        assistant = (
            "Summary of this document:\n"
            f"• File name: {name}\n"
            f"• File type: {(mt or 'unknown')}\n"
            "• I couldn't extract text from this file, so I can’t summarize its contents yet.\n"
            "• If it’s a scanned document, upload a clear photo or screenshot of the page(s) for a better summary.\n"
            "• If it’s a PDF, try exporting a text-based version if possible.\n"
            "\n"
            "Would you like me to link this document to an item?"
        )
        yield _evt({"type": "delta", "delta": assistant})
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
        yield 'event: done\n'
        yield 'data: {}\n\n'
        return

    messages = [
        {
            "role": "system",
            "content": (
                "You are FindEZ Assistant — a smart, ChatGPT-like helper that manages the user's belongings. "
                "The user uploaded a document or file. "
                "Write a clear, concise summary using bullet points. "
                "Rules: "
                "1) Start with exactly: 'Summary of this document:' "
                "2) Then 3–7 bullets using the '•' character, one per line. "
                "3) Prefer short phrases, not long paragraphs. "
                "4) If present, include key details like warranty/validity dates, model/serial numbers, product names, amounts, or important identifiers. "
                "5) End with ONE helpful follow-up question, on its own line, e.g. 'Would you like me to link this document to an item?'."
            ),
        },
        {
            "role": "user",
            "content": f"Filename: {name}\n\nCONTENT:\n{clipped}",
        },
    ]

    assistant = ""
    try:
        stream = _chat_stream(
            client,
            model=settings.openai_model,
            messages=messages,
            stream=True,
        )
        for chunk in stream:
            try:
                choice = chunk.choices[0]
            except Exception:
                continue
            delta = getattr(choice, "delta", None) or getattr(choice, "message", None)
            if delta is None:
                continue
            content_part = getattr(delta, "content", None)
            if not content_part:
                continue
            assistant += content_part
            yield _evt({"type": "delta", "delta": content_part})
    except Exception:
        logger.exception("OpenAI document summary stream failed")
        yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": ""})
        yield 'event: done\n'
        yield 'data: {}\n\n'
        return

    yield _evt({"type": "done", "tool": None, "result": None, "assistant_message": assistant})
    yield 'event: done\n'
    yield 'data: {}\n\n'


def extract_item_from_image(*, filename: str, image_bytes: bytes) -> dict:
    settings = get_settings()
    client = _client()

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    schema = {
        "type": "object",
        "properties": {
            "name": {"type": "string"},
            "category": {"type": "string"},
            "quantity": {"type": "integer"},
            "location": {"type": "string"},
            "barcode": {"type": ["string", "null"]},
            "purchase_source": {"type": ["string", "null"]},
            "notes": {"type": ["string", "null"]},
        },
        "required": ["name", "category", "quantity", "location"],
        "additionalProperties": False,
    }

    tools = [
        {
            "type": "function",
            "function": {
                "name": "extract_inventory_fields",
                "description": "Extract structured inventory fields from an image of an item, receipt, or barcode label.",
                "parameters": schema,
            },
        }
    ]

    try:
        resp = client.chat.completions.create(
            model=settings.openai_vision_model,
            messages=[
                {
                    "role": "system",
                    "content": "You extract inventory fields. If uncertain, make best effort and keep strings short.",
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Extract inventory fields from this image."},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/png;base64,{b64}", "detail": "high"},
                        },
                    ],
                },
            ],
            tools=tools,
            tool_choice={"type": "function", "function": {"name": "extract_inventory_fields"}},
            max_tokens=4000,
            temperature=0.1,
        )
    except Exception:
        logger.exception("OpenAI vision extraction failed")
        raise

    tool_calls = resp.choices[0].message.tool_calls or []
    if not tool_calls:
        return {}

    args = tool_calls[0].function.arguments
    try:
        return json.loads(args)
    except Exception:
        return {}


def extract_items_from_image_multi(*, filename: str, image_bytes: bytes) -> dict:
    settings = get_settings()
    client = _client()

    b64 = base64.b64encode(image_bytes).decode("utf-8")

    schema = {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "category": {"type": "string"},
                        "subcategory": {"type": ["string", "null"]},
                        "quantity": {"type": "integer"},
                        "location": {"type": ["string", "null"]},
                        "brand": {"type": ["string", "null"]},
                        "part_number": {"type": ["string", "null"]},
                        "barcode": {"type": ["string", "null"]},
                        "tags": {"type": ["array", "null"], "items": {"type": "string"}},
                        "confidence": {"type": ["number", "null"]},
                        "notes": {"type": ["string", "null"]},
                    },
                    "required": ["name", "category", "quantity"],
                    "additionalProperties": False,
                },
            },
            "summary": {
                "type": "object",
                "properties": {
                    "total_detected": {"type": "integer"},
                    "categories": {"type": "object"},
                },
                "required": ["total_detected", "categories"],
                "additionalProperties": False,
            },
        },
        "required": ["items", "summary"],
        "additionalProperties": False,
    }

    tools = [
        {
            "type": "function",
            "function": {
                "name": "extract_inventory_items",
                "description": "Detect multiple inventory items in an image and return structured fields for each detected item.",
                "parameters": schema,
            },
        }
    ]

    try:
        resp = client.chat.completions.create(
            model=settings.openai_vision_model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an expert inventory scanner with the precision of a professional home organizer and the knowledge of a product database. "
                        "Your job is to identify and extract EVERY single item visible in an image — nothing is too small or too obvious to include.\n\n"
                        "RULES:\n"
                        "- Identify ALL items in the image, even partially visible ones\n"
                        "- Never skip background items, items on shelves, items behind other items, or items that seem minor\n"
                        "- For each item, extract: exact product name, brand (if visible), quantity (count carefully), category, and any text visible on packaging\n"
                        "- If you see a box or container, identify what it is AND what it likely contains if labeled\n"
                        "- For food items: include flavor, size, variant (e.g. 'Lay\'s Classic Chips 8oz' not just 'chips')\n"
                        "- For electronics: include model number or generation if visible\n"
                        "- For cleaning/household products: include the full product name and size\n"
                        "- For books: include full title and author if visible\n"
                        "- If quantity is ambiguous, err on the side of counting more carefully — look for multiples\n"
                        "- Never group items together — each distinct product is its own entry\n"
                        "- Confidence score: only mark as low confidence if the item is truly unidentifiable"
                    ),
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Scan this image with maximum thoroughness. Extract EVERY item you can see. Be exhaustive — I would rather have too many items than miss any. For each item provide: name (specific, not generic), brand, quantity, category (one of: Food, Electronics, Clothing, Health, Home, Office, Supplies, Toys, Cosmetics, Other), and confidence (0.0-1.0). Return as structured JSON array."},
                        {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}", "detail": "high"}},
                    ],
                },
            ],
            tools=tools,
            tool_choice={"type": "function", "function": {"name": "extract_inventory_items"}},
            max_tokens=4000,
            temperature=0.1,
        )
    except Exception:
        logger.exception("OpenAI multi-item vision extraction failed")
        raise

    tool_calls = resp.choices[0].message.tool_calls or []
    if not tool_calls:
        return {"items": [], "summary": {"total_detected": 0, "categories": {}}}

    args = tool_calls[0].function.arguments
    try:
        data = json.loads(args)
        return data if isinstance(data, dict) else {"items": [], "summary": {"total_detected": 0, "categories": {}}}
    except Exception:
        return {"items": [], "summary": {"total_detected": 0, "categories": {}}}


def parse_search_query_to_keywords(*, query: str) -> dict:
    settings = get_settings()
    client = _client()

    tools = [
        {
            "type": "function",
            "function": {
                "name": "parse_inventory_search",
                "description": "Parse a natural language inventory search into lightweight keywords and optional filters.",
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
    ]

    try:
        resp = client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {
                    "role": "system",
                    "content": "You convert a natural language inventory intent into a compact search query. Return a short keyword-style search text plus optional category/location filters when clearly implied. Prefer action-oriented keywords (e.g., 'woodworking clamps', 'restock batteries', 'garage hand tools') over repeating the user's full sentence.",
                },
                {"role": "user", "content": query},
            ],
            tools=tools,
            tool_choice={"type": "function", "function": {"name": "parse_inventory_search"}},
        )
    except Exception:
        logger.exception("OpenAI search intent parsing failed")
        raise

    tool_calls = resp.choices[0].message.tool_calls or []
    if not tool_calls:
        return {"text": query, "category": None, "location": None}

    try:
        return json.loads(tool_calls[0].function.arguments)
    except Exception:
        return {"text": query, "category": None, "location": None}


def interpret_barcode(*, barcode: str) -> dict:
    settings = get_settings()
    client = _client()

    tools = [
        {
            "type": "function",
            "function": {
                "name": "barcode_to_item_guess",
                "description": "Given a barcode string, guess a likely product name/category or return unknown.",
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
    ]

    try:
        resp = client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {
                    "role": "system",
                    "content": "You do not have access to online UPC databases. If you cannot infer, return null name/category and a brief note.",
                },
                {"role": "user", "content": f"Barcode: {barcode}"},
            ],
            tools=tools,
            tool_choice={"type": "function", "function": {"name": "barcode_to_item_guess"}},
        )
    except Exception:
        logger.exception("OpenAI barcode interpretation failed")
        raise

    tool_calls = resp.choices[0].message.tool_calls or []
    if not tool_calls:
        return {"barcode": barcode, "name": None, "category": None, "notes": "No match"}

    try:
        return json.loads(tool_calls[0].function.arguments)
    except Exception:
        return {"barcode": barcode, "name": None, "category": None, "notes": "No match"}


def summarize_activity(*, action: str, details: dict) -> str:
    settings = get_settings()
    client = _client()

    try:
        resp = client.chat.completions.create(
            model=settings.openai_model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You write a single short activity log line describing what the user did. "
                        "Be specific, factual, and concise. No extra punctuation beyond normal."
                    ),
                },
                {
                    "role": "user",
                    "content": json.dumps({"action": action, "details": details}),
                },
            ],
        )
    except Exception:
        logger.exception("OpenAI activity summarization failed")
        raise

    text = (resp.choices[0].message.content or "").strip()
    return text or f"{action}"
