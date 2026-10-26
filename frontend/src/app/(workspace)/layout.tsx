import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { Suspense } from "react";

export const metadata = {
  robots: { index: false, follow: false },
};

// Keep navigation, identity and appearance mounted while page segments load.
// Authentication remains in each page so it is verified on every navigation.
export default function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<div className="interior-loading inventory-loading" role="status">Opening inventory...</div>}><InventoryBoundary>{children}</InventoryBoundary></Suspense>;
}
