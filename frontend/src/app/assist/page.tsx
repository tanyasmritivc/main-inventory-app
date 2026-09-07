import { AssistClient } from "@/components/site/assist-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function AssistPage() { return <ProtectedAppPage returnTo="/assist"><AssistClient /></ProtectedAppPage>; }
