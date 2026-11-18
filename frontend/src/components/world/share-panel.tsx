'use client';
import { useEffect, useRef, useState } from 'react';
import { accountRequest } from '@/lib/account-request';
import type { Share } from './types';

export function SharePanel({ accountId, spaceId }: { accountId: string; spaceId: string }) {
  const [shares, setShares] = useState<Share[] | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [copied, setCopied] = useState('');
  const requestId = useRef<string | null>(null), pending = useRef(false);
  useEffect(() => {
    let active = true;
    accountRequest<{ shares: Share[] }>(accountId, `/world/shares?space=${spaceId}`).then(r => { if (active) setShares(r.shares); }).catch(e => { if (active) setError(e.message); });
    return () => { active = false; };
  }, [accountId, spaceId]);
  async function change(id?: string, body?: Record<string, unknown>) {
    if (pending.current) return; pending.current = true; setBusy(true); setError('');
    try {
      requestId.current ||= crypto.randomUUID();
      const result = await accountRequest<{ share: Share }>(accountId, id ? `/world/shares/${id}` : '/world/shares', { method: id ? 'PATCH' : 'POST', body: body || { space_id: spaceId, request_id: requestId.current } });
      setShares(rows => [...(rows || []).filter(s => s.id !== result.share.id), result.share]);
      if (!id) requestId.current = null;
    } catch (e) { setError(e instanceof Error ? e.message : 'The sharing settings could not be saved.'); }
    finally { pending.current = false; setBusy(false); }
  }
  return <><p className="muted">Anyone with the link can explore this Space. Counts, locations and photos stay hidden unless you enable them.</p>
    {error && <p className="world-error" role="alert">{error}</p>}
    {shares === null ? <p role="status">Loading links...</p> : <>
      {shares.filter(s => !s.revoked_at).map(share => <div className="world-share" key={share.id}>
        {(['counts', 'locations', 'photos'] as const).map(key => <label key={key}><input type="checkbox" checked={share[`show_${key}`]} disabled={busy} onChange={e => void change(share.id, { [`show_${key}`]: e.target.checked })} /> Show {key}</label>)}
        <div className="row"><button className="btn sm" disabled={busy} onClick={() => { void navigator.clipboard.writeText(`${location.origin}/world/s/${share.token}`).then(() => setCopied(share.id)).catch(() => setError('Clipboard access is unavailable. Open the link and copy its address.')); }}>{copied === share.id ? 'Copied' : 'Copy link'}</button>
          <a className="btn sm ghost" href={`/world/s/${share.token}`} target="_blank" rel="noreferrer">Open</a><button className="btn sm ghost" disabled={busy} onClick={() => void change(share.id, { revoke: true })}>Revoke</button></div>
      </div>)}
      <button className="btn" disabled={busy} onClick={() => void change()}>{busy ? 'Saving...' : 'Create view-only link'}</button>
    </>}
  </>;
}
