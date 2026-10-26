"use client";
import { useEffect, useState } from "react";
import { RefreshCw } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import type { LimitsResponse } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { currentAccess, usageCount, usagePeriod } from "@/lib/plan-usage";
import { PlanComparison } from "./plan-comparison";
import styles from "./plans-usage.module.css";

function UsageStat({ name, used, max, unmetered, period }: { name: string; used: unknown; max: unknown; unmetered?: boolean; period?: string | null }) {
  const count = usageCount(used), limit = usageCount(max);
  return <section className={styles.stat} aria-label={name}>
    <h3>{name}</h3>
    <p className={styles.statValue} data-unmetered={unmetered || undefined}>{unmetered ? "Not metered" : count === null ? "—" : count.toLocaleString("en-US")}
      {!unmetered && limit !== null && <small> / {limit.toLocaleString("en-US")}</small>}
    </p>
    {!unmetered && count !== null && limit !== null && limit > 0 && <progress aria-label={`${name} allowance used`} value={Math.min(count, limit)} max={limit}/>}
    <p className={styles.statNote}>{unmetered ? "No plan limit in early access" : count === null ? "Count unavailable" : max === null ? "No plan limit" : limit === null ? "Allowance unavailable" : "Current allowance"}{!unmetered && period ? ` · Resets ${period} (UTC)` : ""}</p>
  </section>;
}

export function PlansUsageClient() {
  const { accountId, loading, error } = useApiSession();
  return <div className={styles.page}>
    {accountId ? <AccountUsage key={accountId} accountId={accountId}/> : <>
      <h1>Plans &amp; usage</h1>
      <p role={error ? "alert" : "status"}>{loading ? "Checking your account…" : "Sign in again to view your usage."}</p>
    </>}
  </div>;
}

export function AccountUsage({ accountId }: { accountId: string }) {
  const [data, setData] = useState<LimitsResponse | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [error, setError] = useState(false);
  const [busy, setBusy] = useState(true);
  const [checkedAt, setCheckedAt] = useState<Date | null>(null);
  useEffect(() => {
    const controller = new AbortController();
    let active = true;
    const timer = setTimeout(() => controller.abort(), 15000);
    void accountRequest<LimitsResponse>(accountId, "/me/limits", { signal: controller.signal }).then(result => {
      if (!active || controller.signal.aborted) return;
      if (!result || !["free", "pro", "team_member"].includes(result.tier) || !result.items || !result.spaces || !result.chats || !result.scans) throw new Error("Invalid usage snapshot");
      setData(result); setCheckedAt(new Date());
    }).catch(() => { if (active) setError(true); }).finally(() => {
      clearTimeout(timer);
      if (active) setBusy(false);
    });
    return () => { active = false; clearTimeout(timer); controller.abort(); };
  }, [accountId, attempt]);
  function refresh() { setBusy(true); setError(false); setData(null); setAttempt(n => n + 1); }
  return <>
    <header className={styles.header}>
      <div><h1>Plans &amp; usage</h1><p>Your account, at a glance.</p></div>
      <button type="button" className={styles.secondary} disabled={busy} onClick={refresh} aria-label="Refresh usage"><RefreshCw size={15} aria-hidden="true"/>Refresh</button>
    </header>
    {busy && <p className={styles.muted} role="status">Loading usage…</p>}
    {error && <div className={styles.error} role="alert"><p>Usage couldn’t be loaded. Your access hasn’t changed.</p><button className={styles.secondary} onClick={refresh}>Try again</button></div>}
    {data && <UsageOverview data={data} checkedAt={checkedAt}/>}
    <section className={styles.plans} aria-labelledby="compare-plans-heading">
      <h2 className={styles.sectionTitle} id="compare-plans-heading">Compare plans</h2>
      <PlanComparison signedIn/>
      <p className={styles.footnote}>Planned allowances apply when subscriptions launch. No payment is taken here. Need a larger team? <a href="mailto:info@findez.ai?subject=FindEZ%20larger%20team">Contact us</a>.</p>
    </section>
  </>;
}

export function UsageOverview({ data, checkedAt }: {data: LimitsResponse; checkedAt: Date | null}) {
  const pilot = data.pilot_mode === true;
  return <>
      <div className={styles.notice}>
        <div><strong>{currentAccess(data)}</strong><p>{pilot ? "No plan quotas or automatic charges. No scheduled cutoff." : "Current access is shown below. New subscriptions are coming soon."}</p></div>
        <span className={styles.badge}>{pilot ? "Early access" : "Current access"}</span>
      </div>
      <h2 className={styles.sectionTitle}>Usage overview</h2>
      <div className={styles.usage}>
        <UsageStat name="Saved item records" used={data.items.used} max={data.items.max}/>
        <UsageStat name="Spaces" used={data.spaces.used} max={data.spaces.max}/>
        <UsageStat name="AI messages" used={data.chats.used} max={data.chats.max} unmetered={pilot} period={usagePeriod(data.chats.resets_at)}/>
        <UsageStat name="Photo extractions" used={data.scans.used} max={data.scans.max} unmetered={pilot} period={usagePeriod(data.scans.resets_at)}/>
      </div>
      <p className={styles.muted}>Items and Spaces owned by your account. Quantities don’t count as extra records.{pilot ? " AI usage totals aren’t tracked during early access." : " AI counters cover the current monthly allowance."}{checkedAt ? ` Updated ${checkedAt.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}.` : ""}</p>
  </>;
}
