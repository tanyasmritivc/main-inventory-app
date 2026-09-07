import { TeamsClient } from "@/components/site/teams-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function TeamsPage() { return <ProtectedAppPage returnTo="/teams"><TeamsClient /></ProtectedAppPage>; }
