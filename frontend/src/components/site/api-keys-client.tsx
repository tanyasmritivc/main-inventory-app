"use client";

import Link from "next/link";
import { FormEvent, useCallback, useEffect, useRef, useState } from "react";
import { useApiSession } from "@/lib/use-api-session";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { apiBase } from "@/lib/api";
import {
  createIntegrationKey, integrationKeyStatus, listIntegrationKeys, listKeyWorkspaces,
  revokeIntegrationKey, testIntegrationKey,
  type IntegrationKey, type KeyScope, type KeyWorkspace,
} from "@/lib/integration-api";
import styles from "./api-keys-client.module.css";

const WORKSPACE_SCOPES: { value: KeyScope; title: string; detail: string }[] = [
  { value: "items:read", title: "Read inventory", detail: "List items and query quantities." },
  { value: "workspace:read", title: "Read workspace summary", detail: "List locations and inventory counts." },
  { value: "items:write", title: "Create and update items", detail: "Change inventory in linked Spaces." },
  { value: "import:write", title: "Bulk import", detail: "Sync items using external identifiers." },
];
const ORG_SCOPES: typeof WORKSPACE_SCOPES = [
  { value: "org:read", title: "Read all owned workspaces", detail: "Read inventory and summaries across workspaces you own." },
  { value: "org:write", title: "Write to all owned workspaces", detail: "Create, update, and bulk import items across workspaces you own." },
];
const message = (error: unknown) => error instanceof Error ? error.message : "The request failed. Please try again.";
const date = (value: string | null) => value ? new Date(value).toLocaleString() : "Never";

export function ApiKeysClient() {
  const session = useApiSession();
  if (!session.accountId || !session.token) return <div className={styles.page}>
    <Link href="/settings">Settings</Link><h1>API keys</h1>
    {session.loading ? <p role="status">Loading API keys...</p> :
      <p role="alert">{session.error || "Sign in to manage API keys."} <Link href="/signin?redirect=/settings/api-keys">Sign in</Link></p>}
  </div>;
  return <AccountApiKeys key={session.accountId} session={session} />;
}

