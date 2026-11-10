"""Read-only integrations. Values retain their source and exact meaning."""
import asyncio
from collections import Counter
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
import re
import shutil
import time

import httpx

from store import now
from storage_monitor import storage_status, GIB


def metric(identity, label, value=None, *, unit="count", source="Not connected", definition="", period="Current", note="", status=None):
    return dict(id=identity, label=label, value=value, unit=unit, source=source,
                definition=definition or label, period=period, note=note,
                status=status or ("live" if value is not None else "unavailable"))


class Sources:
    def __init__(self, env=None, client=None):
        self.env = env if env is not None else os.environ
        self.client = client or httpx.AsyncClient(timeout=12, follow_redirects=False)
        self.base = self.env["SUPABASE_URL"].rstrip("/")
        self.headers = {"apikey": self.env["SUPABASE_SERVICE_ROLE_KEY"],
                        "Authorization": "Bearer " + self.env["SUPABASE_SERVICE_ROLE_KEY"]}

    async def rest(self, table, fields, params=None, count=False):
        headers = dict(self.headers)
        if count:
            headers["Prefer"] = "count=exact"
        response = await self.client.get(self.base + "/rest/v1/" + table,
                                         headers=headers, params={"select": fields, **(params or {})})
        response.raise_for_status()
        if count:
            value = response.headers.get("content-range", "").split("/")[-1]
            if not value.isdigit():
                raise ValueError("Exact count unavailable")
            return int(value)
        return response.json()

    async def rows(self, table, fields, params=None):
        rows = []
        for offset in range(0, 20000, 1000):
            page = await self.rest(table, fields, {**(params or {}), "limit": 1000, "offset": offset, "order": fields.split(",")[0] + ".asc"})
            rows.extend(page)
            if len(page) < 1000:
                return rows, False
        return rows, True

    async def accounts(self):
        users = []
        for page in range(1, 21):
            response = await self.client.get(self.base + "/auth/v1/admin/users", headers=self.headers,
                                             params={"page": page, "per_page": 1000})
            response.raise_for_status()
            values = response.json()["users"]
            users.extend(values)
            if len(values) < 1000:
                return users, False
        return users, True

    async def application(self):
        users, capped = await self.accounts()
        current = datetime.now(timezone.utc)
        def recent(value, days):
            try:
                return datetime.fromisoformat(value.replace("Z", "+00:00")) >= current - timedelta(days=days)
            except (AttributeError, ValueError, TypeError):
                return False
        results = await asyncio.gather(
            self.rest("items", "item_id", {"limit": 0}, True),
            self.rest("spaces", "id", {"limit": 0}, True),
            self.rest("teams", "team_id", {"limit": 0}, True),
            self.rows("profiles", "id,is_pro,plan,pending_deletion"),
            self.rows("items", "item_id,user_id,created_at"),
            self.rows("spaces", "id,user_id"),
            self.rows("team_memberships", "team_id,user_id,role"),
            return_exceptions=True,
        )
        total_items, spaces, teams, profiles, items, space_rows, memberships = results
        profile_map = {} if isinstance(profiles, Exception) else {p["id"]: p for p in profiles[0]}
        item_counts = Counter() if isinstance(items, Exception) else Counter(p["user_id"] for p in items[0])
        space_counts = Counter() if isinstance(space_rows, Exception) else Counter(p["user_id"] for p in space_rows[0])
        membership_map = {}
        if not isinstance(memberships, Exception):
            for m in memberships[0]:
                membership_map.setdefault(m["user_id"], []).append({"team_id": m["team_id"], "role": m["role"]})
        directory = []
        for u in users:
            profile = profile_map.get(u["id"], {})
            directory.append(dict(id=u["id"], email=u.get("email") or "Private relay account",
                                  created_at=u.get("created_at"), last_sign_in=u.get("last_sign_in_at"),
                                  plan=profile.get("plan") or ("pro" if profile.get("is_pro") else "Not recorded"),
                                  status="Deletion pending" if profile.get("pending_deletion") else "Registered",
                                  platform="Not tracked", items=item_counts.get(u["id"], 0) if not isinstance(items, Exception) and not items[1] else None,
                                  spaces=space_counts.get(u["id"], 0) if not isinstance(space_rows, Exception) and not space_rows[1] else None,
                                  memberships=membership_map.get(u["id"], []) if not isinstance(memberships, Exception) and not memberships[1] else None))
        directory.sort(key=lambda u: u["created_at"] or "", reverse=True)
        ms = [metric("users", "Registered users", None if capped else len(users), source="Supabase Auth", definition="All registered accounts, including accounts that have not activated."),
              metric("signups7", "New users", None if capped else sum(recent(u.get("created_at"), 7) for u in users), source="Supabase Auth", period="Last 7 days"),
              metric("signups30", "New users", None if capped else sum(recent(u.get("created_at"), 30) for u in users), source="Supabase Auth", period="Last 30 days"),
              metric("items", "Saved inventory records", None if isinstance(total_items, Exception) else total_items, source="PostgreSQL items", definition="Number of saved item records, not the sum of quantities."),
              metric("spaces", "Spaces", None if isinstance(spaces, Exception) else spaces, source="PostgreSQL spaces"),
              metric("teams", "Teams", None if isinstance(teams, Exception) else teams, source="PostgreSQL teams")]
        if not capped and not isinstance(items, Exception) and not items[1] and users:
            activated = len(set(item_counts) & {u["id"] for u in users})
            ms.append(metric("activation", "Accounts with saved items", round(activated / len(users) * 100, 1), unit="percent", source="Auth + items", definition="Registered accounts with at least one saved item record. This is a proxy, not onboarding completion.", note="Activation proxy"))
        else:
            ms.append(metric("activation", "Accounts with saved items", definition="Requires complete account and item counts."))
        for identity, label, detail in [
            ("dau", "Daily active users", "A sign-in is not a session or a product action. Product activity instrumentation is not connected."),
            ("mau", "Monthly active users", "Requires durable product activity events."),
            ("retention", "Day 7 retention", "Requires signup cohorts and durable daily activity."),
            ("platform", "Usage by platform", "Web, iOS and Android events are not instrumented."),
            ("acquisition", "Acquisition channels", "Campaign attribution is not connected."),
            ("onboarding", "Onboarding completion", "Onboarding completion events are not connected.")]:
            ms.append(metric(identity, label, definition=detail))
        growth = []
        if not capped:
            for days in range(13, -1, -1):
                day = (current - timedelta(days=days)).date().isoformat()
                growth.append({"day": day, "count": sum((u.get("created_at") or "").startswith(day) for u in users)})
        activity = [dict(id="signup:"+u["id"], at=u["created_at"], category="Customers", severity="info", title="Account registered", target=u["id"], detail="Account " + u["id"][:8]) for u in directory[:50] if u["created_at"]]
        return dict(metrics=ms, customers=directory, growth=growth, activity=activity, partial=capped)

    async def usage(self):
        period = datetime.now(timezone.utc).strftime("%Y-%m")
        values = await asyncio.gather(
            self.rows("usage_counters", "user_id,chats_used,scans_used", {"period": "eq." + period}),
            self.rows("team_usage_counters", "team_id,chats_used,scans_used,imports_used", {"period": "eq." + period}),
            self.rows("usage_limits", "id,user_id,feature,count", {"period": "eq." + period}), return_exceptions=True)
        personal, team, legacy = values
        def total(field):
            if any(isinstance(r, Exception) or r[1] for r in (personal, team)):
                return None
            return sum(int(row.get(field) or 0) for r in (personal, team) for row in r[0])
        ms = [metric("chats", "Tracked Assist uses", total("chats_used"), source="Personal + team usage counters", period=period,
                     definition="Sum of recorded chat counters. These are product quota counters, not raw model requests."),
              metric("scans", "Tracked scan uses", total("scans_used"), source="Personal + team usage counters", period=period,
                     definition="Sum of recorded scan counters. Tracking coverage depends on the capture path.")]
        for feature, label in [("photo_scan", "Photo scan counter"), ("barcode_scan", "Barcode scan counter"), ("spreadsheet_import", "Import counter")]:
            value = None if isinstance(legacy, Exception) or legacy[1] else sum(int(r.get("count") or 0) for r in legacy[0] if r["feature"] == feature)
            ms.append(metric(feature, label, value, source="Legacy usage_limits", period=period, definition="Recorded legacy feature counters. Shown separately because they can overlap other counters and may omit unmetered pilot usage."))
        for identity, label, definition in [
            ("ai_cost", "AI spending", "Self-hosted FIND and gateway costs are not metered here. Zero would not mean free."),
            ("success", "AI request success rate", "Requires a complete request ledger, including successful and failed requests."),
            ("quality", "Identification accuracy", "Requires labeled evaluations or structured human feedback."),
            ("tokens", "Token usage", "Provider token accounting is not connected."),
            ("gpu", "GPU utilization", "GPU telemetry is not connected."),
            ("queue", "FIND queue length", "A documented queue metric is not connected."),
            ("cost_user", "AI cost per active user", "Requires actual costs and instrumented active users.")]:
            ms.append(metric(identity, label, definition=definition))
        return {"metrics": ms, "note": "FIND and the private agent gateway run server-side. Counters are not a complete AI request or cost ledger."}

    async def stripe_list(self, name, params=None):
        rows, after = [], None
        for _ in range(20):
            query = {"limit": 100, **(params or {})}
            if after:
                query["starting_after"] = after
            response = await self.client.get("https://api.stripe.com/v1/" + name,
                                             auth=(self.env["STRIPE_SECRET_KEY"], ""), params=query)
            response.raise_for_status()
            value = response.json()
            rows.extend(value["data"])
            if not value["has_more"]:
                return rows
            after = value["data"][-1]["id"]
        raise ValueError("Stripe result exceeds safe collection limit")

    async def revenue(self):
        definitions = [("mrr", "Monthly recurring revenue"), ("arr", "Annual recurring revenue"),
                       ("gross30", "Gross payments"), ("refunds30", "Refunds on those payments"),
                       ("after_refunds", "Payments after refunds"), ("paying", "Paying customers"),
                       ("subscriptions", "Active subscriptions"), ("past_due", "Past-due subscriptions"),
                       ("fees", "Payment fees"), ("profit", "Accounting profit"), ("cash", "Company cash balance"),
                       ("churn", "Customer churn"), ("total_revenue", "All-time revenue")]
        unavailable = [metric(k, title, definition="Stripe is not connected or the requested historical/accounting source is unavailable.") for k, title in definitions]
        key = self.env.get("STRIPE_SECRET_KEY", "")
        if not key or not key.startswith(("sk_live_", "rk_live_")):
            return {"metrics": unavailable, "connected": False, "note": "A live Stripe connection is required. Test-mode payments are excluded."}
        subs, charges = await asyncio.gather(self.stripe_list("subscriptions", {"status": "all"}),
                                             self.stripe_list("charges", {"created[gte]": int(time.time()-30*86400)}))
        active = [s for s in subs if s["status"] == "active"]
        currencies = {c["currency"] for c in charges if c.get("paid")}
        currencies.update(item["price"]["currency"] for s in active for item in s["items"]["data"])
        currency = next(iter(currencies)) if len(currencies) == 1 else "usd" if not currencies else None
        if currency is None:
            return {"metrics": unavailable, "connected": True, "note": "Multiple currencies detected. Totals require separate currency reporting; no conversion is assumed."}
        if currency != "usd":
            return {"metrics": unavailable, "connected": True, "note": "This first release supports USD financial reporting. No conversion or minor-unit assumption is made for other currencies."}
        mrr = 0
        for s in active:
            if s["items"].get("has_more") or s.get("discount") or s.get("discounts"):
                raise ValueError("Subscription adjustments require supported MRR accounting")
            for item in s["items"]["data"]:
                price = item["price"]
                recurring = price.get("recurring")
                if not recurring or recurring.get("usage_type") == "metered" or price.get("unit_amount") is None:
                    raise ValueError("Metered or tiered subscription requires supported accounting")
                interval = recurring["interval"]
                factor = {"month": 1, "year": 1/12, "week": 52/12, "day": 365/12}[interval] / recurring["interval_count"]
                mrr += price["unit_amount"] * item.get("quantity", 1) * factor
        paid = [c for c in charges if c.get("paid") and c.get("status") == "succeeded"]
        gross = sum(c["amount"] for c in paid)
        refunds = sum(c.get("amount_refunded", 0) for c in paid)
        ms = [metric("mrr", "Monthly recurring revenue", round(mrr/100, 2), unit=currency, source="Stripe live subscriptions", definition="Active fixed-price subscriptions normalized to a month. Excludes trials, tax and one-time payments. Unsupported discounts or tiered pricing show unavailable."),
              metric("arr", "Annual recurring revenue", round(mrr*12/100, 2), unit=currency, source="Stripe live subscriptions", definition="Current MRR multiplied by 12, an annualized run rate rather than collected revenue."),
              metric("gross30", "Gross payments", gross/100, unit=currency, source="Stripe live charges", period="Last 30 days", definition="Successful charges created in this rolling window, before refunds and fees. Taxes can be included."),
              metric("refunds30", "Refunds on those payments", refunds/100, unit=currency, source="Stripe live charges", period="Last 30 days", definition="Refunded amounts on charges created in this window, not all refunds issued during the window."),
              metric("after_refunds", "Payments after refunds", (gross-refunds)/100, unit=currency, source="Stripe live charges", period="Last 30 days", definition="Gross payments minus refunds on those payments, before processing fees. Not accounting net revenue."),
              metric("paying", "Paying customers", len({s["customer"] for s in active}), source="Stripe live subscriptions", definition="Distinct customers with active subscriptions. Excludes one-time purchasers."),
              metric("subscriptions", "Active subscriptions", len(active), source="Stripe live subscriptions"),
              metric("past_due", "Past-due subscriptions", sum(s["status"] == "past_due" for s in subs), source="Stripe live subscriptions")]
        ms.extend(unavailable[8:])
        return {"metrics": ms, "connected": True, "note": "Stripe only. App Store revenue, expenses and bank balances are not connected. All amounts retain their source currency."}

    async def health(self):
        async def check(identity, label, url):
            start = time.monotonic()
            try:
                response = await self.client.get(url, timeout=8)
                return dict(id=identity, label=label, healthy=200 <= response.status_code < 400,
                            latency_ms=round((time.monotonic()-start)*1000), at=now())
            except httpx.HTTPError:
                return dict(id=identity, label=label, healthy=False, latency_ms=None, at=now())
        checks = await asyncio.gather(check("api", "Backend API", "http://127.0.0.1:8000/health"),
                                      check("database", "Database connection", "http://127.0.0.1:8000/health/db"),
                                      check("web", "Web application", "http://127.0.0.1:3000/"))
        disk = shutil.disk_usage("/")
        storage = storage_status(disk)
        cleanup = storage['cleanup']
        checks.append(dict(id="upload_storage", label="Upload storage", healthy=storage['level'] == 'healthy', latency_ms=None, at=now()))
        ms = [metric("disk", "Server disk used", storage['used_percent'], unit="percent", source="Current server filesystem",
                     definition="Capacity unavailable to uploads, including filesystem reserves. Warning at 80% used or 5 GiB free. Critical at 90% used or 2 GiB free."),
              metric("disk_free", "Space available for uploads", round(disk.free/GIB, 1), unit="GiB", source="Current server filesystem",
                     definition="Free space shared by uploads, saved photos, database, logs and deployed services. This is not a per-user upload allowance."),
              metric("disk_total", "Server capacity", round(disk.total/GIB, 1), unit="GiB", source="Current server filesystem"),
              metric("storage_cleanup", "Automatic cache cleanup", "On" if cleanup['status'] == 'ok' else "Check", source="Hourly cleanup receipt",
                     definition="Runs hourly and removes only inactive website compiler caches untouched for at least 24 hours. Active releases, photos, inventory, databases and backups are excluded. A missing, failed or more than two-hour-old result opens an issue.",
                     note="Hourly. Old build caches only." if cleanup['status'] == 'ok' else "Cleanup needs attention. See Issues."),
              metric("storage_cleanup_removed", "Build cache removed", round(cleanup['removed_bytes']/GIB, 2) if cleanup['removed_bytes'] is not None else None,
                     unit="GiB", source="Cleanup file allocation count", period="Latest cleanup: " + (cleanup['at'] or "Unavailable"),
                     definition="Allocated size of compiler cache files removed in the latest hourly run. Zero means nothing eligible needed removal. Filesystem free space may change independently."),
              metric("storage_capacity", "Storage upgrade", "Plan" if storage['level'] != 'healthy' else "OK", source="Current server capacity thresholds",
                     definition="If storage stays above 80% used or below 5 GiB free after cleanup, increase the server volume through the hosting provider. This dashboard does not purchase or resize storage.",
                     note="Review capacity after cleanup." if storage['level'] != 'healthy' else "No capacity alert right now."),
              metric("uptime", "Historical availability", definition="Monitoring history starts when this dashboard is installed. A current healthy probe is not historical uptime."),
              metric("api_latency", "Customer API latency", definition="Health-check response times do not measure real customer endpoint latency."),
              metric("backups", "Verified backup status", definition="Backup verification records are not connected."),
              metric("ssl", "Public SSL expiry", definition="Certificate inventory is not connected."),
              metric("storage", "Object storage use", definition="Storage capacity telemetry is not connected.")]
        return dict(checks=checks, metrics=ms, storage=storage)


