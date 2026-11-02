import { requireUser } from "@/lib/auth-guard";
import { InventoryAccessRequest } from "@/components/site/inventory-access-request";
export const metadata = {title:"Inventory access",robots:{index:false,follow:false}};
export default async function AccessRequestPage({params}:{params:Promise<{inventoryId:string}>}) {
 const {inventoryId}=await params;
 await requireUser(`/inventory-access-request/${encodeURIComponent(inventoryId)}`);
 return <InventoryAccessRequest inventoryId={inventoryId}/>;
}
