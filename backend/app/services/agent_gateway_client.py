"""Small client for the self-hosted FTCTools Agent Gateway.

FindEZ talks to the gateway directly so no external model client, key, model,
or fallback is present in the app.
"""

from __future__ import annotations

from types import SimpleNamespace
from typing import Any

import httpx

from app.core.config import get_settings


def _as_namespace(value: Any) -> Any:
    if isinstance(value, dict):
        return SimpleNamespace(**{key: _as_namespace(item) for key, item in value.items()})
    if isinstance(value, list):
        return [_as_namespace(item) for item in value]
    return value


class _Completions:
    def __init__(self, owner: "AgentGatewayClient") -> None:
        self._owner = owner

    def create(self, **kwargs: Any) -> SimpleNamespace:
        extra_headers = kwargs.pop("extra_headers", None) or {}
        payload = dict(kwargs)
        payload["stream"] = False
        with httpx.Client(timeout=self._owner.timeout) as client:
            response = client.post(
                self._owner.url,
                headers={**self._owner.headers, **extra_headers},
                json=payload,
            )
        response.raise_for_status()
        return _as_namespace(response.json())


class AgentGatewayClient:
    def __init__(self) -> None:
        settings = get_settings()
        self.url = (
            str(settings.findez_agent_base_url).rstrip("/") + "/chat/completions"
        )
        self.headers = {
            "Authorization": f"Bearer {settings.findez_agent_key}",
            "Content-Type": "application/json",
        }
        self.timeout = httpx.Timeout(
            connect=15.0, read=180.0, write=30.0, pool=15.0
        )
        self.chat = SimpleNamespace(completions=_Completions(self))

    def close(self) -> None:
        return None


def gateway_completion(
    *,
    messages: list[dict[str, Any]],
    conversation_id: str,
    max_tokens: int = 500,
    **kwargs: Any,
) -> SimpleNamespace:
    settings = get_settings()
    client = AgentGatewayClient()
    try:
        return client.chat.completions.create(
            model=settings.findez_agent_model,
            messages=messages,
            max_tokens=max_tokens,
            extra_headers={
                "X-Agent-Conversation-ID": conversation_id,
                "X-Agent-Timezone": settings.findez_agent_timezone,
            },
            **kwargs,
        )
    finally:
        client.close()
