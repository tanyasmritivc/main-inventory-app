'use client';
import { useEffect, useState } from 'react';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';
import { AppShell } from '@/components/site/app-shell';
import { searchItems, type InventoryItem } from '@/lib/api';

const FONT = { fontFamily: 'DM Sans, sans-serif' };

interface ShoppingItem {
  item: InventoryItem;
  suggestedQty: number;
  reason: string;
}

export default function ShoppingListPage() {
  const [items, setItems] = useState<ShoppingItem[]>([]);
  const [checked, setChecked] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    try {
      const sb = createSupabaseBrowserClient();
      const { data: { session } } = await sb.auth.getSession();
      if (!session) return;
      const result = await searchItems({ token: session.access_token, query: '' });

      // Items with qty <= 1 or qty = 0 are low stock
      const low = result.items
        .filter((i: InventoryItem) => i.quantity <= 1)
        .map((i: InventoryItem) => ({
          item: i,
          suggestedQty: i.quantity <= 0 ? 5 : 3,
          reason: i.quantity <= 0 ? 'Out of stock' : `Low stock (${i.quantity} left)`,
        }));
      setItems(low);
    } finally {
      setLoading(false);
    }
  }

  function buildShareText() {
    const bySpace: Record<string, ShoppingItem[]> = {};
    items.filter(i => !checked.has(i.item.item_id)).forEach(si => {
      (bySpace[si.item.location] ??= []).push(si);
    });
    let text = '🛒 FindEZ AI — Shopping List\n\n';
    Object.entries(bySpace).sort(([a], [b]) => a.localeCompare(b)).forEach(([space, sis]) => {
      text += `📦 ${space.toUpperCase()}\n`;
      sis.forEach(si => {
        const pn = si.item.part_number ? ` [${si.item.part_number}]` : '';
        const brand = si.item.brand ? ` — ${si.item.brand}` : '';
        text += `  • ${si.item.name}${pn}${brand}\n`;
        text += `    Qty needed: ${si.suggestedQty}  |  ${si.reason}\n`;
      });
      text += '\n';
    });
    return text;
  }

  const unchecked = items.filter(i => !checked.has(i.item.item_id));
  const checkedItems = items.filter(i => checked.has(i.item.item_id));

  return (
    <AppShell>
      <div style={{ maxWidth: 640, margin: '0 auto', padding: '32px 24px', ...FONT }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <div>
            <h1 style={{ color: '#fff', fontSize: 24, fontWeight: 700, margin: 0 }}>Shopping List</h1>
            <p style={{ color: 'rgba(255,255,255,0.45)', fontSize: 13, margin: '4px 0 0' }}>
              Items that need restocking
            </p>
          </div>
          {items.length > 0 && (
            <button
              onClick={() => { navigator.clipboard.writeText(buildShareText()); }}
              style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 99, padding: '8px 16px', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}
            >
              Copy List
            </button>
          )}
        </div>

        {loading ? (
          <div style={{ color: 'rgba(255,255,255,0.45)', textAlign: 'center', padding: 40 }}>Loading...</div>
        ) : items.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 0' }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
            <p style={{ color: '#fff', fontSize: 18, fontWeight: 600 }}>All stocked up!</p>
            <p style={{ color: 'rgba(255,255,255,0.45)', fontSize: 14 }}>No items are low on stock.</p>
          </div>
        ) : (
          <>
            {/* Summary banner */}
            <div style={{
              background: unchecked.length === 0 ? 'rgba(48,209,88,0.06)' : 'rgba(239,68,68,0.06)',
              border: `1px solid ${unchecked.length === 0 ? 'rgba(48,209,88,0.2)' : 'rgba(239,68,68,0.2)'}`,
              borderRadius: 14, padding: '14px 16px', marginBottom: 24,
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <div style={{ color: unchecked.length === 0 ? '#30D158' : '#fff', fontSize: 14, fontWeight: 600 }}>
                {unchecked.length === 0 ? '🎉 All items ordered!' : `${unchecked.length} items need restocking`}
              </div>
              {unchecked.length > 0 && (
                <button
                  onClick={() => { navigator.clipboard.writeText(buildShareText()); alert('Shopping list copied!'); }}
                  style={{ background: '#fff', color: '#000', border: 'none', borderRadius: 99, padding: '6px 14px', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}
                >
                  Share
                </button>
              )}
            </div>

            {/* Needs restocking */}
            {unchecked.length > 0 && (
              <>
                <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: 600, letterSpacing: '1.4px', marginBottom: 10 }}>
                  NEEDS RESTOCKING
                </div>
                {unchecked.map(si => (
                  <ShoppingItemRow
                    key={si.item.item_id}
                    si={si}
                    checked={false}
                    onToggle={() => setChecked(prev => { const n = new Set(prev); n.add(si.item.item_id); return n; })}
                    onQtyChange={(qty) => setItems(prev => prev.map(i => i.item.item_id === si.item.item_id ? { ...i, suggestedQty: qty } : i))}
                  />
                ))}
              </>
            )}

            {/* Ordered */}
            {checkedItems.length > 0 && (
              <>
                <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 10, fontWeight: 600, letterSpacing: '1.4px', margin: '24px 0 10px' }}>
                  ORDERED
                </div>
                {checkedItems.map(si => (
                  <ShoppingItemRow
                    key={si.item.item_id}
                    si={si}
                    checked={true}
                    onToggle={() => setChecked(prev => { const n = new Set(prev); n.delete(si.item.item_id); return n; })}
                    onQtyChange={() => {}}
                  />
                ))}
              </>
            )}
          </>
        )}
      </div>
    </AppShell>
  );
}

