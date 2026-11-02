import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { RestockClient } from "@/components/site/restock-client";
export const metadata = { title: "Restock" };

export default function Page() {
  return (
    <ProtectedAppPage returnTo="/restock">
      <RestockClient />
    </ProtectedAppPage>
  );
}
