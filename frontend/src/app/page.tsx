import type { Metadata } from "next";

import { LandingMorph } from "@/components/site/landing-morph";
import { MarketingFooter } from "@/components/site/product-marketing";

export const metadata: Metadata = {
  title: { absolute: "FindEZ — Understands your environment" },
  description:
    "FindEZ understands your environment. Turn photos of physical objects into searchable inventory, organized by space and ready to answer your questions.",
  openGraph: {
    title: "FindEZ — Understands your environment",
    description: "Turn photos of physical objects into searchable inventory, organized by space and ready to answer your questions.",
    url: "https://findez.ai/",
    siteName: "FindEZ",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "FindEZ — Understands your environment",
    description: "Turn photos of physical objects into searchable inventory, organized by space and ready to answer your questions.",
  },
};

export default function LandingPage() {
  return (
    <>
      <LandingMorph />
      <MarketingFooter theme="light" />
    </>
  );
}
