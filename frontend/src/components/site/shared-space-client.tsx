"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  ApiError,
  addItem,
  getShareMembers,
  getMyShares,
  getJoinedShares,
  removeShareMember,
  type InventoryItem,
  updateSharedItem,
} from "@/lib/api";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { MoreHorizontal } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

const inputStyle = {
  background: 'rgba(0,0,0,0.36)',
  border: '1px solid rgba(255,255,255,0.12)',
  borderRadius: 8,
  padding: '10px 12px',
  color: '#f5f5f7',
  fontFamily: FONT,
};

function friendlyError(error: unknown, fallback: string) {
  return error instanceof ApiError ? error.message : fallback;
}

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
  const [addItemOpen, setAddItemOpen] = useState(false);
  const [newItemName, setNewItemName] = useState('');
  const [newItemCategory, setNewItemCategory] = useState('Other');
  const [newItemQuantity, setNewItemQuantity] = useState(1);
  const [addItemError, setAddItemError] = useState<string | null>(null);
  const [addingItem, setAddingItem] = useState(false);
  const [editingItem, setEditingItem] = useState<InventoryItem | null>(null);
  const [editName, setEditName] = useState('');
  const [editCategory, setEditCategory] = useState('Other');
  const [editQuantity, setEditQuantity] = useState(1);
  const [editNotes, setEditNotes] = useState('');
  const [editItemError, setEditItemError] = useState<string | null>(null);
  const [savingItem, setSavingItem] = useState(false);

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
        // The share permission describes invited members. Owners always retain
        // full control of their own inventory.
        setPermission('edit');
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
      setError(friendlyError(err, 'We could not load this space. Please try again.'));
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
      setError(friendlyError(err, 'We could not remove that member. Please try again.'));
    } finally {
      setRemovingMember(null);
    }
  }

  async function handleAddSharedItem() {
    const name = newItemName.trim();
    if (!name) {
      setAddItemError('Enter an item name.');
      return;
    }
    const t = token || await refreshToken();
    if (!t) {
      setAddItemError('Your session has expired. Please sign in again.');
      return;
    }

    setAddingItem(true);
    setAddItemError(null);
    try {
      const result = await addItem({
        token: t,
        item: {
          name,
          category: newItemCategory.trim() || 'Other',
          quantity: Math.max(0, Math.floor(Number(newItemQuantity) || 0)),
          location: spaceName,
          image_url: null,
          barcode: null,
          brand: null,
          part_number: null,
          purchase_source: null,
          notes: null,
        },
      });
      setItems((previous) => {
        const index = previous.findIndex((item) => item.item_id === result.item.item_id);
        if (index < 0) return [...previous, result.item];
        return previous.map((item) => item.item_id === result.item.item_id ? result.item : item);
      });
      setNewItemName('');
      setNewItemCategory('Other');
      setNewItemQuantity(1);
      setAddItemOpen(false);
    } catch (err) {
      setAddItemError(friendlyError(err, 'We could not add this item. Please try again.'));
    } finally {
      setAddingItem(false);
    }
  }

  function openEditItem(item: InventoryItem) {
    setEditingItem(item);
    setEditName(item.name ?? '');
    setEditCategory(item.category ?? 'Other');
    setEditQuantity(item.quantity ?? 0);
    setEditNotes(item.notes ?? '');
    setEditItemError(null);
  }

  async function updateSharedInventoryItem(itemId: string, updates: Parameters<typeof updateSharedItem>[0]['updates']) {
    const t = token || await refreshToken();
    if (!t) throw new ApiError('Your session has expired. Please sign in again.', 401, null);
    const result = await updateSharedItem({ token: t, shareId, itemId, updates });
    setItems((previous) => previous.map((item) => item.item_id === itemId ? result.item : item));
    return result.item;
  }

  async function handleSaveItem() {
    if (!editingItem) return;
    const name = editName.trim();
    if (!name) {
      setEditItemError('Enter an item name.');
      return;
    }
    setSavingItem(true);
    setEditItemError(null);
    try {
      await updateSharedInventoryItem(editingItem.item_id, {
        name,
        category: editCategory.trim() || 'Other',
        quantity: Math.max(0, Math.floor(Number(editQuantity) || 0)),
        notes: editNotes.trim() || null,
      });
      setEditingItem(null);
    } catch (err) {
      setEditItemError(friendlyError(err, 'We could not save this item. Please try again.'));
    } finally {
      setSavingItem(false);
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
          {permission === 'edit' && (
            <button
              type="button"
              onClick={() => { setAddItemError(null); setAddItemOpen(true); }}
              style={{ background: 'rgba(100,149,237,0.16)', border: '1px solid rgba(100,149,237,0.30)', borderRadius: 8, padding: '9px 14px', fontSize: 12, fontWeight: 560, color: '#a9c7ff', cursor: 'pointer', fontFamily: FONT, whiteSpace: 'nowrap' }}
            >
              + Add item
            </button>
          )}
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
            <div style={{ display: 'grid', gridTemplateColumns: permission === 'edit' ? '2fr 1fr 60px 2fr 44px' : '2fr 1fr 60px 2fr', gap: 12, paddingBottom: 10, borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
              {['Name', 'Category', 'Qty', 'Notes', ...(permission === 'edit' ? ['Actions'] : [])].map((h) => (
                <div key={h} style={{ fontSize: 10, fontWeight: 500, letterSpacing: '0.07em', textTransform: 'uppercase' as const, color: '#6e6e73' }}>{h}</div>
              ))}
            </div>
            {filteredItems.map((item: any) => (
              <div key={item.item_id} style={{ display: 'grid', gridTemplateColumns: permission === 'edit' ? '2fr 1fr 60px 2fr 44px' : '2fr 1fr 60px 2fr', gap: 12, padding: '11px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', alignItems: 'center' }}>
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
                {permission === 'edit' && (
                  <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <button type="button" aria-label={`Actions for ${item.name}`} style={{ width: 32, height: 32, borderRadius: 8, border: '1px solid rgba(255,255,255,0.12)', background: 'rgba(255,255,255,0.05)', color: '#c7c7cc', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
                          <MoreHorizontal size={17} aria-hidden="true" />
                        </button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onSelect={() => openEditItem(item as InventoryItem)}>Edit item</DropdownMenuItem>
                        <DropdownMenuItem onSelect={() => void updateSharedInventoryItem(item.item_id, { quantity: item.quantity + 1 }).catch((err) => setError(friendlyError(err, 'We could not update this item. Please try again.')))}>Add one</DropdownMenuItem>
                        <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void updateSharedInventoryItem(item.item_id, { quantity: Math.max(0, item.quantity - 1) }).catch((err) => setError(friendlyError(err, 'We could not update this item. Please try again.')))}>Remove one</DropdownMenuItem>
                        <DropdownMenuItem disabled={item.quantity === 0} onSelect={() => void updateSharedInventoryItem(item.item_id, { quantity: 0 }).catch((err) => setError(friendlyError(err, 'We could not update this item. Please try again.')))}>Mark out of stock</DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </div>
                )}
              </div>
            ))}
          </>
        )}
      </div>

      <Dialog open={addItemOpen} onOpenChange={(open) => { setAddItemOpen(open); if (!open) setAddItemError(null); }}>
        <DialogContent style={{ background: 'linear-gradient(145deg, rgba(30,31,43,0.98), rgba(12,12,18,0.98))', border: '1px solid rgba(255,255,255,0.16)', borderRadius: 16, padding: 28, maxWidth: 440, backdropFilter: 'blur(28px)' }}>
          <DialogHeader><DialogTitle style={{ color: '#f5f5f7' }}>Add to {spaceName}</DialogTitle></DialogHeader>
          <div style={{ display: 'grid', gap: 12, marginTop: 16 }}>
            <input autoFocus placeholder="Item name" value={newItemName} onChange={(e) => setNewItemName(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') void handleAddSharedItem(); }} style={{ background: 'rgba(0,0,0,0.36)', border: '1px solid rgba(255,255,255,0.12)', borderRadius: 8, padding: '10px 12px', color: '#f5f5f7', fontFamily: FONT }} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 100px', gap: 10 }}>
              <input placeholder="Category" value={newItemCategory} onChange={(e) => setNewItemCategory(e.target.value)} style={{ background: 'rgba(0,0,0,0.36)', border: '1px solid rgba(255,255,255,0.12)', borderRadius: 8, padding: '10px 12px', color: '#f5f5f7', fontFamily: FONT }} />
              <input aria-label="Quantity" type="number" min="0" value={newItemQuantity} onChange={(e) => setNewItemQuantity(Number(e.target.value))} style={{ background: 'rgba(0,0,0,0.36)', border: '1px solid rgba(255,255,255,0.12)', borderRadius: 8, padding: '10px 12px', color: '#f5f5f7', fontFamily: FONT }} />
            </div>
            {addItemError && <p role="alert" style={{ margin: 0, color: '#ff6961', fontSize: 12 }}>{addItemError}</p>}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 8 }}>
              <button type="button" onClick={() => setAddItemOpen(false)} disabled={addingItem} style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.12)', borderRadius: 8, padding: '9px 14px', color: '#a1a1a6', cursor: 'pointer', fontFamily: FONT }}>Cancel</button>
              <button type="button" onClick={() => void handleAddSharedItem()} disabled={addingItem} style={{ background: '#fff', border: 'none', borderRadius: 8, padding: '9px 14px', color: '#000', cursor: 'pointer', fontFamily: FONT, fontWeight: 600, opacity: addingItem ? 0.6 : 1 }}>{addingItem ? 'Adding…' : 'Add item'}</button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      <Dialog open={Boolean(editingItem)} onOpenChange={(open) => { if (!open) { setEditingItem(null); setEditItemError(null); } }}>
        <DialogContent style={{ background: 'linear-gradient(145deg, rgba(30,31,43,0.98), rgba(12,12,18,0.98))', border: '1px solid rgba(255,255,255,0.16)', borderRadius: 16, padding: 28, maxWidth: 440, backdropFilter: 'blur(28px)' }}>
          <DialogHeader><DialogTitle style={{ color: '#f5f5f7' }}>Edit item</DialogTitle></DialogHeader>
          <div style={{ display: 'grid', gap: 12, marginTop: 16 }}>
            <input autoFocus aria-label="Item name" value={editName} onChange={(event) => setEditName(event.target.value)} style={inputStyle} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 100px', gap: 10 }}>
              <input aria-label="Category" value={editCategory} onChange={(event) => setEditCategory(event.target.value)} style={inputStyle} />
              <input aria-label="Quantity" type="number" min="0" value={editQuantity} onChange={(event) => setEditQuantity(Number(event.target.value))} style={inputStyle} />
            </div>
            <textarea aria-label="Notes" placeholder="Notes (optional)" value={editNotes} onChange={(event) => setEditNotes(event.target.value)} rows={3} style={{ ...inputStyle, resize: 'vertical' }} />
            {editItemError && <p role="alert" style={{ margin: 0, color: '#ff6961', fontSize: 12 }}>{editItemError}</p>}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 8 }}>
              <button type="button" onClick={() => setEditingItem(null)} disabled={savingItem} style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.12)', borderRadius: 8, padding: '9px 14px', color: '#a1a1a6', cursor: 'pointer', fontFamily: FONT }}>Cancel</button>
              <button type="button" onClick={() => void handleSaveItem()} disabled={savingItem} style={{ background: '#fff', border: 'none', borderRadius: 8, padding: '9px 14px', color: '#000', cursor: 'pointer', fontFamily: FONT, fontWeight: 600, opacity: savingItem ? 0.6 : 1 }}>{savingItem ? 'Saving…' : 'Save changes'}</button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

    </div>
  );
}
