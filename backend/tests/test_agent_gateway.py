import asyncio
from types import SimpleNamespace
from unittest.mock import Mock, patch

from app.services import ai_agent
from app.services.agent_gateway_client import AgentGatewayClient
from app.services.ai_memory import extract_and_save_memory


def _settings(**overrides):
    values = {
        "findez_agent_key": "gateway-test-key",
        "findez_agent_base_url": "https://agent.ftctools.com/v1",
        "findez_agent_model": "deepseek-v4-flash-agent",
        "findez_agent_timezone": "America/Los_Angeles",
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def test_gateway_client_posts_directly_to_configured_endpoint():
    response = Mock()
    response.json.return_value = {
        "choices": [{"message": {"content": "Ready", "tool_calls": []}}]
    }
    http = Mock()
    http.post.return_value = response

    with patch(
        "app.services.agent_gateway_client.get_settings", return_value=_settings()
    ), patch("app.services.agent_gateway_client.httpx.Client", return_value=http):
        client = AgentGatewayClient()
        result = client.chat.completions.create(
            model="deepseek-v4-flash-agent",
            messages=[{"role": "user", "content": "Hello"}],
            stream=True,
            extra_headers={"X-Agent-Conversation-ID": "conversation-123"},
        )

    response.raise_for_status.assert_called_once_with()
    request = http.post.call_args
    assert request.args[0] == "https://agent.ftctools.com/v1/chat/completions"
    assert request.kwargs["headers"]["Authorization"] == "Bearer gateway-test-key"
    assert request.kwargs["headers"]["X-Agent-Conversation-ID"] == "conversation-123"
    assert request.kwargs["json"]["stream"] is False
    assert result.choices[0].message.content == "Ready"


def test_gateway_provider_uses_dedicated_key_endpoint_and_conversation_headers():
    client = Mock()
    with patch.object(ai_agent, "get_settings", return_value=_settings()), patch.object(
        ai_agent, "AgentGatewayClient", return_value=client
    ) as gateway:
        provider = ai_agent._get_chat_provider("conversation-123")

    gateway.assert_called_once_with()
    assert provider.client is client
    assert provider.model == "deepseek-v4-flash-agent"

    kwargs = ai_agent._completion_kwargs(
        provider,
        messages=[{"role": "user", "content": "Where are the M4 screws?"}],
        stream=False,
        allow_tools=True,
    )
    assert kwargs["max_tokens"] == 500
    assert "max_completion_tokens" not in kwargs
    assert kwargs["parallel_tool_calls"] is False
    assert kwargs["extra_headers"] == {
        "X-Agent-Conversation-ID": "conversation-123",
        "X-Agent-Timezone": "America/Los_Angeles",
    }


def test_gateway_tool_loop_is_sequential_and_returns_tool_result_to_model():
    tool_call = SimpleNamespace(
        id="tool-call-1",
        function=SimpleNamespace(name="inventory_search", arguments='{"query":"M4"}'),
    )
    first = SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content="", tool_calls=[tool_call]))]
    )
    second = SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content="M4 screws are in Cabinet.", tool_calls=[]))]
    )
    create = Mock(side_effect=[first, second])
    provider = ai_agent._ChatProvider(
        client=SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create))),
        model="deepseek-v4-flash-agent",
        conversation_id="conversation-123",
        timezone="America/Los_Angeles",
    )
    state = ai_agent._SessionState()

    with patch.object(ai_agent, "_get_chat_provider", return_value=provider), patch.object(
        ai_agent, "_load_context", return_value={}
    ), patch.object(ai_agent, "_get_state", return_value=state), patch.object(
        ai_agent, "_requires_inventory_knowledge", return_value=False
    ), patch.object(ai_agent, "_should_enable_tools", return_value=True), patch.object(
        ai_agent, "_execute_tool_call", return_value={"items": [{"name": "M4 screw"}]}
    ) as execute, patch.object(ai_agent, "_persist_state"), patch.object(
        ai_agent, "_update_memory_from_trace"
    ):
        events = list(ai_agent._iter_agent_streaming(
            user_id="user-1",
            message="Where are the M4 screws?",
            first_name="Tanya",
            conversation_id="conversation-123",
        ))

    execute.assert_called_once_with(
        user_id="user-1",
        tool_name="inventory_search",
        args={"query": "M4"},
    )
    assert create.call_count == 2
    assert create.call_args_list[0].kwargs["stream"] is False
    assert create.call_args_list[0].kwargs["parallel_tool_calls"] is False
    returned_messages = create.call_args_list[1].kwargs["messages"]
    assert returned_messages[-2]["tool_calls"][0]["id"] == "tool-call-1"
    assert returned_messages[-1]["tool_call_id"] == "tool-call-1"
    assert events[0] == {"type": "delta", "delta": "M4 screws are in Cabinet."}
    assert events[-1]["type"] == "done"
    assert events[-1]["assistant_message"] == "M4 screws are in Cabinet."


def test_memory_extraction_uses_gateway_when_configured():
    completion = SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content="{}"))]
    )
    create = Mock(return_value=completion)
    client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(create=create)))

    with patch("app.core.config.get_settings", return_value=_settings()), patch(
        "app.services.agent_gateway_client.AgentGatewayClient", return_value=client
    ) as gateway:
        asyncio.run(extract_and_save_memory("user-1", "Where are the M4 screws?", "In Cabinet."))

    gateway.assert_called_once_with()
    kwargs = create.call_args.kwargs
    assert kwargs["model"] == "deepseek-v4-flash-agent"
    assert kwargs["max_tokens"] == 200
    assert "max_completion_tokens" not in kwargs
    assert kwargs["extra_headers"]["X-Agent-Timezone"] == "America/Los_Angeles"
