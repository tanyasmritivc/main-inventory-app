import { CommerceCallbackClient } from "@/components/site/commerce-callback-client";

export const dynamic = "force-dynamic";
export const metadata = { title: "Connect Shopify", robots: { index: false, follow: false }, referrer: "no-referrer" as const };

// No sign-in redirect: it would carry the provider code into another URL.
// The client strips the query and verifies the initiating account before POST.
export default function ShopifyCallbackPage() {
  return <CommerceCallbackClient provider="shopify" />;
}
