import type { Metadata } from "next";
import { AccessInvitationClient } from "@/components/site/access-invitation-client";
export const metadata: Metadata = { title: "Invitation", robots: { index: false, follow: false }, referrer: "no-referrer" };
export default async function AccessInvitationPage({ searchParams }: { searchParams: Promise<{ code?: string | string[]; invitation?: string | string[] }> }) {
  const query = await searchParams;
  const code = typeof query.code === "string" && /^[a-z2-9]{12}$/i.test(query.code) ? query.code.toUpperCase() : "";
  const invitationId = typeof query.invitation === "string" && /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(query.invitation) ? query.invitation : "";
  return <AccessInvitationClient code={code} invitationId={invitationId} />;
}
