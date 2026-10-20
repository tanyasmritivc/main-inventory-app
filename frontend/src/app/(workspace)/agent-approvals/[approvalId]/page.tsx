import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { AgentApprovalClient } from "@/components/site/agent-approval-client";

export const metadata = { title: "Review agent request", robots: { index: false, follow: false } };

export default async function AgentApprovalPage({ params }: { params: Promise<{ approvalId: string }> }) {
  const { approvalId } = await params;
  return <ProtectedAppPage returnTo={`/agent-approvals/${encodeURIComponent(approvalId)}`}>
    <AgentApprovalClient approvalId={approvalId} />
  </ProtectedAppPage>;
}
