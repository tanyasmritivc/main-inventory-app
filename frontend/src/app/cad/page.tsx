import { Suspense } from "react";
import { requireUser } from "@/lib/auth-guard";
import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { CadClient } from "@/components/cad/cad-client";

export const metadata = { title: "CAD Intelligence", robots: { index: false, follow: false } };

export default async function CadPage({ searchParams }: { searchParams: Promise<{ inventory?: string }> }) {
  const params = await searchParams;
  const destination = typeof params.inventory === "string" ? `/cad?inventory=${encodeURIComponent(params.inventory)}` : "/cad";
  // Verify before rendering the client inventory gate. A redirect nested behind
  // its anonymous loading state may never be consumed by the client router.
  await requireUser(destination);
  return <Suspense fallback={<div role="status">Opening inventory...</div>}>
    <InventoryBoundary><CadClient /></InventoryBoundary>
  </Suspense>;
}
