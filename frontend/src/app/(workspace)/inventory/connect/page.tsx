import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { CommerceClient } from "@/components/site/commerce-client";

export const metadata = { title: "Connections" };

export default function CommercePage() {
  return <ProtectedAppPage returnTo="/inventory/connect"><CommerceClient /></ProtectedAppPage>;
}
