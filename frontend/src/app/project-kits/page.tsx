import { ProjectKitsClient } from "@/components/site/project-kits-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function ProjectKitsPage() { return <ProtectedAppPage returnTo="/project-kits"><ProjectKitsClient /></ProtectedAppPage>; }
