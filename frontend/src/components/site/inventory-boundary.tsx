"use client";
import { useEffect, useLayoutEffect, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { activeInventory, isInventoryPage, requireInventoryContext, selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { AppShell } from "@/components/site/app-shell";
import { userFacingError } from "@/lib/user-facing-error";

export function InventoryBoundary({ children }: { children: React.ReactNode }) {
  const { accountId, loading, error: sessionError } = useApiSession();
  const pathname = usePathname(), params = useSearchParams(), router = useRouter();
  const inventoryId = params.get("inventory");
  const required = isInventoryPage(pathname);
  const [verified, setVerified] = useState<InventorySelection | null>(null);
  const [error, setError] = useState("");
  useLayoutEffect(() => {
    requireInventoryContext(required);
    if (!required) selectInventory(null);
    return () => requireInventoryContext(false);
  }, [required]);
  useEffect(() => {
    let live = true;
    if (!accountId) { selectInventory(null); return; }
    if (!required) {
      selectInventory(null);
      return;
    }
    selectInventory(null);
    if (!inventoryId) { router.replace("/workspaces"); return; }
    void accountRequest<{ inventory: Omit<InventorySelection, "accountId"> }>(accountId, `/inventories/${encodeURIComponent(inventoryId)}`)
      .then(({ inventory }) => {
        if (!live) return;
        const value = { ...inventory, accountId };
        selectInventory(value);
        setVerified(value);
        setError("");
      }).catch((reason) => { if (live) setError(userFacingError(reason, "This inventory could not be opened.")); });
    return () => { live = false; selectInventory(null); };
  }, [accountId, inventoryId, required, router]);
  useEffect(() => () => { selectInventory(null); }, []);
  const ready = !loading && accountId && (!required || (verified?.inventory_id === inventoryId && verified.accountId === accountId && activeInventory() === verified));
  if (!ready) return (
    <div className="interior-loading inventory-loading" role={error || sessionError ? "alert" : "status"}>
      <p>{error || sessionError || "Opening inventory..."}</p>
      {(error || sessionError) && <Link href="/workspaces">Choose a workspace</Link>}
    </div>
  );
  if (required && verified && !verified.can_edit && pathname.startsWith("/scan")) return <AppShell inventory={verified}>
    <p className="workspace-muted">You have view-only access to this inventory.</p>
    <Link href={`/inventory?inventory=${encodeURIComponent(verified.inventory_id)}`}>View inventory</Link>
  </AppShell>;
  return <AppShell inventory={required && verified?.accountId === accountId ? verified : undefined} key={required ? `${accountId}:${inventoryId}` : "account"}>{children}</AppShell>;
}
