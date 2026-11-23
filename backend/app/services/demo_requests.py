"""Durable demo inbox and transactional mail queue for the self-hosted API."""
import asyncio
from contextlib import closing
from hashlib import sha256
from html import escape
import json
import logging
from pathlib import Path
import sqlite3
import time

from app.services.email_delivery import send_transactional_email

INBOX = Path.home() / ".local/share/findez-demo/inbox.sqlite3"
FOUNDER = "tanya@findez.ai"
logger = logging.getLogger(__name__)


def connect():
    INBOX.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    db = sqlite3.connect(INBOX, timeout=8)
    db.row_factory = sqlite3.Row
    return db


def initialize():
    with closing(connect()) as db, db:
        db.executescript("""
            CREATE TABLE IF NOT EXISTS requests (
                id TEXT PRIMARY KEY, email TEXT NOT NULL, details TEXT NOT NULL,
                fingerprint TEXT NOT NULL, created INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS requests_email ON requests(email, created);
            CREATE INDEX IF NOT EXISTS requests_created ON requests(created);
            CREATE TABLE IF NOT EXISTS mail (
                request_id TEXT NOT NULL, kind TEXT NOT NULL, due INTEGER NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0, sent INTEGER,
                PRIMARY KEY(request_id, kind)
            );
            CREATE INDEX IF NOT EXISTS mail_pending ON mail(due) WHERE sent IS NULL;
        """)


class TooManyRequests(Exception):
    pass


class RequestConflict(Exception):
    pass


def save(request_id, email, details):
    initialize()
    now = int(time.time())
    data = json.dumps(details, sort_keys=True)
    fingerprint = sha256((email + data).encode()).hexdigest()
    with closing(connect()) as db, db:
        db.execute("BEGIN IMMEDIATE")
        previous = db.execute("SELECT fingerprint FROM requests WHERE id=?", (request_id,)).fetchone()
        if previous:
            if previous["fingerprint"] != fingerprint:
                raise RequestConflict
            return
        if db.execute("SELECT 1 FROM requests WHERE email=? AND fingerprint=? AND created>? LIMIT 1",
                      (email, fingerprint, now - 900)).fetchone():
            return
        recent = db.execute("SELECT count(*) FROM requests WHERE email=? AND created>?", (email, now - 86400)).fetchone()[0]
        total = db.execute("SELECT count(*) FROM requests WHERE created>?", (now - 3600,)).fetchone()[0]
        if recent >= 3 or total >= 100:
            raise TooManyRequests
        db.execute("INSERT INTO requests VALUES(?,?,?,?,?)", (request_id, email, data, fingerprint, now))
        db.executemany("INSERT INTO mail(request_id,kind,due) VALUES(?,?,?)",
                       [(request_id, kind, now) for kind in ("founder", "visitor")])


def deliver_one():
    now = int(time.time())
    with closing(connect()) as db, db:
        db.execute("BEGIN IMMEDIATE")
        job = db.execute("""
            SELECT m.*, r.email, r.details FROM mail m JOIN requests r ON r.id=m.request_id
            WHERE m.sent IS NULL AND m.due<=? ORDER BY m.due, m.rowid LIMIT 1
        """, (now,)).fetchone()
        if not job:
            return False
        key = (job["request_id"], job["kind"])
        db.execute("UPDATE mail SET due=?, attempts=attempts+1 WHERE request_id=? AND kind=?",
                   (now + 300, *key))
    details = json.loads(job["details"])
    if job["kind"] == "founder":
        to, subject = FOUNDER, "New FindEZ demo request"
        text = "\n".join([
            "A visitor requested a FindEZ demo.", "",
            "Name: " + details["name"], "Email: " + job["email"],
            "Organization: " + details["organization"],
            *[f"{label}: {details[key]}" for key, label in (
                ("role", "Job title or role"), ("organization_type", "Organization type"),
                ("team_size", "Team size"), ("referral", "How they heard about FindEZ"),
            ) if details.get(key)],
            "",
            "Demo interests: " + (", ".join(details["interests"]) or "Unspecified"),
            *[f"{label}: {details[key]}" for key, label in (
                ("other_interest", "Other interest"), ("cad_software", "CAD software"),
                ("problem", "What they are trying to solve"),
            ) if details.get(key)],
            "", "Reply to this message to arrange a time.",
        ])
        reply = job["email"]
    else:
        to, subject = job["email"], "We received your FindEZ demo request"
        text = ("Thanks for requesting a FindEZ demo. We will email you to arrange a time.\n\n"
                "If you’d like to share anything else before the demo, reply to this email.\n\nThe FindEZ team")
        reply = FOUNDER
    try:
        send_transactional_email(to=to, subject=subject, html="<p>" + escape(text).replace("\n", "<br>") + "</p>",
                                 text=text, message_id=f"<demo-{key[0]}-{key[1]}@findez.ai>", reply_to=reply)
    except Exception:
        logger.warning("Demo %s email delivery failed; retry queued for request %s", key[1], key[0])
        delay = min(3600, 60 * 2 ** min(job["attempts"], 6))
        with closing(connect()) as db, db:
            db.execute("UPDATE mail SET due=? WHERE request_id=? AND kind=?", (now + delay, *key))
    else:
        with closing(connect()) as db, db:
            db.execute("UPDATE mail SET sent=? WHERE request_id=? AND kind=?", (int(time.time()), *key))
    return True


async def run_mail_queue():
    initialized = False
    while True:
        try:
            if not initialized:
                await asyncio.to_thread(initialize)
                initialized = True
            if await asyncio.to_thread(deliver_one):
                continue
        except (OSError, sqlite3.Error):
            initialized = False
            logger.error("Demo email queue is temporarily unavailable")
        await asyncio.sleep(5)
