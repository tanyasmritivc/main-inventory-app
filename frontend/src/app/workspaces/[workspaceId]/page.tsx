import { requireUser } from "@/lib/auth-guard";
import type { WorkspaceView } from "@/lib/context-navigation";
import { WorkspaceDirectory } from "@/components/site/workspace-directory";
export const metadata = { title: "Inventories", robots: { index: false, follow: false } };
export default async function WorkspaceInventoriesPage({ params, searchParams }: { params: Promise<{ workspaceId: string }>; searchParams: Promise<{ view?: string }> }) {
  const { workspaceId } = await params;
  const { view } = await searchParams;
  const selectedView = ["people", "locations", "board", "files", "activity"].includes(view || "") ? view as WorkspaceView : "inventories";
  await requireUser(`/workspaces/${encodeURIComponent(workspaceId)}${selectedView === "inventories" ? "" : `?view=${selectedView}`}`);
  return <WorkspaceDirectory workspaceId={workspaceId} view={selectedView} />;
}
