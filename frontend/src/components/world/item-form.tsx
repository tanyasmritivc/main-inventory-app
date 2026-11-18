'use client';
import { useRef, useState, type FormEvent } from 'react';
import { accountRequest } from '@/lib/account-request';
import { ApiError } from '@/lib/api';
import type { Room, WorldItem } from './types';

export function ItemForm({ accountId, room, saved, onBusy }: { accountId: string; room: Room; saved(itemId: string, added: boolean): Promise<void>; onBusy(value: boolean): void }) {
  const [name, setName] = useState(''), [quantity, setQuantity] = useState('1'), [spot, setSpot] = useState('');
  const [areaName, setAreaName] = useState(''), [kind, setKind] = useState('shelf');
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [uncertain, setUncertain] = useState(false);
  const created = useRef<{ item_id: string; bin_id?: string | null } | null>(null);
  const areaId = useRef<string | null>(null), submitted = useRef(false);
  const freshIds = useRef(new Set<string>()), newItem = useRef(true), placed = useRef(false);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (submitted.current || uncertain) return;
    submitted.current = true; setBusy(true); onBusy(true); setError('');
    try {
      if (!created.current) {
        const fresh = await accountRequest<{ spaces: Room[] }>(accountId, '/world/spaces');
        const actual = fresh.spaces.find(s => s.id === room.id);
        if (!actual?.can_edit) throw new Error('You can no longer add items to this Space. Reload World.');
        if (actual.capped) throw new Error('This Space has more than 400 items. Add through your full inventory so existing records can be checked.');
        freshIds.current = new Set(actual.items.map(i => i.id));
      }
      let destination = spot;
      if (!created.current) {
        try {
          const result = await accountRequest<{ item: { item_id: string; bin_id?: string | null } }>(accountId, `/inventories/${room.inventory_id}/add_item`, {
            method: 'POST', body: { name: name.trim(), category: 'Other', quantity: Number(quantity), location: room.name },
          });
          created.current = result.item;
          newItem.current = !freshIds.current.has(result.item.item_id);
        } catch (failure) {
          // Existing item creation is not retry-safe. Reconcile in inventory before another create.
          setUncertain(!(failure instanceof ApiError && failure.status >= 400 && failure.status < 500)); throw failure;
        }
      }
      if (spot === 'new' && newItem.current) {
        areaId.current ||= crypto.randomUUID();
        await accountRequest(accountId, `/world/spaces/${room.id}/storage-areas`, { method: 'POST', body: { id: areaId.current, name: areaName.trim(), kind } });
        destination = `area:${areaId.current}`;
      }
      if (destination && newItem.current && !placed.current) {
        const [type, id] = destination.split(':');
        await accountRequest(accountId, `/world/placements/${created.current.item_id}`, { method: 'PUT', body: {
          area_id: type === 'area' ? id : null, bin_id: type === 'bin' ? id : null,
          expected_area_id: null, expected_bin_id: created.current.bin_id || null,
        } });
        placed.current = true;
      }
      await saved(created.current.item_id, newItem.current);
    } catch (failure) { setError(failure instanceof Error ? failure.message : 'The item could not be saved.'); }
    finally { submitted.current = false; setBusy(false); onBusy(false); }
  }
  return <form onSubmit={submit}>
    <p className="muted">Add something you actually own to {room.name}.</p>
    <fieldset disabled={busy || !!created.current || uncertain}>
      <label className="lbl" htmlFor="world-item-name">Name</label><input id="world-item-name" type="text" required maxLength={200} value={name} onChange={e => setName(e.target.value)} />
      <label className="lbl" htmlFor="world-item-quantity">Quantity</label><input className="world-field" id="world-item-quantity" type="number" required min="0" max="100000" step="1" value={quantity} onChange={e => setQuantity(e.target.value)} />
      <label className="lbl" htmlFor="world-item-spot">Where in this Space?</label><select className="world-select" id="world-item-spot" value={spot} onChange={e => setSpot(e.target.value)}>
        <option value="">No storage area yet</option>{room.storage_areas.map(a => <option key={a.id} value={`area:${a.id}`}>{a.name}</option>)}{room.bins.map(b => <option key={b.id} value={`bin:${b.id}`}>{b.name}</option>)}<option value="new">New storage area...</option>
      </select>
      {spot === 'new' && <><label className="lbl" htmlFor="world-area-name">Storage area name</label><input id="world-area-name" type="text" required maxLength={100} value={areaName} onChange={e => setAreaName(e.target.value)} /><label className="lbl" htmlFor="world-area-kind">Type</label><select className="world-select" id="world-area-kind" value={kind} onChange={e => setKind(e.target.value)}>{['shelf', 'drawer', 'cabinet', 'container', 'other'].map(k => <option key={k}>{k}</option>)}</select></>}
    </fieldset>
    {error && <p role="alert" className="world-error">{error}</p>}
    {uncertain ? <p className="muted">Check your inventory before adding again: the request may have reached the server. Close this card and reload World to see the latest items.</p> : <button className="btn" disabled={busy || !name.trim()}>{busy ? 'Saving...' : created.current ? 'Finish saving item' : 'Add item'}</button>}
  </form>;
}

export function placementBody(item: WorldItem, destination: { kind: 'bin' | 'area'; id: string } | null) {
  return { area_id: destination?.kind === 'area' ? destination.id : null, bin_id: destination?.kind === 'bin' ? destination.id : null,
    expected_area_id: item.area_id || null, expected_bin_id: item.bin_id || null };
}
