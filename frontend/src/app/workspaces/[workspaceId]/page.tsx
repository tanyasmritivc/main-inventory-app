import { requireUser } from "@/lib/auth-guard";
import { WorkspaceDirectory } from "@/components/site/workspace-directory";
export const metadata = { title: "Inventories", robots: { index: false, follow: false } };
export default async function WorkspaceInventoriesPage({ params }: { params: Promise<{ workspaceId: string }> }) {
  const { workspaceId } = await params;
  await requireUser(`/workspaces/${encodeURIComponent(workspaceId)}`);
  return <WorkspaceDirectory workspaceId={workspaceId} />;
}
