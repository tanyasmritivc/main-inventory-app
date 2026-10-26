import { TeamsClient } from "@/components/site/teams-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { redirect } from "next/navigation";
export const metadata = { title: "Workspace settings" };

export default async function TeamsPage({ searchParams }: { searchParams: Promise<{ team?: string }> }) {
  const { team } = await searchParams;
  if (!team) redirect("/workspaces");
  return <ProtectedAppPage returnTo={`/teams?team=${encodeURIComponent(team)}`}><TeamsClient selectedTeamId={team} /></ProtectedAppPage>;
}
