"""Dashboard-only issues and audit history. Never writes customer tables."""
from contextlib import contextmanager
from datetime import datetime, timezone
import json
from pathlib import Path
import sqlite3
import uuid


def now():
    return datetime.now(timezone.utc).isoformat()


class Store:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS issues (
                    id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT NOT NULL,
                    severity TEXT NOT NULL, status TEXT NOT NULL, kind TEXT NOT NULL,
                    created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                    source TEXT NOT NULL, occurrences INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE IF NOT EXISTS audit (
                    id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL,
                    target TEXT NOT NULL, outcome TEXT NOT NULL, at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS samples (
                    at TEXT PRIMARY KEY, payload TEXT NOT NULL
                );
            """)

    @contextmanager
    def db(self):
        with sqlite3.connect(self.path, timeout=5) as db:
            db.row_factory = sqlite3.Row
            yield db

    def audit(self, actor, action, target, outcome="success"):
        with self.db() as db:
            db.execute("INSERT INTO audit VALUES (?,?,?,?,?,?)",
                       (str(uuid.uuid4()), actor, action, target, outcome, now()))

    def audits(self):
        with self.db() as db:
            return [dict(r) for r in db.execute("SELECT * FROM audit ORDER BY at DESC LIMIT 100")]

    def action_count(self, action, since):
        with self.db() as db:
            return db.execute("SELECT count(*) FROM audit WHERE action=? AND at>=?", (action, since)).fetchone()[0]

    def issues(self):
        with self.db() as db:
            return [dict(r) for r in db.execute("SELECT * FROM issues ORDER BY updated_at DESC LIMIT 250")]

    def create(self, actor, title, description, severity, kind="issue"):
        identity, at = str(uuid.uuid4()), now()
        with self.db() as db:
            db.execute("INSERT INTO issues VALUES (?,?,?,?,?,?,?,?,?,?)",
                       (identity, title, description, severity, "open", kind, at, at, "Founder", 1))
            db.execute("INSERT INTO audit VALUES (?,?,?,?,?,?)",
                       (str(uuid.uuid4()), actor, "create_" + kind, identity, "success", at))
        return identity

    def update(self, actor, identity, status):
        with self.db() as db:
            result = db.execute("UPDATE issues SET status=?,updated_at=? WHERE id=?",
                                (status, now(), identity))
            if not result.rowcount:
                return False
            db.execute("INSERT INTO audit VALUES (?,?,?,?,?,?)",
                       (str(uuid.uuid4()), actor, "set_status_" + status, identity, "success", now()))
        return True

    def incident(self, identity, title, description, severity, active):
        at = now()
        with self.db() as db:
            existing = db.execute("SELECT status FROM issues WHERE id=?", (identity,)).fetchone()
            if active:
                db.execute("""INSERT INTO issues VALUES (?,?,?,?,?,?,?,?,?,?)
                    ON CONFLICT(id) DO UPDATE SET updated_at=excluded.updated_at,
                    status=CASE WHEN issues.status='resolved' THEN 'open' ELSE issues.status END,
                    occurrences=issues.occurrences+1""",
                           (identity, title, description, severity, "open", "incident", at, at, "Monitoring", 1))
            elif existing and existing["status"] != "resolved":
                db.execute("UPDATE issues SET status='resolved',updated_at=? WHERE id=?", (at, identity))
                db.execute("INSERT INTO audit VALUES (?,?,?,?,?,?)",
                           (str(uuid.uuid4()), "monitor", "auto_resolve", identity, "success", at))

    def sample(self, payload):
        with self.db() as db:
            db.execute("INSERT OR REPLACE INTO samples VALUES (?,?)", (payload["at"], json.dumps(payload)))
            db.execute("DELETE FROM samples WHERE at < datetime('now','-30 days')")

    def history(self):
        with self.db() as db:
            return [json.loads(r[0]) for r in db.execute("SELECT payload FROM samples ORDER BY at DESC LIMIT 96")]
