import type { Metadata } from "next";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";
import { APP_STORE_ID, invitationUniversalLink } from "@/lib/app-store";

type Params = { params: Promise<{ code: string }> };

function normalizeCode(rawCode: string) {
  const code = rawCode.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  return code.length === 6 ? code : "";
}

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const code = normalizeCode((await params).code);
  return {
    title: "Join a team",
    description: "Accept a FindEZ team invitation in your browser.",
    robots: { index: false, follow: false },
    // Safari's Smart App Banner hands this invitation to the app after install.
    itunes: code ? { appId: APP_STORE_ID, appArgument: invitationUniversalLink("team", code) } : { appId: APP_STORE_ID },
  };
}

export default async function TeamInvitationPage({ params }: Params) {
  const code = normalizeCode((await params).code);
  return <JoinInvitationClient code={code} kind="team" />;
}
