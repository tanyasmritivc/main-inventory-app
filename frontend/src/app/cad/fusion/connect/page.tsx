import { cadWorldPath } from "@/lib/cad-links";
import { Suspense } from "react";
import { requireUser } from "@/lib/auth-guard";
import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { CadEntry } from "@/components/cad/cad-entry";
import { FusionConnect } from "@/components/cad/fusion-connect";

export const metadata = { title: "Connect Fusion", robots: { index: false, follow: false } };
export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  const code = typeof params.code === "string" && /^[A-HJ-NP-Z2-9]{10}$/.test(params.code) ? params.code : "";
  const inventory = typeof params.inventory === "string" ? params.inventory : "";
  const destination = `/cad/fusion/connect${code ? `?code=${code}` : ""}`;
  const world = typeof params.world === "string" && params.world.length <= 200 ? params.world : undefined;
  await requireUser(cadWorldPath(`${destination}${inventory ? `${code ? "&" : "?"}inventory=${encodeURIComponent(inventory)}` : ""}`, world));
  return <Suspense fallback={<p role="status">Opening Fusion connection...</p>}>
    {inventory ? <InventoryBoundary><FusionConnect code={code} /></InventoryBoundary> : <CadEntry worldId={world} destination={destination} />}
  </Suspense>;
}
