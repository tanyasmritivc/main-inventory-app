import type { Metadata } from "next";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";
import { APP_STORE_ID, invitationUniversalLink } from "@/lib/app-store";
import { normalizeInvitationCode } from "@/lib/invitation";

type Params = { params: Promise<{ code: string }> };

function normalizeCode(rawCode: string) {
  return normalizeInvitationCode(rawCode);
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const code = normalizeCode((await params).code);
  return {
    title: "Join a team",
    description: "Accept a FindEZ team invitation in your browser.",
    robots: { index: false, follow: false },
    // The banner opens this link in an installed app. Account handoff handles installation.
    itunes: code ? { appId: APP_STORE_ID, appArgument: invitationUniversalLink("team", code) } : { appId: APP_STORE_ID },
  };
}

export default async function TeamInvitationPage({ params }: Params) {
  const code = normalizeCode((await params).code);
  return <JoinInvitationClient code={code} kind="team" />;
}
