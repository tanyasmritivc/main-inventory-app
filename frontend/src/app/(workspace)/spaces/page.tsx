import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
export const metadata = { title: "Spaces" };

export default function Page() {
  return (
    <ProtectedAppPage returnTo="/spaces">
      <HomeInventoryClient mode="spaces" />
    </ProtectedAppPage>
  );
}
