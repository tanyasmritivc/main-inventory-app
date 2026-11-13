import { Suspense } from "react";
import { requireUser } from "@/lib/auth-guard";
import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { OnshapeClient, OnshapeEntry } from "@/components/cad/onshape-client";
import { onshapeContext, onshapeQuery } from "@/lib/onshape";

export const metadata = { title: "Onshape CAD Intelligence", robots: { index: false, follow: false } };
export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  const context = onshapeContext(params);
  const inventory = typeof params.inventory === "string" ? params.inventory : "";
  const query = onshapeQuery(context);
  const destination = `/cad/onshape${query ? `?${query}` : ""}`;
  await requireUser(`${destination}${inventory ? `${query ? "&" : "?"}inventory=${encodeURIComponent(inventory)}` : ""}`);
  return <Suspense fallback={<p role="status">Opening Onshape comparison...</p>}>
    {inventory ? <InventoryBoundary><OnshapeClient initial={context} /></InventoryBoundary> : <OnshapeEntry destination={destination} />}
  </Suspense>;
}
