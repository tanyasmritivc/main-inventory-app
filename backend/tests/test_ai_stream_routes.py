import asyncio
import io
import json
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import BackgroundTasks, UploadFile
from starlette.datastructures import Headers
from starlette.requests import Request

from app.api.routes.ai import (
    _prepare_conversation,
    ai_command_route,
    ai_upload_route,
)
from app.core.auth import AuthenticatedUser
from app.schemas.ai import AICommandRequest


def _request(accept: str = "text/event-stream") -> Request:
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/ai_command",
            "headers": [(b"accept", accept.encode())],
            "client": ("127.0.0.1", 50000),
        }
    )


async def _body(response) -> str:
    chunks = []
    async for chunk in response.body_iterator:
        chunks.append(chunk.decode() if isinstance(chunk, bytes) else chunk)
    return "".join(chunks)


async def _agent_events(**_kwargs):
    yield {"type": "delta", "delta": "Cabinet A"}
    yield {
        "type": "done",
        "assistant_message": "Cabinet A",
        "nav_hint": {"type": "space", "id": "space-1"},
    }


async def _failing_agent_events(**_kwargs):
    yield {"type": "delta", "delta": "Partial"}
    raise RuntimeError("private gateway detail")


def test_prepare_conversation_reuses_owned_conversation_and_persists_user_message():
    admin = MagicMock()
    conversations = MagicMock()
    messages = MagicMock()
    admin.table.side_effect = lambda name: {
        "conversations": conversations,
        "messages": messages,
    }[name]
    owned = conversations.select.return_value.eq.return_value.eq.return_value
    owned.limit.return_value.execute.return_value.data = [{"id": "conversation-1"}]

    with patch("app.api.routes.ai.get_supabase_admin", return_value=admin):
        conversation_id = _prepare_conversation(
            user_id="user-1",
            requested_id="conversation-1",
            user_message="Which shelf?",
        )

    assert conversation_id == "conversation-1"
    conversations.insert.assert_not_called()
    messages.insert.assert_called_once_with(
        {
            "conversation_id": "conversation-1",
            "role": "user",
            "content": "Which shelf?",
        }
    )


def test_prepare_conversation_replaces_unowned_id_and_returns_created_id():
    admin = MagicMock()
    conversations = MagicMock()
    messages = MagicMock()
    admin.table.side_effect = lambda name: {
        "conversations": conversations,
        "messages": messages,
    }[name]
    owned = conversations.select.return_value.eq.return_value.eq.return_value
    owned.limit.return_value.execute.return_value.data = []
    conversations.insert.return_value.execute.return_value.data = [
        {"id": "conversation-2"}
    ]

    with patch("app.api.routes.ai.get_supabase_admin", return_value=admin):
        conversation_id = _prepare_conversation(
            user_id="user-1",
            requested_id="other-users-conversation",
            user_message="Start over",
        )

    assert conversation_id == "conversation-2"
    conversations.insert.assert_called_once_with(
        {"user_id": "user-1", "title": "Start over"}
    )
    messages.insert.assert_called_once_with(
        {
            "conversation_id": "conversation-2",
            "role": "user",
            "content": "Start over",
        }
    )


def test_text_stream_returns_effective_conversation_id_and_keeps_content_protocol():
    admin = MagicMock()
    with patch("app.api.routes.ai.check_and_increment_chat"), patch(
        "app.api.routes.ai._prepare_conversation", return_value="conversation-1"
    ) as prepare, patch(
        "app.api.routes.ai.iter_ai_command_events_async", side_effect=_agent_events
    ), patch(
        "app.api.routes.ai.fetch_user_memory", new=AsyncMock(return_value="")
    ), patch(
        "app.api.routes.ai.fetch_similar_history", new=AsyncMock(return_value="")
    ), patch(
        "app.api.routes.ai.extract_and_save_memory", new=AsyncMock()
    ), patch(
        "app.api.routes.ai.log_query", new=AsyncMock()
    ), patch(
        "app.api.routes.ai.save_conversation", new=AsyncMock()
    ), patch("app.api.routes.ai.get_supabase_admin", return_value=admin):
        response = asyncio.run(
            ai_command_route.__wrapped__(
                request=_request(),
                payload=AICommandRequest(message="Where is the bearing?"),
                background_tasks=BackgroundTasks(),
                user=AuthenticatedUser(user_id="user-1", first_name="Tanya"),
                stream=True,
            )
        )
        body = asyncio.run(_body(response))

    prepare.assert_called_once_with(
        user_id="user-1",
        requested_id=None,
        user_message="Where is the bearing?",
    )
    assert 'data: {"conversation_id": "conversation-1"}' in body
    assert 'data: {"content": "Cabinet A"}' in body
    assert '"nav_hint": {"type": "space", "id": "space-1"}' in body
    assert body.rstrip().endswith("data: [DONE]")


