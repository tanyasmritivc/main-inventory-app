import type { Metadata } from "next";
import localFont from "next/font/local";

import { LandingLab } from "@/components/site/landing-lab";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const geist = localFont({
  src: [{ path: "./fonts/geist-400.ttf", weight: "400" }, { path: "./fonts/geist-500.ttf", weight: "500" }],
  variable: "--fzl-geist", display: "swap",
});
const mono = localFont({
  src: [{ path: "./fonts/geist-mono-400.ttf", weight: "400" }, { path: "./fonts/geist-mono-500.ttf", weight: "500" }],
  variable: "--fzl-mono", display: "swap",
});

export const metadata: Metadata = {
  title: { absolute: "FindEZ | Know what you have. Find what you need." },
  description:
    "Capture physical items, organize them by Space, and find what you need through search or Ask FindEZ. Share inventory with your team.",
  alternates: { canonical: "/" },
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
  return <LandingLab className={`${geist.variable} ${mono.variable}`} siteNavigation initialSignedIn={Boolean(user)} />;
}
