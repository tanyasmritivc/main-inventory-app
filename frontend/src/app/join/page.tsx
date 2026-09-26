import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";

export const metadata: Metadata = {
  title: "Join a shared Space",
  description: "Accept a FindEZ Space invitation.",
  robots: { index: false, follow: false },
};

/** Space invitation emails sent before 2026-09-24 linked to `/join?code=CODE`. */
export default async function LegacySpaceInvitationPage({ searchParams }: { searchParams: Promise<{ code?: string | string[] }> }) {
  const raw = (await searchParams).code;
  const code = (Array.isArray(raw) ? raw[0] : raw ?? "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  if (code.length === 6) redirect(`/join/${code}`);
  return <JoinInvitationClient code="" kind="space" />;
}
