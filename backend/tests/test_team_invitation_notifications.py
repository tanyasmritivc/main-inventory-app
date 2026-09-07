import os
import sys
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault(
    "SUPABASE_JWKS_URL",
    "https://placeholder.supabase.co/.well-known/jwks.json",
)
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.api.routes import teams
from app.core.auth import AuthenticatedUser
from app.services.email_delivery import send_transactional_email
from app.services.push_notifications import _send


def test_team_invite_url_uses_frontend_and_rotating_code():
    with (
        patch.object(teams.teams_repo, "get_team_invitation", return_value={
            "team_id": "team-1",
            "name": "Circuit Breakers",
            "program": "ftc",
            "join_code": "ABC234",
        }),
        patch.object(
            teams,
            "get_settings",
            return_value=SimpleNamespace(frontend_url="https://www.findez.ai/"),
        ),
    ):
        result = teams._invite_details("team-1", "user-1")

    assert result["invite_url"] == "https://www.findez.ai/join/team/ABC234"
    assert result["team_name"] == "Circuit Breakers"


def test_transactional_email_uses_noreply_sender_over_smtp():
    smtp = MagicMock()
    smtp.__enter__.return_value = smtp
    settings = SimpleNamespace(
        smtp_from_name="FindEZ",
        smtp_from_email="noreply@findez.ai",
        brevo_smtp_host="smtp-relay.brevo.com",
        brevo_smtp_port=587,
        brevo_smtp_username="user",
        brevo_smtp_password="password",
    )
    with (
        patch("app.services.email_delivery.get_settings", return_value=settings),
        patch("app.services.email_delivery.smtplib.SMTP", return_value=smtp),
    ):
        send_transactional_email(
            to="member@example.com",
            subject="Team invitation",
            html="<p>Join</p>",
            text="Join",
        )

    message = smtp.send_message.call_args.args[0]
    assert message["From"] == "FindEZ <noreply@findez.ai>"
    assert message["To"] == "member@example.com"
    smtp.starttls.assert_called_once()
    smtp.login.assert_called_once_with("user", "password")


def test_apns_payload_groups_by_team_and_sets_badge():
    response = MagicMock(status_code=200)
    client = MagicMock()
    client.__enter__.return_value = client
    client.post.return_value = response
    with (
        patch(
            "app.services.push_notifications._credentials",
            return_value=("/tmp/key", "key", "team", "com.findez.app"),
        ),
        patch("app.services.push_notifications._authorization", return_value="jwt"),
        patch("app.services.push_notifications.httpx.Client", return_value=client),
    ):
        sent = _send(
            {"device_token": "device", "environment": "production"},
            title="Circuit Breakers",
            body="Tanya updated inventory",
            badge=4,
            thread_id="team-team-1",
            data={"team_id": "team-1", "action": "item_updated"},
        )

    assert sent is True
    payload = client.post.call_args.kwargs["json"]
    assert payload["aps"]["badge"] == 4
    assert payload["aps"]["thread-id"] == "team-team-1"
    assert payload["aps"]["category"] == "TEAM_ACTIVITY"
