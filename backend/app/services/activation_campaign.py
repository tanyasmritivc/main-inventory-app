"""Weekly onboarding recovery. The inventory-notification worker calls this separately."""
import logging
import os
from html import escape
from urllib.parse import urlsplit

from app.core.config import get_settings
from app.services import email_delivery, push_notifications
from app.services.notification_delivery import send_once
from app.services.supabase_client import get_supabase_raw

log = logging.getLogger(__name__)

# Subject / email body / push body. Later cycles rotate without repeating week one.
MESSAGES = (
    ("Your FindEZ inventory is waiting.",
     "Create your first Space for tools, parts, or equipment. Add one item and its location so you can ask FindEZ where to find it.",
     "Create your first Space and give one item a home."),
    ("Know what you have. Find what you need.",
     "Where are the M4 screws? How many did you record? Add a part and its quantity to start answering those questions. When you record orders, you can check those separately.",
     "What do you have in storage? Start with one part."),
    ("Already have an inventory list?",
     "Open Spaces, choose Start now, and select Spreadsheet. Bring in the list you already keep and review the rows before saving.",
     "Start with a list you already keep. Try importing it into FindEZ."),
    ("Start with a photo of one shelf.",
     "Choose Auto extract to photograph a shelf or toolbox. Review what FindEZ picks out, then save the items you want to keep.",
     "Photograph one shelf and review the parts FindEZ picks out."),
    ("What would you ask FindEZ?",
     "Try describing an item and where you store it in Ask. A useful first record can be as simple as the name of a tool and the drawer it belongs in.",
     "Give FindEZ one tool and its location to remember."),
    ("Give your next project a Space.",
     "Pick a drawer, bench, or project box you use often. Create a Space for it and record the first thing you want to find there again.",
     "Pick one drawer or project box for your first Space."),
)


def copy_for(cycle):
    return MESSAGES[cycle - 1 if cycle <= 2 else 2 + (cycle - 3) % (len(MESSAGES) - 2)]


def enabled():
    return os.getenv("FINDEZ_ACTIVATION_ENABLED") == "1"


def https_url(name, default=""):
    value = os.getenv(name, default).strip().rstrip("/")
    parsed = urlsplit(value)
    if parsed.scheme == "https" and parsed.hostname and not (
        parsed.username or parsed.password or parsed.query or parsed.fragment
    ):
        return value
    return ""


def available_channels():
    settings = get_settings()
    mail = bool((settings.brevo_smtp_username and settings.brevo_smtp_password)
                or os.getenv("RESEND_API_KEY"))
    return {
        "allow_email": mail and bool(https_url("FINDEZ_ACTIVATION_API_URL")) and bool(
            https_url("FINDEZ_ACTIVATION_APP_URL", "https://findez.ai/spaces")),
        "allow_push": os.getenv("FINDEZ_PERSONALIZATION_PUSH_ENABLED") == "1"
                      and push_notifications._credentials() is not None,
    }


def submit(row):
    subject, body, prompt = copy_for(row["step"])
    if row["channel"] == "push":
        content = {"title": "FindEZ", "body": prompt if row["details"] else
                   "Open FindEZ for a quick way to get started."}
        state, _ = send_once(row, row["id"], row["user_id"], content)
        return {"accepted": "accepted", "unknown": "unknown"}.get(state, "rejected")

    url = https_url("FINDEZ_ACTIVATION_APP_URL", "https://findez.ai/spaces")
    stop = f'{https_url("FINDEZ_ACTIVATION_API_URL")}/activation/unsubscribe/{row["unsubscribe"]}'
    email_delivery.send_transactional_email(
        to=row["email"], subject=subject,
        text=f"{body}\n\nOpen FindEZ: {url}\n\nUnsubscribe from setup reminders: {stop}",
        html=f'<p>{escape(body)}</p><p><a href="{escape(url, quote=True)}">Open FindEZ</a></p>'
             f'<p><a href="{escape(stop, quote=True)}">Unsubscribe from setup reminders</a></p>',
        message_id=f'<{row["id"]}@findez.ai>',
        headers={"List-Unsubscribe": f"<{stop}>", "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
                 "X-Mailin-custom": f'activation:{row["id"]}'},
    )
    return "accepted"


def dispatch(limit=None):
    if not enabled():
        return 0
    channels = available_channels()
    if not any(channels.values()):
        log.warning("activation_channels_unconfigured")
        return 0
    if limit is None:
        try:
            limit = int(os.getenv("FINDEZ_ACTIVATION_BATCH_SIZE", "5"))
        except ValueError:
            log.warning("activation_invalid_batch_size")
            return 0
    client = get_supabase_raw()
    accepted = 0
    for _ in range(max(0, min(limit, 100))):
        reminder = client.rpc("findez_activation_claim", channels).execute().data
        if not reminder:
            break
        row = client.rpc("findez_activation_begin", {"p_id": reminder, **channels}).execute().data
        if not row:
            continue
        try:
            outcome = submit(row)
        except Exception:
            # A transport failure can happen after provider acceptance. Never replay this cycle.
            log.warning("activation_provider_outcome_unknown")
            outcome = "unknown"
        client.table("activation_reminders").update({"outcome": outcome}).eq(
            "id", reminder).eq("outcome", "submitting").execute()
        accepted += int(outcome == "accepted")
    return accepted