async def journal_summary():
    """Return categories and counts, never raw customer or exception text."""
    import json
    process = await asyncio.create_subprocess_exec("journalctl", "-u", "findez", "--since", "24 hours ago",
                                                  "-n", "20000", "-o", "json", "--no-pager",
                                                  stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
    try:
        output, _ = await asyncio.wait_for(process.communicate(), timeout=6)
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        raise
    if process.returncode:
        raise RuntimeError("Service logs are unavailable")
    requests, errors, categories = 0, 0, Counter()
    events = []
    lines = output.splitlines()
    for line in lines:
        try:
            entry = json.loads(line)
            message = entry.get("MESSAGE", "")
            match = re.search(r'HTTP/1\.[01]"\s+(\d{3})\b', message)
            if match:
                requests += 1
                errors += int(match[1]) >= 500
            category = None
            if re.search(r"\b429\b|rate.limit", message, re.I):
                category = "Rate limit event"
            elif re.search(r"\b5\d\d\b", match[1] if match else ""):
                category = "Backend request failed"
            elif "Traceback (most recent call last)" in message or re.search(r"\bERROR\b", message):
                category = "Application error recorded"
            elif "[SECURITY]" in message:
                category = "Authentication security event"
            if category:
                categories[category] += 1
                stamp = datetime.fromtimestamp(int(entry["__REALTIME_TIMESTAMP"])/1e6, timezone.utc).isoformat()
                events.append(dict(id="log:" + entry.get("__CURSOR", stamp), at=stamp, category="Diagnostics",
                                   severity="warning" if category != "Backend request failed" else "critical",
                                   title=category, detail="Raw log text is withheld to protect customer data."))
        except (KeyError, ValueError, TypeError):
            continue
    capped = len(lines) >= 20000
    return dict(requests=requests, errors=errors, error_rate=round(errors/requests*100, 2) if requests and not capped else None,
                categories=dict(categories), events=events[-100:], partial=capped,
                note="Last 24 hours of backend service logs, up to 20,000 lines. Completed HTTP access records only. Streaming failures and missing log records can be absent.")
