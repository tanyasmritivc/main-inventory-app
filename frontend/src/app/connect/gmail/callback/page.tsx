import { CommerceCallbackClient } from "@/components/site/commerce-callback-client";

export const dynamic = "force-dynamic";
export const metadata = { title: "Connect Gmail", robots: { index: false, follow: false }, referrer: "no-referrer" as const };

export default function GmailCallbackPage() {
  return <CommerceCallbackClient provider="gmail" />;
}
