import type { Metadata } from "next";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";

export const metadata: Metadata = {
  title: "Join a shared Space",
  description: "Accept a FindEZ Space invitation in your browser.",
  robots: { index: false, follow: false },
};

export default async function SpaceInvitationPage({ params }: { params: Promise<{ code: string }> }) {
  const { code: rawCode } = await params;
  const code = rawCode.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  return <JoinInvitationClient code={code.length === 6 ? code : ""} kind="space" />;
}
