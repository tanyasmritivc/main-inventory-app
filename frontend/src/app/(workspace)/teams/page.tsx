import { TeamsClient } from "@/components/site/teams-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export const metadata = { title: "Teams" };

export default function TeamsPage() { return <ProtectedAppPage returnTo="/teams"><TeamsClient /></ProtectedAppPage>; }
