import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { InventoryEnrichmentClient } from "@/components/site/inventory-enrichment-client";
export const metadata = { title: "AI Inventory Enrichment | FindEZ" };
export default function EnrichmentPage() {
  return <ProtectedAppPage returnTo="/review/enrichment"><InventoryEnrichmentClient /></ProtectedAppPage>;
}
