"""Isolated founder API. Customer application services are unchanged."""
import asyncio
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import time
from typing import Literal

from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx
from pydantic import BaseModel, Field

from collectors import Sources, journal_summary, metric
from store import Store, now
from storage_monitor import update_storage_incidents


class IssueInput(BaseModel):
    title: str = Field(min_length=3, max_length=140)
    description: str = Field(default="", max_length=2000)
    severity: Literal["info", "warning", "critical"] = "warning"
    kind: Literal["issue", "task"] = "issue"


class StatusInput(BaseModel):
    status: Literal["open", "in_progress", "resolved"]


def create_app(sources=None, store=None, owner=None, monitor=True):
    data = sources or Sources()
    db = store or Store(os.environ.get("DASHBOARD_DB", "/home/ubuntu/findez-dashboard-data/dashboard.sqlite"))
    identity = owner or json.loads(Path(os.environ.get("DASHBOARD_OWNER_FILE", "owner.json")).read_text())["user_id"]
    cache, lock = {}, asyncio.Lock()
    login_lock = asyncio.Lock()

    async def monitoring():
        while True:
            try:
                health = await data.health()
                db.sample({"at": now(), "checks": health["checks"], "storage": health.get("storage")})
                for check in health["checks"]:
                    if check["id"] == "upload_storage":
                        continue  # Storage has capacity-specific warning/critical incidents.
                    db.incident("health:"+check["id"], check["label"]+" unavailable",
                                "A direct service health probe failed. Open Infrastructure for the latest status.",
                                "critical", not check["healthy"])
                if health.get("storage"):
                    update_storage_incidents(db, health["storage"])
            except Exception:
                db.incident("monitor:collection", "Monitoring collection failed", "The monitor could not complete its health collection. Metrics may be stale.", "warning", True)
            else:
                db.incident("monitor:collection", "Monitoring collection failed", "", "warning", False)
            await asyncio.sleep(60)

    @asynccontextmanager
    async def lifespan(_):
        task = asyncio.create_task(monitoring()) if monitor else None
        yield
        if task:
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
        await data.client.aclose()

    app = FastAPI(title="FindEZ Founder Dashboard", docs_url=None, redoc_url=None, openapi_url=None, lifespan=lifespan)
    bearer = HTTPBearer(auto_error=False)

    async def founder(credentials: HTTPAuthorizationCredentials | None = Depends(bearer)):
        if not credentials or credentials.scheme.lower() != "bearer" or len(credentials.credentials) > 8192:
            raise HTTPException(401, "Sign in to your founder account.")
        try:
            response = await data.client.get(data.base + "/auth/v1/user", headers={
                "apikey": data.env["SUPABASE_ANON_KEY"], "Authorization": "Bearer " + credentials.credentials})
            if response.status_code != 200:
                raise HTTPException(401, "Your session expired. Please sign in again.")
            user = response.json()
        except httpx.HTTPError:
            raise HTTPException(503, "Account verification is temporarily unavailable.") from None
        if user.get("id") != identity or not user.get("email_confirmed_at"):
            db.audit(user.get("id", "unknown"), "dashboard_access", "dashboard", "denied")
            raise HTTPException(403, "This dashboard is private to the founder.")
        # Auth server validates the token before its assurance level is inspected.
        if any(f.get("status") == "verified" for f in user.get("factors", [])):
            import base64
            try:
                part = credentials.credentials.split(".")[1]
                claims = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))
            except (ValueError, IndexError):
                raise HTTPException(401, "Please sign in again.") from None
            if claims.get("aal") != "aal2":
                raise HTTPException(403, "Complete your account's multifactor sign-in.")
        return user

    @app.middleware("http")
    async def privacy_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers.update({"Cache-Control": "no-store, private", "X-Content-Type-Options": "nosniff", "X-Frame-Options": "DENY"})
        return response

    @app.get("/dashboard/v1/health")
    async def service_health():
        return {"status": "ok"}

    @app.post("/dashboard/v1/login/code")
    async def request_signin_code():
        # This can send only to the existing, explicitly configured founder.
        # No supplied recipient, new account or service credential reaches a client.
        async with login_lock:
            current = datetime.now(timezone.utc)
            if db.action_count("request_signin_code", (current-timedelta(seconds=60)).isoformat()) or db.action_count("request_signin_code", (current-timedelta(days=1)).isoformat()) >= 20:
                raise HTTPException(429, "Please wait a minute before requesting another code. Up to 20 codes can be requested per day.")
            if not data.env.get("BREVO_SMTP_USERNAME") or not data.env.get("BREVO_SMTP_PASSWORD"):
                raise HTTPException(503, "Email sign-in is unavailable. Use your FindEZ password.")
            response = await data.client.get(data.base + "/auth/v1/admin/users/" + identity, headers=data.headers)
            if response.status_code != 200:
                raise HTTPException(503, "Could not verify the founder account. Try again later.")
            user = response.json()
            email = user.get("email")
            if user.get("id") != identity or not user.get("email_confirmed_at") or not email:
                raise HTTPException(503, "Founder email sign-in is not configured.")
            # Record the attempt before upstream I/O so failures cannot bypass throttling.
            db.audit(identity, "request_signin_code", "founder", "requested")
            response = await data.client.post(data.base + "/auth/v1/admin/generate_link", headers=data.headers,
                                               json={"type": "magiclink", "email": email})
            if response.status_code != 200:
                raise HTTPException(503, "Could not prepare a sign-in code. Try again later.")
            code = response.json().get("email_otp")
            if not code or not str(code).isdigit():
                raise HTTPException(503, "Could not prepare a sign-in code. Use your password.")
            def send():
                from email.message import EmailMessage
                import smtplib
                import ssl
                message = EmailMessage()
                message["From"] = data.env.get("SMTP_FROM_EMAIL", "noreply@findez.ai")
                message["To"] = email
                message["Subject"] = "Your FindEZ Dashboard sign-in code"
                message.set_content("Your private founder dashboard sign-in code is:\n\n" + str(code) + "\n\nOnly enter it in FindEZ Dashboard. Never share this code. If you did not request it, ignore this email.")
                with smtplib.SMTP(data.env.get("BREVO_SMTP_HOST", "smtp-relay.brevo.com"), int(data.env.get("BREVO_SMTP_PORT", "587")), timeout=12) as smtp:
                    smtp.starttls(context=ssl.create_default_context())
                    smtp.login(data.env["BREVO_SMTP_USERNAME"], data.env["BREVO_SMTP_PASSWORD"])
                    smtp.send_message(message)
            try:
                await asyncio.to_thread(send)
            except Exception:
                db.audit(identity, "send_signin_code", "founder", "failed")
                raise HTTPException(503, "The sign-in email could not be delivered. Use your password or try again later.") from None
            db.audit(identity, "send_signin_code", "founder")
            return {"sent": True}

    async def collect():
        async with lock:
            if cache and time.monotonic() - cache["time"] < 15:
                return cache["snapshot"]
            values = await asyncio.gather(
                asyncio.wait_for(data.application(), 30), asyncio.wait_for(data.usage(), 20),
                asyncio.wait_for(data.revenue(), 30), asyncio.wait_for(data.health(), 10),
                asyncio.wait_for(journal_summary(), 8), return_exceptions=True)
            result = {"at": now(), "refresh_seconds": 60, "definitions_version": 1, "source_status": []}
            for name, value in zip(("analytics", "ai", "revenue", "infrastructure", "diagnostics"), values):
                if isinstance(value, Exception):
                    result[name] = {"metrics": [], "unavailable": True, "note": "This data source could not be synchronized. No zero values are substituted."}
                    result["source_status"].append({"name": name, "status": "unavailable"})
                else:
                    result[name] = value
                    result["source_status"].append({"name": name, "status": "not connected" if value.get("connected") is False else "partial" if value.get("partial") else "synced"})
            if result["infrastructure"].get("storage"):
                update_storage_incidents(db, result["infrastructure"]["storage"])
            result["customers"] = result["analytics"].pop("customers", [])
            result["activity"] = result["analytics"].pop("activity", []) + result["diagnostics"].pop("events", [])
            result["activity"].sort(key=lambda e: e["at"], reverse=True)
            result["activity"] = result["activity"][:150]
            diag = result["diagnostics"]
            if not diag.get("unavailable"):
                result["infrastructure"]["metrics"].append(metric("errors", "Logged API server error rate", diag["error_rate"], unit="percent", source="Backend journal access records", period="Last 24 hours", definition=diag["note"]))
                db.incident("logs:errors", "Backend errors recorded", "Completed backend requests returned server errors in the last 24 hours. Open Live Activity for redacted event categories.", "warning", diag["errors"] > 0)
                db.incident("logs:rate", "Rate-limit events recorded", "Backend logs contain rate-limit events within the last 24 hours. Counts may include repeated messages.", "warning", bool(diag["categories"].get("Rate limit event")))
                db.incident("logs:application", "Application errors recorded", "Backend logs contain application error entries within the last 24 hours. Raw customer content is withheld.", "warning", bool(diag["categories"].get("Application error recorded")))
            past_due = next((m["value"] for m in result["revenue"]["metrics"] if m["id"] == "past_due"), None)
            if past_due is not None:
                db.incident("stripe:past_due", "Subscriptions need payment attention", "Stripe reports past-due subscriptions. Review Revenue for the current count.", "warning", past_due > 0)
            result["monitoring_history"] = db.history()
            cache.update(time=time.monotonic(), snapshot=result)
            return result

    @app.get("/dashboard/v1/snapshot")
    async def snapshot(user=Depends(founder)):
        result = dict(await collect())
        result["issues"] = db.issues()
        result["audit"] = db.audits()
        db.audit(user["id"], "read_dashboard", "snapshot")
        return result

    @app.post("/dashboard/v1/issues", status_code=201)
    async def create_issue(body: IssueInput, user=Depends(founder)):
        if not body.title.strip() or len(body.title.strip()) < 3:
            raise HTTPException(422, "Add a short, meaningful title.")
        identity = db.create(user["id"], body.title.strip(), body.description.strip(), body.severity, body.kind)
        return {"id": identity, "saved": True}

    @app.patch("/dashboard/v1/issues/{issue_id}")
    async def update_issue(issue_id: str, body: StatusInput, user=Depends(founder)):
        if not db.update(user["id"], issue_id, body.status):
            raise HTTPException(404, "This issue no longer exists.")
        return {"saved": True}

    return app


def production():
    return create_app()
