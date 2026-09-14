'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, Clock3, RefreshCw, RotateCcw } from 'lucide-react';

import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { AppShell } from '@/components/site/app-shell';
import { getActiveCheckouts, returnItem } from '@/lib/api';
import { useAppDialog } from '@/components/site/app-dialog-provider';

const AVATAR_COLORS = ['#4D8063', '#728A76', '#8DB29D', '#315E47', '#668074', '#57705F'];

function avatarColor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length];
}

function timeAgo(dateStr?: string): string {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

function isOverdue(dueBackAt?: string): boolean {
  if (!dueBackAt) return false;
  return Date.now() > new Date(dueBackAt).getTime();
}

type Checkout = Record<string, unknown>;

export default function CheckoutPage() {
  const { confirmAction, showNotice } = useAppDialog();
  const [checkouts, setCheckouts] = useState<Checkout[]>([]);
  const [loading, setLoading] = useState(true);
  const [returning, setReturning] = useState<string | null>(null);

  useEffect(() => { void load(); }, []);

  async function load() {
    setLoading(true);
    try {
      const sb = createSupabaseBrowserClient();
      const { data: { session } } = await sb.auth.getSession();
      if (!session) return;
      const res = await getActiveCheckouts({ token: session.access_token });
      setCheckouts((res.checkouts ?? []) as Checkout[]);
    } finally {
      setLoading(false);
    }
  }

  async function handleReturn(checkoutId: string, itemName: string) {
    if (!await confirmAction({ title: `Return “${itemName}”?`, message: 'This marks the item as back in inventory.', confirmLabel: 'Mark returned' })) return;
    setReturning(checkoutId);
    try {
      const sb = createSupabaseBrowserClient();
      const { data: { session } } = await sb.auth.getSession();
      if (!session) return;
      await returnItem({ token: session.access_token, checkoutId });
      await load();
    } catch {
      await showNotice({ title: 'Item not returned', message: 'The item could not be marked as returned. Please try again.' });
    } finally {
      setReturning(null);
    }
  }

  return (
    <AppShell>
      <section className="product-page checkout-page">
        <header className="product-page-header">
          <div><h1>Check-outs</h1><p>See what is away from its usual location and who has it.</p></div>
          <button className="product-button" type="button" onClick={() => void load()} disabled={loading}><RefreshCw size={14} /> Refresh</button>
        </header>

        {loading ? (
          <div className="product-empty product-card"><span>Loading check-outs…</span></div>
        ) : checkouts.length === 0 ? (
          <div className="checkout-empty product-card">
            <span><CheckCircle2 size={23} /></span>
            <div><strong>Everything is accounted for</strong><p>Items checked out from their detail view will appear here until they are returned.</p></div>
          </div>
        ) : (
          <div className="checkout-ledger product-card">
            <header><span><Clock3 size={15} /> Currently out</span><strong>{checkouts.length}</strong></header>
            <div className="checkout-table-head"><span>Item</span><span>Checked out by</span><span>Due</span><span /></div>
            {checkouts.map((co) => {
              const itemData = (co.items ?? {}) as Record<string, unknown>;
              const itemName = (itemData.name as string) ?? 'Unknown item';
              const location = (itemData.location as string) ?? '';
              const checkedOutBy = (co.checked_out_by as string) ?? '';
              const checkedOutAt = co.checked_out_at as string | undefined;
              const dueBackAt = co.due_back_at as string | undefined;
              const checkoutId = (co.checkout_id as string) ?? '';
              const overdue = isOverdue(dueBackAt);

              return (
                <article className={overdue ? 'is-overdue' : ''} key={checkoutId}>
                  <div className="checkout-item"><strong>{itemName}</strong><small>{location || 'No saved location'}</small></div>
                  <div className="checkout-person"><span style={{ background: checkedOutBy ? avatarColor(checkedOutBy) : '#6f695f' }}>{checkedOutBy ? checkedOutBy[0].toUpperCase() : '?'}</span><div><strong>{checkedOutBy || 'Unknown'}</strong><small>{timeAgo(checkedOutAt)}</small></div></div>
                  <div className={`checkout-due ${overdue ? 'overdue' : ''}`}>{dueBackAt ? (overdue ? `Overdue · ${timeAgo(dueBackAt)}` : timeAgo(dueBackAt)) : 'No due date'}</div>
                  <button className="product-button" type="button" onClick={() => void handleReturn(checkoutId, itemName)} disabled={returning === checkoutId}><RotateCcw size={13} /> {returning === checkoutId ? 'Returning…' : 'Return'}</button>
                </article>
              );
            })}
          </div>
        )}
      </section>
    </AppShell>
  );
}
