'use client';
import { useEffect, useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { AppShell } from '@/components/site/app-shell';
import { getActiveCheckouts, returnItem } from '@/lib/api';

const FONT = { fontFamily: 'DM Sans, sans-serif' };

const AVATAR_COLORS = [
  '#0A84FF', '#30D158', '#FF9F0A', '#FF375F', '#BF5AF2', '#5E5CE6',
];

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
  const [checkouts, setCheckouts] = useState<Checkout[]>([]);
  const [loading, setLoading] = useState(true);
  const [returning, setReturning] = useState<string | null>(null);

  useEffect(() => { load(); }, []);

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
    if (!confirm(`Mark "${itemName}" as returned?`)) return;
    setReturning(checkoutId);
    try {
      const sb = createSupabaseBrowserClient();
      const { data: { session } } = await sb.auth.getSession();
      if (!session) return;
      await returnItem({ token: session.access_token, checkoutId });
      await load();
    } catch {
      alert('Failed to return item. Please try again.');
    } finally {
      setReturning(null);
    }
  }

  return (
    <AppShell>
      <div style={{ maxWidth: 640, margin: '0 auto', padding: '32px 24px', ...FONT }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <div>
            <h1 style={{ color: '#fff', fontSize: 24, fontWeight: 700, margin: 0 }}>Check-Out Tracker</h1>
            <p style={{ color: 'rgba(255,255,255,0.45)', fontSize: 13, margin: '4px 0 0' }}>
              Items currently checked out
            </p>
          </div>
          <button
            onClick={load}
            style={{ background: 'rgba(255,255,255,0.06)', color: 'rgba(255,255,255,0.6)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, padding: '8px 16px', fontSize: 13, cursor: 'pointer' }}
          >
            Refresh
          </button>
        </div>

        {loading ? (
          <div style={{ color: 'rgba(255,255,255,0.45)', textAlign: 'center', padding: 40 }}>Loading...</div>
        ) : checkouts.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 0' }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
            <p style={{ color: '#fff', fontSize: 18, fontWeight: 600 }}>Nothing checked out</p>
            <p style={{ color: 'rgba(255,255,255,0.45)', fontSize: 14 }}>Check out items from any item&apos;s detail view.</p>
          </div>
        ) : (
          <>
            {/* Summary banner */}
            <div style={{
              background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 14, padding: '14px 16px', marginBottom: 24,
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <span style={{ fontSize: 18 }}>↔️</span>
              <span style={{ color: '#fff', fontSize: 14, fontWeight: 500 }}>
                {checkouts.length} item{checkouts.length !== 1 ? 's' : ''} currently checked out
              </span>
            </div>

            {/* Section label */}
            <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: 600, letterSpacing: '1.4px', marginBottom: 10 }}>
              CURRENTLY OUT
            </div>

            {/* Checkout cards */}
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
                <div
                  key={checkoutId}
                  style={{
                    background: overdue ? 'rgba(239,68,68,0.04)' : 'rgba(255,255,255,0.05)',
                    border: `1px solid ${overdue ? 'rgba(239,68,68,0.2)' : 'rgba(255,255,255,0.08)'}`,
                    borderRadius: 14, padding: 16, marginBottom: 8,
                    display: 'flex', alignItems: 'center', gap: 12,
                  }}
                >
                  {/* Avatar */}
                  <div style={{
                    width: 40, height: 40, borderRadius: '50%', flexShrink: 0,
                    background: checkedOutBy ? avatarColor(checkedOutBy) : '#636366',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: '#fff', fontWeight: 700, fontSize: 16,
                  }}>
                    {checkedOutBy ? checkedOutBy[0].toUpperCase() : '?'}
                  </div>

                  {/* Info */}
                  <div style={{ flex: 1 }}>
                    <div style={{ color: '#fff', fontSize: 14, fontWeight: 600 }}>{itemName}</div>
                    <div style={{ color: 'rgba(255,255,255,0.45)', fontSize: 12, marginTop: 2 }}>
                      Checked out by {checkedOutBy} · {timeAgo(checkedOutAt)}
                    </div>
                    {location && (
                      <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11 }}>From: {location}</div>
                    )}
                    {dueBackAt && (
                      <div style={{ color: overdue ? '#EF4444' : '#FBBF24', fontSize: 11, fontWeight: 500, marginTop: 2 }}>
                        {overdue ? `⚠ Overdue — was due ${timeAgo(dueBackAt)}` : `Due back ${timeAgo(dueBackAt)}`}
                      </div>
                    )}
                  </div>

                  {/* Return button */}
                  <button
                    onClick={() => handleReturn(checkoutId, itemName)}
                    disabled={returning === checkoutId}
                    style={{
                      background: 'rgba(255,255,255,0.06)', color: '#fff', border: '1px solid rgba(255,255,255,0.08)',
                      borderRadius: 10, padding: '8px 14px', fontSize: 12, fontWeight: 600,
                      cursor: returning === checkoutId ? 'not-allowed' : 'pointer', flexShrink: 0,
                      opacity: returning === checkoutId ? 0.5 : 1,
                    }}
                  >
                    {returning === checkoutId ? '…' : 'Return'}
                  </button>
                </div>
              );
            })}
          </>
        )}
      </div>
    </AppShell>
  );
}
