import { ProjectKitsClient } from "@/components/site/project-kits-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export const metadata = { title: "Project kits" };

export default async function ProjectKitsPage({searchParams}:{searchParams:Promise<{kit?:string}>}) { const {kit}=await searchParams; return <ProtectedAppPage returnTo={kit?`/project-kits?${new URLSearchParams({kit})}`:"/project-kits"}><ProjectKitsClient initialKit={kit}/></ProtectedAppPage>; }
