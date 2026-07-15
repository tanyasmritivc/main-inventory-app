"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  getShareMembers,
  getMyShares,
  getJoinedShares,
  removeShareMember,
} from "@/lib/api";

const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

type Member = {
  member_id: string;
  user_id?: string;
  display_name?: string;
  email?: string;
  avatar_color?: string;
  role?: string;
  joined_at?: string;
};

function getInitials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) return ((parts[0]?.[0] ?? '') + (parts[1]?.[0] ?? '')).toUpperCase();
  return name.slice(0, 2).toUpperCase();
}

export function SharedSpaceClient({ shareId }: { shareId: string }) {
  const supabase = createSupabaseBrowserClient();

  const [token, setToken] = useState<string | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [members, setMembers] = useState<Member[]>([]);
  const [items, setItems] = useState<any[]>([]);
  const [spaceName, setSpaceName] = useState('');
  const [permission, setPermission] = useState<'view' | 'edit'>('view');
  const [isOwner, setIsOwner] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [removingMember, setRemovingMember] = useState<string | null>(null);

  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');

  useEffect(() => {
    void init();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [shareId]);

  async function refreshToken(): Promise<string> {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (session?.access_token) {
        setToken(session.access_token);
        return session.access_token;
      }
    } catch (_) {}
    return '';
  }

  async function init() {
    setLoading(true);
    setError(null);
    try {
      const t = await refreshToken();
      if (!t) { setError('Not authenticated.'); setLoading(false); return; }

      const { data: { user } } = await supabase.auth.getUser();
      const userId = user?.id ?? null;
      setCurrentUserId(userId);

      // Resolve space metadata from my shares + joined shares
      const [mySharesRes, joinedRes] = await Promise.all([
        getMyShares({ token: t }),
        getJoinedShares({ token: t }),
      ]);

      const myShare = mySharesRes.shares.find((s) => s.share_id === shareId);
      const joinedShare = joinedRes.shares.find((s) => s.share_id === shareId);

      if (myShare) {
        setSpaceName(myShare.share_name);
        setPermission(myShare.permission as 'view' | 'edit');
        setIsOwner(true);
      } else if (joinedShare) {
        setSpaceName(joinedShare.share_name);
        setPermission(joinedShare.permission as 'view' | 'edit');
        setIsOwner(false);
      } else {
        setError('Space not found or you do not have access.');
        setLoading(false);
        return;
      }

      // Load members + items in parallel
      const [membersRaw, itemsRes] = await Promise.all([
        getShareMembers({ token: t, shareId }),
        fetch(
          `${process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:8000'}/sharing/${shareId}/inventory`,
          { headers: { Authorization: `Bearer ${t}` } }
        ).then((r) => r.json()),
      ]);

      const memberList = (Array.isArray(membersRaw) ? membersRaw : []) as Member[];
      setMembers(memberList);

      // Check ownership from members list (may override the joined-shares detection)
      const me = memberList.find((m) => m.user_id === userId);
      if (me?.role === 'owner') setIsOwner(true);

      setItems(itemsRes?.items ?? (Array.isArray(itemsRes) ? itemsRes : []));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load workspace.');
    } finally {
      setLoading(false);
    }
  }

  async function handleRemoveMember(memberId: string) {
    if (!token || !window.confirm('Remove this member from the space?')) return;
    setRemovingMember(memberId);
    try {
      await removeShareMember({ token, shareId, memberId });
      setMembers((prev) => prev.filter((m) => m.member_id !== memberId));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove member.');
    } finally {
      setRemovingMember(null);
    }
  }

  const categories = useMemo(
    () => Array.from(new Set(items.map((i: any) => i.category).filter(Boolean))).sort() as string[],
    [items]
  );

  const filteredItems = useMemo(() => {
    let result = items;
    if (categoryFilter) result = result.filter((i: any) => i.category === categoryFilter);
    if (search.trim()) {
      const q = search.toLowerCase();
      result = result.filter(
        (i: any) =>
          (i.name ?? '').toLowerCase().includes(q) ||
          (i.category ?? '').toLowerCase().includes(q) ||
          (i.notes ?? '').toLowerCase().includes(q)
      );
    }
    return result;
  }, [items, categoryFilter, search]);

  if (loading) {
    return (
      <div style={{ padding: '48px 40px', fontFamily: FONT }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, maxWidth: 640 }}>
          {[1, 2, 3].map((i) => (
            <div key={i} className="skeleton" style={{ height: 48, borderRadius: 10 }} />
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '48px 40px', fontFamily: FONT }}>
        <Link href="/inventory" style={{ fontSize: 12, color: '#6e6e73', textDecoration: 'none', display: 'block', marginBottom: 20 }}>
          ← My Spaces
        </Link>
        <p style={{ fontSize: 13, color: '#ff453a', margin: 0 }}>{error}</p>
      </div>
    );
  }

  return (
    <div style={{ padding: '32px 40px', maxWidth: '1100px', fontFamily: FONT, WebkitFontSmoothing: 'antialiased' as any }}>

      {/* HEADER */}
      <div style={{ marginBottom: 28 }}>
        <Link
          href="/inventory"
          style={{ fontSize: 12, color: '#6e6e73', textDecoration: 'none', display: 'inline-block', marginBottom: 16 }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = '#a1a1a6'; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = '#6e6e73'; }}
        >
          ← My Spaces
        </Link>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' as const }}>
          <h1 style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.035em', color: '#f5f5f7', margin: 0 }}>
            {spaceName}
          </h1>
          <span style={{
            fontSize: 10, padding: '3px 10px', borderRadius: 99,
            background: isOwner ? 'rgba(50,215,75,0.10)' : 'rgba(100,149,237,0.10)',
            border: `1px solid ${isOwner ? 'rgba(50,215,75,0.20)' : 'rgba(100,149,237,0.20)'}`,
            color: isOwner ? '#32d74b' : '#6495ed',
          }}>
            {isOwner ? 'shared by me' : 'joined space'}
          </span>
          <span style={{
            fontSize: 10, padding: '3px 10px', borderRadius: 99,
            background: 'rgba(255,255,255,0.04)',
            border: '1px solid rgba(255,255,255,0.08)',
            color: '#a1a1a6',
          }}>
            {permission === 'edit' ? 'Can edit' : 'View only'}
          </span>
        </div>

        <p style={{ fontSize: 13, color: '#6e6e73', margin: '6px 0 0', letterSpacing: '-0.01em' }}>
          {items.length} item{items.length !== 1 ? 's' : ''} · {members.length} member{members.length !== 1 ? 's' : ''}
        </p>
      </div>

      {/* MEMBERS */}
      <div style={{ marginBottom: 36 }}>
        <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 14 }}>
          Members
        </div>

        {members.length === 0 ? (
          <div style={{ fontSize: 12, color: '#3a3a3c' }}>No members found.</div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            {members.map((member) => {
              const name = member.display_name || member.email || 'Unknown';
              const isMe = member.user_id === currentUserId;
              return (
                <div
                  key={member.member_id}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '10px 14px',
                    borderRadius: 10,
                    background: 'rgba(255,255,255,0.02)',
                    border: '1px solid rgba(255,255,255,0.05)',
                  }}
                >
                  <div style={{
                    width: 32, height: 32, borderRadius: '50%', flexShrink: 0,
                    background: member.avatar_color ?? '#2c2c2e',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 12, fontWeight: 600, color: '#fff',
                  }}>
                    {getInitials(name)}
                  </div>

                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                      {name}{isMe ? ' (you)' : ''}
                    </div>
                    {member.email && member.display_name && (
                      <div style={{ fontSize: 11, color: '#3a3a3c', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                        {member.email}
                      </div>
                    )}
                  </div>

                  <div style={{ fontSize: 11, color: member.role === 'owner' ? '#32d74b' : '#6e6e73', flexShrink: 0 }}>
                    {member.role === 'owner' ? 'Owner' : 'Member'}
                  </div>

                  {member.joined_at ? (
                    <div style={{ fontSize: 11, color: '#3a3a3c', flexShrink: 0 }}>
                      {new Date(member.joined_at).toLocaleDateString()}
                    </div>
                  ) : null}

                  {isOwner && member.role !== 'owner' && (
                    <button
                      type="button"
                      onClick={() => void handleRemoveMember(member.member_id)}
                      disabled={removingMember === member.member_id}
                      style={{
                        fontSize: 11, color: '#ff453a',
                        background: 'rgba(255,69,58,0.06)', border: '1px solid rgba(255,69,58,0.15)',
                        borderRadius: 5, padding: '3px 10px', cursor: 'pointer', fontFamily: FONT, flexShrink: 0,
                        opacity: removingMember === member.member_id ? 0.5 : 1,
                        transition: 'background 0.12s',
                      }}
                      onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,69,58,0.12)'; }}
                      onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'rgba(255,69,58,0.06)'; }}
                    >
                      {removingMember === member.member_id ? '…' : 'Remove'}
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* ITEMS */}
      <div style={{ marginBottom: 36 }}>
        <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 14 }}>
          Items
        </div>

        <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' as const }}>
          <input
            placeholder="Search items…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ flex: 1, minWidth: 180, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 8, padding: '9px 14px', fontSize: 13, color: '#f5f5f7', outline: 'none', fontFamily: FONT, letterSpacing: '-0.01em' }}
          />
        </div>

        {categories.length > 0 && (
          <div style={{ display: 'flex', flexWrap: 'wrap' as const, gap: 6, marginBottom: 14 }}>
            <button
              type="button"
              onClick={() => setCategoryFilter('')}
              style={{ background: categoryFilter === '' ? '#1c1c1e' : 'rgba(255,255,255,0.03)', color: categoryFilter === '' ? '#fff' : '#6e6e73', border: `1px solid ${categoryFilter === '' ? '#2c2c2e' : 'rgba(255,255,255,0.07)'}`, borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
            >
              All
            </button>
            {categories.map((cat) => (
              <button
                key={cat}
                type="button"
                onClick={() => setCategoryFilter(cat)}
                style={{ background: categoryFilter === cat ? '#1c1c1e' : 'rgba(255,255,255,0.03)', color: categoryFilter === cat ? '#fff' : '#6e6e73', border: `1px solid ${categoryFilter === cat ? '#2c2c2e' : 'rgba(255,255,255,0.07)'}`, borderRadius: 99, padding: '4px 12px', fontSize: 11, cursor: 'pointer', fontFamily: FONT }}
              >
                {cat}
              </button>
            ))}
          </div>
        )}

        {filteredItems.length === 0 ? (
          <div style={{ textAlign: 'center' as const, padding: '40px 24px', background: 'rgba(255,255,255,0.02)', borderRadius: 12, border: '1px dashed rgba(255,255,255,0.08)' }}>
            <div style={{ fontSize: 13, color: '#3a3a3c' }}>
              {items.length === 0 ? 'No items in this space yet.' : 'No items match your search.'}
            </div>
          </div>
        ) : (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 2fr', gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
              {['Name', 'Category', 'Qty', 'Notes'].map((h) => (
                <div key={h} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73' }}>{h}</div>
              ))}
            </div>
            {filteredItems.map((item: any) => (
              <div key={item.item_id} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr 60px 2fr', gap: 12, padding: '11px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
                <div style={{ fontSize: 13, fontWeight: 510, color: '#f5f5f7', letterSpacing: '-0.015em', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                  {item.name}
                </div>
                <div>
                  <span style={{ fontSize: 11, padding: '2px 8px', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 99, color: '#a1a1a6' }}>
                    {item.category ?? '—'}
                  </span>
                </div>
                <div style={{ fontSize: 13, fontWeight: 590, color: item.quantity <= 1 ? '#ffd60a' : '#f5f5f7' }}>
                  {item.quantity}
                </div>
                <div style={{ fontSize: 11, color: '#6e6e73', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const }}>
                  {item.notes ?? '—'}
                </div>
              </div>
            ))}
          </>
        )}
      </div>

      {/* CHECKOUT STATUS — backend task needed */}
      <div style={{ marginBottom: 32 }}>
        <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
          Checked Out Items
          <span style={{ fontSize: 9, padding: '2px 7px', borderRadius: 4, background: 'rgba(255,214,10,0.08)', border: '1px solid rgba(255,214,10,0.18)', color: '#ffd60a', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'none' as const }}>
            backend task
          </span>
        </div>
        <p style={{ fontSize: 12, color: '#3a3a3c', margin: 0, lineHeight: 1.5 }}>
          Per-space checkout tracking requires a{' '}
          <code style={{ fontFamily: "'SF Mono', ui-monospace, monospace", fontSize: 11, color: '#6e6e73' }}>
            GET /checkouts/active?share_id=
          </code>{' '}
          endpoint (not yet implemented in backend).
        </p>
      </div>

      {/* ACTIVITY LOG — backend task needed */}
      <div>
        <div style={{ fontSize: '10px', fontWeight: 510, letterSpacing: '0.08em', textTransform: 'uppercase' as const, color: '#6e6e73', marginBottom: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
          Recent Activity
          <span style={{ fontSize: 9, padding: '2px 7px', borderRadius: 4, background: 'rgba(255,214,10,0.08)', border: '1px solid rgba(255,214,10,0.18)', color: '#ffd60a', fontWeight: 500, letterSpacing: '0.04em', textTransform: 'none' as const }}>
            backend task
          </span>
        </div>
        <p style={{ fontSize: 12, color: '#3a3a3c', margin: 0, lineHeight: 1.5 }}>
          Space-scoped activity requires a{' '}
          <code style={{ fontFamily: "'SF Mono', ui-monospace, monospace", fontSize: 11, color: '#6e6e73' }}>
            location
          </code>{' '}
          or{' '}
          <code style={{ fontFamily: "'SF Mono', ui-monospace, monospace", fontSize: 11, color: '#6e6e73' }}>
            share_id
          </code>{' '}
          filter on{' '}
          <code style={{ fontFamily: "'SF Mono', ui-monospace, monospace", fontSize: 11, color: '#6e6e73' }}>
            GET /activity/recent
          </code>{' '}
          (not yet implemented in backend).
        </p>
      </div>

    </div>
  );
}
