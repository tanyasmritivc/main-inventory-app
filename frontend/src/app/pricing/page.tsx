import type { Metadata } from "next";
import { PagesShell } from "@/components/pages-ui/PagesShell";
import { PricingClient } from "@/components/site/pricing-client";

export const metadata: Metadata = {
  title: "Pricing",
  description: "Explore FindEZ plans for personal inventory and teams. Start free, with paid plans coming soon.",
  alternates: { canonical: "/pricing" },
  openGraph: {
    title: "Pricing | FindEZ",
    description: "Explore FindEZ plans for personal inventory and teams. Start free, with paid plans coming soon.",
    url: "https://findez.ai/pricing",
  },
};

export default function PricingPage() {
  return <PagesShell page="pricing"><PricingClient /></PagesShell>;
}
