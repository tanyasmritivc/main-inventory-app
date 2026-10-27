import { InventoryBoundary } from "@/components/site/inventory-boundary";
import { Suspense } from "react";
import { PageTransition } from "@/components/site/page-transition";

export const metadata = {
  robots: { index: false, follow: false },
};

// Keep navigation, identity and appearance mounted while page segments load.
// Authentication remains in each page so it is verified on every navigation.
export default function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<PageTransition />}><InventoryBoundary>{children}</InventoryBoundary></Suspense>;
}