function AccountApiKeys({ session }: { session: ReturnType<typeof useApiSession> }) {
  const { token, accountId, loading: sessionLoading, error: sessionError, supabase } = session;
  const { confirmAction } = useAppDialog();
  const [keys, setKeys] = useState<IntegrationKey[]>([]);
  const [workspaces, setWorkspaces] = useState<KeyWorkspace[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState("");
  const [workspace, setWorkspace] = useState("");
  const [scopes, setScopes] = useState<KeyScope[]>(["items:read", "workspace:read"]);
  const [expiry, setExpiry] = useState("90");
  // The raw credential lives only in component memory and is removed on dismiss
  // or unmount. Never put it in URLs, persisted storage, or the saved key list.
  const [secret, setSecret] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [testResult, setTestResult] = useState<string | null>(null);
  const [testing, setTesting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const secretRef = useRef<HTMLInputElement>(null);
  const mutationLock = useRef(false);
  const active = useRef(true);
  const loadGeneration = useRef(0);
  const [secretId, setSecretId] = useState<string | null>(null);
  useEffect(() => {
    active.current = true;
    return () => { active.current = false; loadGeneration.current++; };
  }, []);
  const freshToken = useCallback(async () => {
    const { data, error: authError } = await supabase.auth.getSession();
    if (!active.current || authError || !data.session || data.session.user.id !== accountId)
      throw new Error("Your account session changed. Sign in again.");
    return data.session.access_token;
  }, [supabase, accountId]);

  const load = useCallback(async () => {
    if (!token) return;
    const generation = ++loadGeneration.current;
    setLoading(true); setLoadError(null);
    try {
      const currentToken = await freshToken();
      const [keyData, workspaceData] = await Promise.all([listIntegrationKeys(currentToken), listKeyWorkspaces(currentToken)]);
      if (!active.current || generation !== loadGeneration.current) return;
      setKeys(keyData.keys); setWorkspaces(workspaceData.workspaces);
      setWorkspace((current) => current === "organization" || workspaceData.workspaces.some((entry) => entry.team_id === current) ? current : workspaceData.workspaces[0]?.team_id || "");
    } catch (reason) { if (active.current && generation === loadGeneration.current) setLoadError(message(reason)); }
    finally { if (active.current && generation === loadGeneration.current) setLoading(false); }
  }, [token, freshToken]);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { if (secret) secretRef.current?.focus(); }, [secret]);

  function chooseWorkspace(value: string) {
    setWorkspace(value);
    setScopes(value === "organization" ? ["org:read"] : ["items:read", "workspace:read"]);
  }

  async function create(event: FormEvent) {
    event.preventDefault();
    if (mutationLock.current || secret) return;
    mutationLock.current = true; setBusy(true); setError(null); setNotice(null);
    try {
      const result = await createIntegrationKey(await freshToken(), {
        name: name.trim(), workspace_id: workspace === "organization" ? null : workspace,
        scopes, expires_at: expiry === "never" ? null : new Date(Date.now() + Number(expiry) * 86400000).toISOString(),
      });
      if (!active.current) return;
      const { key: rawKey, ...metadata } = result;
      setSecretId(metadata.id);
      setSecret(rawKey); setKeys((current) => [metadata, ...current]);
      setName(""); setCopied(false); setTestResult(null);
    } catch (reason) { setError(message(reason)); }
    finally { mutationLock.current = false; setBusy(false); }
  }

  async function copySecret() {
    if (!secret) return;
    try { await navigator.clipboard.writeText(secret); setCopied(true); }
    catch { setError("Copy was unavailable. Select the key and copy it manually."); secretRef.current?.select(); }
  }

  async function testSecret() {
    if (!secret || testing) return;
    setTesting(true); setTestResult(null); setError(null);
    try { setTestResult(await testIntegrationKey(secret)); }
    catch (reason) { setError(message(reason)); }
    finally { setTesting(false); }
  }

  async function revoke(key: IntegrationKey) {
    if (mutationLock.current || !await confirmAction({
      title: `Revoke “${key.name}”?`, message: "Software using this key will immediately lose access. Create a replacement key if needed.",
      confirmLabel: "Revoke key", danger: true,
    })) return;
    if (!active.current || mutationLock.current) return;
    mutationLock.current = true; setBusy(true); setError(null);
    try {
      const result = await revokeIntegrationKey(await freshToken(), key.id);
      if (!active.current) return;
      if (secretId === key.id) { setSecret(null); setSecretId(null); setTestResult(null); }
      setKeys((current) => current.map((entry) => entry.id === key.id ? { ...entry, revoked_at: result.revoked_at } : entry));
      setNotice(`“${key.name}” was revoked.`);
    } catch (reason) { setError(message(reason)); }
    finally { mutationLock.current = false; setBusy(false); }
  }

  const example = `curl -X POST '${apiBase().replace(/\/$/, "")}/api/v1/query' -H 'Authorization: Bearer YOUR_API_KEY' -H 'Content-Type: application/json' -d '{"resource":"items","filters":[{"field":"part_number","op":"eq","value":"5202"}],"aggregate":"sum_quantity"}'`;

  return <div className={styles.page}>
    <Link href="/settings" className={styles.back}>← Settings</Link>
    <h1>API keys</h1>
    <p className={styles.intro}>Connect a spreadsheet, automation, or AI assistant to your workspace inventory.</p>
    <p><Link className={styles.link} href="/docs/api">Read the API documentation →</Link></p>
    <p><Link className={styles.link} href="/docs/api#ai-assistants">Connect Claude or ChatGPT →</Link></p>
    {sessionError && <p role="alert" className={styles.error}>{sessionError} <Link href="/signin?redirect=/settings/api-keys">Sign in</Link></p>}
    {(sessionLoading || (loading && !sessionError)) && <p role="status">Loading API keys…</p>}
    {loadError && <p role="alert" className={styles.error}>{loadError} <button onClick={() => void load()}>Retry</button></p>}
    {error && <p role="alert" className={styles.error}>{error}</p>}
    {notice && <p role="status">{notice}</p>}

    {secret && <section className={styles.card} aria-labelledby="new-key-title">
      <h2 id="new-key-title">Save your key now</h2>
      <p>This is the only time FindEZ can show it. Store it securely in the software that will use it.</p>
      <label htmlFor="new-api-key">Your new API key</label>
      <input id="new-api-key" ref={secretRef} readOnly value={secret} autoComplete="off" spellCheck={false} onFocus={(event) => event.target.select()} className={styles.secret} />
      <div className={styles.actions}>
        <button onClick={() => void copySecret()}>{copied ? "Copied" : "Copy key"}</button>
        <button onClick={() => void testSecret()} disabled={testing}>{testing ? "Testing…" : "Test connection"}</button>
        <button className={styles.primary} disabled={testing} onClick={() => { setSecret(null); setTestResult(null); }}>I’ve saved my key</button>
      </div>
      {testResult && <p role="status" className={styles.success}>{testResult}</p>}
    </section>}

    {!loading && !sessionLoading && !sessionError && !loadError && <>
      {!workspaces.length ? <section className={styles.card}>
        <h2>Create a workspace to use integrations</h2>
        <p>API keys access authorized inventory in owned workspaces. Create a workspace, open an inventory in it, and add a Space. Only the workspace owner can issue keys. Personal inventories and workspaces you only belong to are not available through this API.</p>
        <Link className={styles.link} href="/home">Open your workspaces →</Link>
      </section> : !secret && <form className={styles.card} onSubmit={(event) => void create(event)}>
        <h2>Create an API key</h2>
        <label htmlFor="key-name">Key name</label>
        <input id="key-name" required maxLength={100} value={name} onChange={(event) => setName(event.target.value)} placeholder="e.g. Team spreadsheet" />
        <div className={styles.fields}>
          <div><label htmlFor="key-workspace">Access</label><select id="key-workspace" value={workspace} onChange={(event) => chooseWorkspace(event.target.value)}>
            {workspaces.map((entry) => <option key={entry.team_id} value={entry.team_id}>{entry.name}</option>)}
            <option value="organization">All workspaces I own</option>
          </select></div>
          <div><label htmlFor="key-expiry">Expires in</label><select id="key-expiry" value={expiry} onChange={(event) => setExpiry(event.target.value)}>
            <option value="30">30 days</option><option value="90">90 days</option><option value="365">1 year</option><option value="never">Never</option>
          </select></div>
        </div>
        <fieldset><legend>Permissions</legend>
          {(workspace === "organization" ? ORG_SCOPES : WORKSPACE_SCOPES).map((scope) => <label key={scope.value} className={styles.permission}>
            <input type="checkbox" checked={scopes.includes(scope.value)} onChange={(event) => setScopes((current) => event.target.checked ? [...current, scope.value] : current.filter((value) => value !== scope.value))} />
            <span>{scope.title}<small>{scope.detail}</small></span>
          </label>)}
        </fieldset>
        <p className={styles.hint}>Read access is selected by default. Writes use the exact name of an existing linked Space.</p>
        <button className={styles.primary} disabled={busy || !name.trim() || !scopes.length || !workspace}>{busy ? "Creating…" : "Create key"}</button>
      </form>}

      <section className={styles.card} aria-labelledby="saved-keys-title">
        <div className={styles.sectionHeading}><h2 id="saved-keys-title">Your keys</h2><button disabled={busy} onClick={() => void load()}>Refresh</button></div>
        {!keys.length && <p>No API keys yet.</p>}
        {keys.map((key) => <article key={key.id} className={styles.key}>
          <div className={styles.sectionHeading}><strong>{key.name}</strong><span>{integrationKeyStatus(key)}</span></div>
          <code>{key.key_prefix}…</code>
          <p>{key.workspace_id ? workspaces.find((entry) => entry.team_id === key.workspace_id)?.name ?? "Unavailable workspace" : "All workspaces you own"}</p>
          <p className={styles.scopes}>{key.scopes.join(" · ")}</p>
          <dl><div><dt>Created</dt><dd>{date(key.created_at)}</dd></div><div><dt>Last used</dt><dd>{date(key.last_used_at)}</dd></div><div><dt>Expires</dt><dd>{date(key.expires_at)}</dd></div></dl>
          {!key.revoked_at && <button className={styles.danger} disabled={busy} onClick={() => void revoke(key)}>Revoke {key.name}</button>}
        </article>)}
      </section>
    </>}

    <section className={styles.card}>
      <h2>Make your first query</h2>
      <p>Use a key with read permission. Replace <code>YOUR_API_KEY</code> and the example part number with your values.</p>
      <pre>{example}</pre>
      <p><code>count</code> counts matching item records; <code>sum_quantity</code> adds their quantities. Omit <code>aggregate</code> to return a paginated item list.</p>
      <p className={styles.hint}>Use the <Link href="/docs/api#ai-assistants">Claude Desktop extension or ChatGPT Actions setup</Link> to read, add, update, and import inventory. Enable the matching permissions when creating your key. Neither connection includes deletion.</p>
    </section>
  </div>;
}
