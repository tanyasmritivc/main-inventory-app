import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
export default function Page() {
  return (
    <ProtectedAppPage returnTo="/spaces">
      <HomeInventoryClient mode="spaces" />
    </ProtectedAppPage>
  );
}
