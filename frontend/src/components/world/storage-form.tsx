'use client';
import { useRef, useState } from 'react';
import { accountRequest } from '@/lib/account-request';
export function StorageForm({ accountId, spaceId, saved, onBusy }: { accountId: string; spaceId: string; saved(): Promise<void>; onBusy(value: boolean): void }) {
  const [name, setName] = useState(''), [kind, setKind] = useState('shelf'), [busy, setBusy] = useState(false), [error, setError] = useState('');
  const id = useRef<string | null>(null), pending = useRef(false);
  return <form onSubmit={event => {
    event.preventDefault(); if (pending.current) return;
    pending.current = true; setBusy(true); onBusy(true); setError(''); id.current ||= crypto.randomUUID();
    void accountRequest(accountId, `/world/spaces/${spaceId}/storage-areas`, { method: 'POST', body: { id: id.current, name: name.trim(), kind } })
      .then(saved).catch(e => setError(e instanceof Error ? e.message : 'The storage area could not be saved.'))
      .finally(() => { pending.current = false; setBusy(false); onBusy(false); });
  }}><p className="muted">Name a real shelf, drawer or cabinet inside this Space. Drag an item onto it to assign its storage area.</p>
    <label className="lbl" htmlFor="world-storage-name">Name</label><input id="world-storage-name" type="text" required maxLength={100} value={name} disabled={busy} onChange={e => setName(e.target.value)} />
    <label className="lbl" htmlFor="world-storage-kind">Type</label><select id="world-storage-kind" value={kind} disabled={busy} onChange={e => setKind(e.target.value)}>{['shelf', 'drawer', 'cabinet', 'container', 'other'].map(value => <option key={value}>{value}</option>)}</select>
    {error && <p className="world-error" role="alert">{error}</p>}<button className="btn" disabled={busy || !name.trim()}>{busy ? 'Saving...' : 'Add storage area'}</button>
  </form>;
}
