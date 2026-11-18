import { notFound } from 'next/navigation';
import { WorldClient } from '@/components/world/world-client';
import { apiBase } from '@/lib/api';
export default async function SharedWorld({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  if (!/^[A-Za-z0-9_-]{22,64}$/.test(token)) notFound();
  const response = await fetch(`${apiBase()}/public/world/s/${encodeURIComponent(token)}`, { cache: 'no-store' });
  if (response.status === 404) notFound();
  if (!response.ok) throw new Error('This shared space could not be loaded.');
  return <WorldClient publicData={await response.json()} embedded={false} />;
}
