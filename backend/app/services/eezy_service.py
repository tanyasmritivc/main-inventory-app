import uuid

import httpx

from app.core.config import get_settings


EEZY_SYSTEM_PROMPT = """You are EEZY, the AI assistant for FindEZ AI.
You help users track, find, and manage their inventory.
You specialize in robotics parts, tools, and equipment.
Always be concise, helpful, and specific."""


async def ask_eezy(message: str, context: str = "") -> str:
    settings = get_settings()
    api_key = settings.findez_agent_key
    if not api_key:
        raise RuntimeError("FINDEZ_AGENT_KEY is not configured")

    messages = [{"role": "system", "content": EEZY_SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "system", "content": f"Inventory context:\n{context}"})
    messages.append({"role": "user", "content": message})

    session_id = f"ses_{uuid.uuid4().hex}"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "X-Agent-Conversation-ID": session_id,
        "X-Agent-Timezone": settings.findez_agent_timezone,
    }
    payload = {
        "model": settings.findez_agent_model,
        "max_tokens": 500,
        "messages": messages,
        "stream": False,
    }
    timeout = httpx.Timeout(connect=15.0, read=180.0, write=30.0, pool=15.0)

    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            str(settings.findez_agent_base_url).rstrip("/") + "/chat/completions",
            headers=headers,
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"].get("content") or ""
