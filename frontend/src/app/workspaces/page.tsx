import { requireUser } from "@/lib/auth-guard";
import { WorkspaceDirectory } from "@/components/site/workspace-directory";
export const metadata = { title: "Workspaces", robots: { index: false, follow: false } };
export default async function WorkspacesPage() {
  await requireUser("/workspaces");
  return <WorkspaceDirectory />;
}
