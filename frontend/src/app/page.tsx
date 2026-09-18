import type { Metadata } from "next";

import { LandingMorph } from "@/components/site/landing-morph";
import { MarketingFooter } from "@/components/site/product-marketing";

export const metadata: Metadata = {
  title: { absolute: "FindEZ — Understands your environment" },
  description:
    "The physical world, understood as information. FindEZ turns a photo of a bin into inventory you can search, ask about, and trust.",
};

export default function LandingPage() {
  return (
    <>
      <LandingMorph />
      <MarketingFooter theme="light" />
    </>
  );
}
