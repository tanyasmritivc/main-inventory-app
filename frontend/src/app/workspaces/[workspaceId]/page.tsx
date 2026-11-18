import { requireUser } from "@/lib/auth-guard";
import { LegacyWorkspaceRedirect } from "@/components/site/legacy-workspace-redirect";
export default async function LegacyWorkspacePage({ params }: { params: Promise<{ workspaceId: string }> }) {
  const { workspaceId } = await params;
  await requireUser(`/workspaces/${encodeURIComponent(workspaceId)}`);
  return <LegacyWorkspaceRedirect workspaceId={workspaceId} />;
}
