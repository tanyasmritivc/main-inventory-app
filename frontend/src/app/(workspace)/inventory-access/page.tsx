import Link from "next/link";
import { requireUser } from "@/lib/auth-guard";
import { CollaborationPanel, type CollaborationSection } from "@/components/site/collaboration-panel";
import { InventoryDirectorySettings } from "@/components/site/inventory-directory-settings";
export const metadata = { title: "Inventory settings" };
export default async function InventoryAccessPage({ searchParams }: { searchParams: Promise<{ inventory?: string; view?: string }> }) {
 const { inventory, view } = await searchParams;
 const selected: CollaborationSection | "directory" = ["policy", "locations", "activity", "directory"].includes(view || "") ? view as CollaborationSection | "directory" : "people";
 await requireUser(`/inventory-access?inventory=${encodeURIComponent(inventory || "")}&view=${selected}`);
 const tabs = [{ id: "people", label: "People" }, { id: "policy", label: "Permissions" }, { id: "locations", label: "Locations" }, { id: "activity", label: "History" }, { id: "directory", label: "Directory" }];
 return <section className="product-page"><header className="product-page-header"><h1>Inventory settings</h1></header>
  <nav className="product-tabs context-tabs" aria-label="Inventory access">{tabs.map((tab) => <Link key={tab.id} className={selected === tab.id ? "is-active" : ""} aria-current={selected === tab.id ? "page" : undefined} href={`/inventory-access?inventory=${encodeURIComponent(inventory || "")}&view=${tab.id}`}>{tab.label}</Link>)}</nav>
  {inventory && (selected === "directory" ? <InventoryDirectorySettings inventoryId={inventory}/> : <CollaborationPanel inventoryId={inventory} section={selected} />)}
 </section>;
}
