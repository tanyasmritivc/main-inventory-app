import json
import os
import uuid

import httpx


EEZY_CHAT_URL = (
    "https://agent-gateway.openstack.ftctools.com/codingagent/v1/chat/completions"
)
EEZY_MODEL = "deepseek-v4-flash-coding"

EEZY_SYSTEM_PROMPT = """You are EEZY, the AI assistant for FindEZ AI.
You help users track, find, and manage their inventory.
You specialize in robotics parts, tools, and equipment.
Always be concise, helpful, and specific."""


async def ask_eezy(message: str, context: str = "") -> str:
    api_key = os.environ.get("EEZY_API_KEY")
    if not api_key:
        raise RuntimeError("EEZY_API_KEY is not configured")

    messages = [{"role": "system", "content": EEZY_SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "system", "content": f"Inventory context:\n{context}"})
    messages.append({"role": "user", "content": message})

    session_id = f"ses_{uuid.uuid4().hex}"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "*/*",
        "User-Agent": "opencode/1.18.16 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14",
        "x-session-affinity": session_id,
        "x-session-id": session_id,
    }
    payload = {
        "model": EEZY_MODEL,
        "max_tokens": 32000,
        "messages": messages,
        "tools": [],
        "tool_choice": "auto",
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    timeout = httpx.Timeout(connect=15.0, read=180.0, write=30.0, pool=15.0)

    content_parts: list[str] = []
    async with httpx.AsyncClient(timeout=timeout) as client:
        async with client.stream(
            "POST",
            EEZY_CHAT_URL,
            headers=headers,
            json=payload,
        ) as response:
            response.raise_for_status()
            async for line in response.aiter_lines():
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if not data or data == "[DONE]":
                    continue
                chunk = json.loads(data)
                for choice in chunk.get("choices", []):
                    delta = choice.get("delta", {})
                    content = delta.get("content")
                    if isinstance(content, str):
                        content_parts.append(content)

    return "".join(content_parts)
