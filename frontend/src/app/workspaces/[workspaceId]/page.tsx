import { requireUser } from "@/lib/auth-guard";
import type { WorkspaceView } from "@/lib/context-navigation";
import { WorkspaceDirectory } from "@/components/site/workspace-directory";
export const metadata = { title: "Workspace", robots: { index: false, follow: false } };
export default async function WorkspaceInventoriesPage({ params, searchParams }: { params: Promise<{ workspaceId: string }>; searchParams: Promise<{ view?: string }> }) {
  const { workspaceId } = await params;
  const { view } = await searchParams;
  const selectedView = ["overview", "inventories", "people", "locations", "board", "files", "activity", "settings"].includes(view || "") ? view as WorkspaceView : workspaceId === "personal" ? "inventories" : "overview";
  await requireUser(`/workspaces/${encodeURIComponent(workspaceId)}${selectedView === "overview" || workspaceId === "personal" ? "" : `?view=${selectedView}`}`);
  return <WorkspaceDirectory workspaceId={workspaceId} view={selectedView} />;
}
