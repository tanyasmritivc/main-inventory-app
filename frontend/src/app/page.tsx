import type { Metadata } from "next";

import { LandingMorph } from "@/components/site/landing-morph";
import { MarketingFooter } from "@/components/site/product-marketing";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: { absolute: "FindEZ | Know what you have. Find what you need." },
  description:
    "Capture physical items, organize them by Space, and find what you need through search or Ask FindEZ. Share inventory with your team.",
  openGraph: {
    title: "FindEZ | Know what you have. Find what you need.",
    description: "Turn photos of physical objects into searchable inventory, organized by space and ready to answer your questions.",
    url: "https://findez.ai/",
    siteName: "FindEZ",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: "FindEZ | Know what you have. Find what you need.",
    description: "Turn photos of physical objects into searchable inventory, organized by space and ready to answer your questions.",
  },
};

export default async function LandingPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  return (
    <>
      <LandingMorph initialSignedIn={Boolean(user)} />
      <MarketingFooter theme="light" />
    </>
  );
}
