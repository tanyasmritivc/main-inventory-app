from __future__ import annotations

import base64
import json

from openai import OpenAI

from app.core.config import get_settings


def _client() -> OpenAI:
    settings = get_settings()
    return OpenAI(api_key=settings.openai_api_key)


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
                        "image_url": {"url": f"data:image/png;base64,{b64}"},
                    },
                ],
            },
        ],
        tools=tools,
        tool_choice={"type": "function", "function": {"name": "extract_inventory_fields"}},
        temperature=0.2,
    )

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

    resp = client.chat.completions.create(
        model=settings.openai_vision_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You extract multiple inventory items from an image. "
                    "Return only items you can see with reasonable confidence. "
                    "If uncertain about quantity, use 1. Keep names short. "
                    "If you can infer a storage folder/location (e.g., Kitchen, Garage, Office, Closet), set location; otherwise null."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "Detect and extract inventory items from this image."},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                ],
            },
        ],
        tools=tools,
        tool_choice={"type": "function", "function": {"name": "extract_inventory_items"}},
        temperature=0.2,
    )

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

    resp = client.chat.completions.create(
        model=settings.openai_model,
        messages=[
            {"role": "system", "content": "Return compact search text and optional category/location filters."},
            {"role": "user", "content": query},
        ],
        tools=tools,
        tool_choice={"type": "function", "function": {"name": "parse_inventory_search"}},
        temperature=0.1,
    )

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
        temperature=0.2,
    )

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
        temperature=0.2,
    )

    text = (resp.choices[0].message.content or "").strip()
    return text or f"{action}"