function ShoppingItemRow({ si, checked, onToggle, onQtyChange }: {
  si: ShoppingItem; checked: boolean;
  onToggle: () => void; onQtyChange: (qty: number) => void;
}) {
  return (
    <div
      onClick={onToggle}
      style={{
        background: checked ? 'rgba(255,255,255,0.03)' : 'rgba(255,255,255,0.05)',
        border: `1px solid ${checked ? 'rgba(255,255,255,0.06)' : si.item.quantity <= 0 ? 'rgba(239,68,68,0.2)' : 'rgba(251,191,36,0.2)'}`,
        borderRadius: 14, padding: 14, marginBottom: 8, display: 'flex',
        alignItems: 'center', gap: 12, cursor: 'pointer',
      }}
    >
      {/* Checkbox */}
      <div style={{
        width: 20, height: 20, borderRadius: 6, flexShrink: 0,
        background: checked ? '#30D158' : 'transparent',
        border: `1px solid ${checked ? '#30D158' : 'rgba(255,255,255,0.25)'}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        {checked && <span style={{ color: '#fff', fontSize: 12 }}>✓</span>}
      </div>

      {/* Info */}
      <div style={{ flex: 1 }}>
        <div style={{
          color: checked ? 'rgba(255,255,255,0.35)' : '#fff',
          fontSize: 14, fontWeight: 600,
          textDecoration: checked ? 'line-through' : 'none',
        }}>
          {si.item.name}
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 3, flexWrap: 'wrap', alignItems: 'center' }}>
          <span style={{
            background: si.item.quantity <= 0 ? 'rgba(239,68,68,0.15)' : 'rgba(251,191,36,0.15)',
            color: si.item.quantity <= 0 ? '#EF4444' : '#FBBF24',
            fontSize: 9, fontWeight: 700, padding: '2px 6px', borderRadius: 4,
          }}>
            {si.item.quantity <= 0 ? 'OUT OF STOCK' : `${si.item.quantity} left`}
          </span>
          <span style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11 }}>{si.item.location}</span>
          {si.item.part_number && <span style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11 }}>#{si.item.part_number}</span>}
        </div>
        {!checked && <div style={{ color: 'rgba(255,255,255,0.3)', fontSize: 11, marginTop: 2 }}>{si.reason}</div>}
      </div>

      {/* Qty adjuster */}
      {!checked && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }} onClick={e => e.stopPropagation()}>
          <button
            onClick={() => onQtyChange(Math.max(1, si.suggestedQty - 1))}
            style={{ width: 26, height: 26, borderRadius: 6, background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', cursor: 'pointer', fontSize: 16 }}
          >−</button>
          <span style={{ color: '#fff', fontSize: 14, fontWeight: 600, minWidth: 20, textAlign: 'center' }}>{si.suggestedQty}</span>
          <button
            onClick={() => onQtyChange(si.suggestedQty + 1)}
            style={{ width: 26, height: 26, borderRadius: 6, background: 'rgba(255,255,255,0.06)', border: 'none', color: '#fff', cursor: 'pointer', fontSize: 16 }}
          >+</button>
        </div>
      )}
    </div>
  );
}
