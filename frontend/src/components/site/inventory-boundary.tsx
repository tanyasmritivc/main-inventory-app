"use client";
import { useEffect, useLayoutEffect, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { activeInventory, isInventoryPage, permissionFingerprint, requireInventoryContext, selectInventory, type InventorySelection } from "@/lib/inventory-selection";
import { AppShell } from "@/components/site/app-shell";
import { ApiError } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";

export function InventoryBoundary({ children }: { children: React.ReactNode }) {
  const { accountId, loading, error: sessionError } = useApiSession();
  const pathname = usePathname(), params = useSearchParams(), router = useRouter();
  const inventoryId = params.get("inventory");
  const required = isInventoryPage(pathname);
  const administration = pathname === "/inventory-access";
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
    if (!inventoryId) { router.replace("/organizations"); return; }
    let checking = false, recheck = false;
    const check = () => {
      if (!live || document.visibilityState === "hidden") return;
      if (checking) { recheck = true; return; }
      checking = true;
      void accountRequest<{ inventory: Omit<InventorySelection, "accountId"> }>(accountId, `/inventories/${encodeURIComponent(inventoryId)}${administration ? "/access" : ""}`)
      .then(({ inventory }) => {
        if (!live) return;
        if (inventory.inventory_id !== inventoryId || !inventory.workspace?.workspace_id ||
            (inventory.can_open === false && !(administration && inventory.can_manage))) {
          selectInventory(null); setVerified(null);
          throw new Error("This inventory's permissions changed. Choose an authorized inventory.");
        }
        const value = { ...inventory, accountId };
        const current = activeInventory();
        if (!current || permissionFingerprint(current) !== permissionFingerprint(value)) {
          selectInventory(value);
          setVerified(value);
        }
        setError("");
      }).catch((reason) => {
        if (!live) return;
        if (reason instanceof ApiError && [401,403,404].includes(reason.status)) {
          selectInventory(null); setVerified(null);
        }
        setError(userFacingError(reason, "This inventory could not be opened."));
      }).finally(() => { checking = false; if (live && recheck) { recheck = false; check(); } });
    };
    check();
    const timer = window.setInterval(check, 15_000);
    window.addEventListener("focus", check);
    document.addEventListener("visibilitychange", check);
    window.addEventListener("findez-permissions-changed", check);
    return () => { live = false; window.clearInterval(timer); window.removeEventListener("focus", check); document.removeEventListener("visibilitychange", check); window.removeEventListener("findez-permissions-changed", check); selectInventory(null); };
  }, [accountId, inventoryId, required, administration, router]);
  useEffect(() => () => { selectInventory(null); }, []);
  const ready = !loading && accountId && (!required || (verified?.inventory_id === inventoryId && verified.accountId === accountId && activeInventory() === verified));
  if (!ready) return (
    <div className="interior-loading inventory-loading" role={error || sessionError ? "alert" : "status"}>
      <p>{error || sessionError || "Opening inventory..."}</p>
      {(error || sessionError) && <Link href="/workspaces">Choose a workspace</Link>}
    </div>
  );
  return <AppShell inventory={required && verified?.accountId === accountId ? verified : undefined} key={required && verified ? permissionFingerprint(verified) : "account"}>
    {error && <p role="alert" className="notice-error">{error}</p>}{children}
  </AppShell>;
}
