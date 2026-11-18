'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { accountRequest } from '@/lib/account-request';
import { Dialog, DialogContent, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

/** Only a once-per-account invitation. No game state is stored on this device. */
export function WorldInvitation({ accountId, worldId }: { accountId: string; worldId: string }) {
  const [open, setOpen] = useState(false);
  useEffect(() => {
    let active = true, pending = false;
    const key = `findez-world-invited:${accountId}`;
    const check = async () => {
      try {
        if (pending || localStorage.getItem(key)) return;
        pending = true;
        const data = await accountRequest<{ has_items: boolean }>(accountId, `/worlds/${encodeURIComponent(worldId)}/directory`);
        if (!data.has_items || !active) return;
        const spaces = await accountRequest<{ inventories: { spaces?: { item_count?: number }[] }[] }>(accountId, `/worlds/${encodeURIComponent(worldId)}/spaces`);
        if (active && spaces.inventories.some(i => i.spaces?.some(s => (s.item_count || 0) > 0))) {
          localStorage.setItem(key, '1'); setOpen(true);
        }
      } catch { /* An optional invitation never interrupts inventory or authentication. */ }
      finally { pending = false; }
    };
    const timer = setTimeout(() => void check(), 1500);
    window.addEventListener('findez-inventory-changed', check);
    return () => { active = false; clearTimeout(timer); window.removeEventListener('findez-inventory-changed', check); };
  }, [accountId, worldId]);
  return <Dialog open={open} onOpenChange={setOpen}><DialogContent><DialogTitle>Your space is ready to explore</DialogTitle><DialogDescription>See your real inventory in FindEZ World. Explore your Space, find your items and make it your own.</DialogDescription><div className="flex gap-3"><Button asChild><Link href="/world" onClick={() => setOpen(false)}>Open World</Link></Button><Button variant="secondary" onClick={() => setOpen(false)}>Later</Button></div></DialogContent></Dialog>;
}
