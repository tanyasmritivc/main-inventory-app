import { Suspense } from "react";
import { requireUser } from "@/lib/auth-guard";
import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { CadClient } from "@/components/cad/cad-client";
import { CadEntry } from "@/components/cad/cad-entry";

export const metadata = { title: "CAD Intelligence", robots: { index: false, follow: false } };

export default async function CadPage({ searchParams }: { searchParams: Promise<{ inventory?: string; world?: string }> }) {
  const params = await searchParams;
  const inventory = typeof params.inventory === "string" && params.inventory ? params.inventory : undefined;
  const world = typeof params.world === "string" && params.world ? params.world : undefined;
  const destination = inventory ? `/cad?inventory=${encodeURIComponent(inventory)}` : world ? `/cad?world=${encodeURIComponent(world)}` : "/cad";
  // Verify before rendering the client inventory gate. A redirect nested behind
  // its anonymous loading state may never be consumed by the client router.
  await requireUser(destination);
  if (!inventory) return <Suspense fallback={<div role="status">Opening CAD Intelligence...</div>}><CadEntry worldId={world} /></Suspense>;
  return <Suspense fallback={<div role="status">Opening inventory...</div>}>
    <InventoryBoundary><CadClient /></InventoryBoundary>
  </Suspense>;
}