def test_follow_up_reuses_supplied_conversation_id():
    admin = MagicMock()
    with patch("app.api.routes.ai.check_and_increment_chat"), patch(
        "app.api.routes.ai._prepare_conversation", return_value="conversation-1"
    ) as prepare, patch(
        "app.api.routes.ai.iter_ai_command_events_async", side_effect=_agent_events
    ), patch(
        "app.api.routes.ai.fetch_user_memory", new=AsyncMock(return_value="")
    ), patch(
        "app.api.routes.ai.fetch_similar_history", new=AsyncMock(return_value="")
    ), patch(
        "app.api.routes.ai.extract_and_save_memory", new=AsyncMock()
    ), patch("app.api.routes.ai.log_query", new=AsyncMock()), patch(
        "app.api.routes.ai.save_conversation", new=AsyncMock()
    ), patch("app.api.routes.ai.get_supabase_admin", return_value=admin):
        response = asyncio.run(
            ai_command_route.__wrapped__(
                request=_request(),
                payload=AICommandRequest(
                    message="Which shelf?", conversation_id="conversation-1"
                ),
                background_tasks=BackgroundTasks(),
                user=AuthenticatedUser(user_id="user-1"),
                stream=True,
            )
        )
        asyncio.run(_body(response))

    prepare.assert_called_once_with(
        user_id="user-1",
        requested_id="conversation-1",
        user_message="Which shelf?",
    )


def test_text_stream_scrubs_internal_errors_and_terminates():
    with patch("app.api.routes.ai.check_and_increment_chat"), patch(
        "app.api.routes.ai._prepare_conversation", return_value=None
    ), patch(
        "app.api.routes.ai.iter_ai_command_events_async",
        side_effect=_failing_agent_events,
    ), patch(
        "app.api.routes.ai.fetch_user_memory", new=AsyncMock(return_value="")
    ), patch(
        "app.api.routes.ai.fetch_similar_history", new=AsyncMock(return_value="")
    ):
        response = asyncio.run(
            ai_command_route.__wrapped__(
                request=_request(),
                payload=AICommandRequest(message="Where is it?"),
                background_tasks=BackgroundTasks(),
                user=AuthenticatedUser(user_id="user-1"),
                stream=True,
            )
        )
        body = asyncio.run(_body(response))

    assert 'data: {"content": "Partial"}' in body
    assert "Ask FindEZ is temporarily unavailable. Please try again." in body
    assert "private gateway detail" not in body
    assert body.rstrip().endswith("data: [DONE]")


def test_upload_stream_associates_user_and_assistant_with_conversation():
    upload = UploadFile(
        file=io.BytesIO(b"manual text"),
        filename="manual.txt",
        headers=Headers({"content-type": "text/plain"}),
    )
    admin = MagicMock()
    messages = MagicMock()
    conversations = MagicMock()
    admin.table.side_effect = lambda name: {
        "messages": messages,
        "conversations": conversations,
    }[name]
    with patch(
        "app.api.routes.ai._prepare_conversation", return_value="conversation-1"
    ) as prepare, patch(
        "app.api.routes.ai.iter_assist_file_analysis_sse",
        return_value=iter(
            [
                'data: {"type":"delta","delta":"Summary"}\n\n',
                'data: {"type":"done","assistant_message":"Summary"}\n\n',
            ]
        ),
    ), patch("app.api.routes.ai.get_supabase_admin", return_value=admin):
        response = ai_upload_route.__wrapped__(
            request=_request(),
            file=upload,
            conversation_id="conversation-1",
            user=AuthenticatedUser(user_id="user-1"),
        )
        body = asyncio.run(_body(response))

    prepare.assert_called_once_with(
        user_id="user-1",
        requested_id="conversation-1",
        user_message="Uploaded file: manual.txt",
    )
    done_line = next(
        line for line in body.splitlines() if '"type": "done"' in line
    )
    event = json.loads(done_line.removeprefix("data: "))
    assert event["conversation_id"] == "conversation-1"
    assert event["assistant_message"] == "Summary"
    messages.insert.assert_called_once_with(
        {
            "conversation_id": "conversation-1",
            "role": "assistant",
            "content": "Summary",
        }
    )
    conversations.update.assert_called_once()
