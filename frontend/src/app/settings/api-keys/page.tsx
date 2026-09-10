import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { ApiKeysClient } from "@/components/site/api-keys-client";

export default function ApiKeysPage() {
  return <ProtectedAppPage returnTo="/settings/api-keys"><ApiKeysClient /></ProtectedAppPage>;
}
