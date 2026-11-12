import { CommerceCallbackClient } from "@/components/site/commerce-callback-client";

export const dynamic = "force-dynamic";
export const metadata = { title: "Connect Amazon", robots: { index: false, follow: false }, referrer: "no-referrer" as const };

export default function AmazonCallbackPage() {
  return <CommerceCallbackClient provider="amazon_seller" />;
}
