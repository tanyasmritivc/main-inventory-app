"""Durable demo inbox and transactional mail queue for the self-hosted API."""
import asyncio
from contextlib import closing, contextmanager
import fcntl
import os
import re
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


TEMPLATES = Path(__file__).with_name("demo_templates")


def founder():
    return os.environ.get("DEMO_FOUNDER_EMAIL") or FOUNDER


@contextmanager
def delivery_lock():
    # Serialize booking/approval changes with the last eligibility check and mail handoff.
    with INBOX.with_suffix(".delivery.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def branded_html(text):
    chunks = re.split(r"(https://[^\s<>]+)", text)
    for i, chunk in enumerate(chunks):
        if i % 2:
            url = chunk.rstrip(".,)")
            chunks[i] = '<a href="' + escape(url, quote=True) + '">' + escape(url) + '</a>' + escape(chunk[len(url):])
        else:
            chunks[i] = escape(chunk)
    body = "".join(chunks).replace("\n","<br>")
    return ('<div style="max-width:600px;margin:auto;padding:24px;font:16px/1.6 Arial,sans-serif;color:#0a0a0b">'
            + body + '<div style="margin-top:24px">' + (TEMPLATES / "signature.html").read_text() + '</div></div>')


def connect():
    INBOX.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    db = sqlite3.connect(INBOX, timeout=8)
    db.execute("PRAGMA foreign_keys=ON")
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

        db.execute("BEGIN IMMEDIATE")
        if db.execute("PRAGMA user_version").fetchone()[0] == 0:
            migration = Path(__file__).with_name("demo_migrations") / "001_sales.sql"
            for statement in migration.read_text().split(";"):
                if statement.strip():
                    db.execute(statement)
            db.execute("PRAGMA user_version=1")


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
        db.execute("INSERT INTO sales(request_id,updated) VALUES(?,?)", (request_id,now))
        db.executemany("INSERT INTO mail(request_id,kind,due) VALUES(?,?,?)",
                       [(request_id, kind, now) for kind in ("founder", "visitor")])


def deliver_one():
    with delivery_lock():
        return _deliver_one()


def _deliver_one():
    from app.services import demo_sales as sales
    now = int(time.time())
    with closing(connect()) as db, db:
        db.execute("BEGIN IMMEDIATE")
        job = db.execute("""
            SELECT m.*, r.email, r.details FROM mail m JOIN requests r ON r.id=m.request_id
            WHERE m.sent IS NULL AND m.cancelled IS NULL AND m.attempts<8 AND m.due<=? ORDER BY m.due, m.rowid LIMIT 1
        """, (now,)).fetchone()
        if not job:
            return False
        key = (job["request_id"], job["kind"])
        db.execute("UPDATE mail SET due=?, attempts=attempts+1 WHERE request_id=? AND kind=?",
                   (now + 300, *key))
    details = json.loads(job["details"])
    extra = {}
    content = json.loads(job["content"] or "{}")
    if content:
        expires = content.get("expires")
        if expires and expires <= now:
            with closing(connect()) as db, db:
                db.execute("UPDATE mail SET cancelled=? WHERE request_id=? AND kind=?",(now,*key))
            return True
        to = founder() if content.get("host") else job["email"]
        subject, text = content["subject"], content["text"]
        reply = job["email"] if content.get("host") else founder()
        if content.get("ics"):
            extra["calendar"] = (content["calendar"], content["ics"])
    elif job["kind"] == "founder":
        to, subject = founder(), "New FindEZ demo request"
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
                ("problem", "What they are trying to solve"), ("comments", "Additional comments"),
            ) if details.get(key)],
            "", "Reply to this message to arrange a time.",
        ])
        reply = job["email"]
    else:
        to, subject = job["email"], "Your FindEZ AI Product Demo Request"
        text = (TEMPLATES / "confirmation.txt").read_text().format(first_name=details["name"].split()[0]).strip()
        reply = founder()
    try:
        identifier = sha256(f"{key[0]}:{key[1]}".encode()).hexdigest() if content else f"{key[0]}-{key[1]}"
        send_transactional_email(to=to, subject=subject, html=branded_html(text), text=text,
                                 message_id=f"<demo-{identifier}@findez.ai>", reply_to=reply, **extra)
    except Exception:
        logger.warning("Demo %s email delivery failed; retry queued for request %s", key[1], key[0])
        delay = min(3600, 60 * 2 ** min(job["attempts"], 6))
        with closing(connect()) as db, db:
            sales.event(db,key[0],"mail worker","Mail handoff failed",key[1])
            db.execute("UPDATE mail SET due=?,last_error='Mail provider did not confirm delivery' WHERE request_id=? AND kind=?", (now + delay, *key))
    else:
        with closing(connect()) as db, db:
            db.execute("UPDATE mail SET sent=?, last_error=NULL WHERE request_id=? AND kind=?", (int(time.time()), *key))
            if key[1] == "visitor":
                db.execute("UPDATE sales SET status='Confirmation Sent',updated=? WHERE request_id=? AND status='New Request'", (now,key[0]))
            if key[1].startswith("followup/"):
                db.execute("UPDATE demo_followups SET state='sent' WHERE id=?", (key[1].split("/")[1],))
            sales.event(db,key[0],"mail worker","Mail accepted",subject)
    return True


async def _mail_worker():
    while True:
        try:
            if await asyncio.to_thread(deliver_one):
                continue
        except (OSError, sqlite3.Error):
            logger.error("Demo email queue is temporarily unavailable")
        await asyncio.sleep(5)

async def _briefing_worker():
    from app.services.demo_briefings import generate_one
    while True:
        try:
            if await asyncio.to_thread(generate_one):
                continue
        except (OSError, sqlite3.Error):
            logger.error("Demo briefing queue is temporarily unavailable")
        await asyncio.sleep(5)


async def run_mail_queue():
    while True:
        try:
            await asyncio.to_thread(initialize)
            break
        except (OSError, sqlite3.Error):
            logger.error("Demo inbox is temporarily unavailable")
            await asyncio.sleep(5)
    workers = [asyncio.create_task(worker()) for worker in (_mail_worker, _briefing_worker)]
    try:
        await asyncio.gather(*workers)
    finally:
        for task in workers:
            task.cancel()
        await asyncio.gather(*workers, return_exceptions=True)
