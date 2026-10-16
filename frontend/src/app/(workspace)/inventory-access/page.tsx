import { requireUser } from "@/lib/auth-guard";
import { CollaborationPanel } from "@/components/site/collaboration-panel";
export const metadata = { title: "Inventory access" };
export default async function InventoryAccessPage({ searchParams }: { searchParams: Promise<{ inventory?: string }> }) {
 const { inventory } = await searchParams;
 await requireUser(`/inventory-access?inventory=${encodeURIComponent(inventory || "")}`);
 return <section className="product-page"><header className="product-page-header"><h1>Access and history</h1></header>{inventory && <CollaborationPanel inventoryId={inventory} />}</section>;
}
