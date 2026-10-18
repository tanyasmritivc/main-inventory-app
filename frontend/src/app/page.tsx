import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";

import { LandingLab } from "@/components/site/landing-lab";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { PUBLIC_SITE_DESCRIPTION, PUBLIC_SITE_STRUCTURED_DATA, PUBLIC_SITE_TITLE, PUBLIC_SITE_URL } from "@/lib/public-positioning";

const geist = Geist({ subsets: ["latin"], weight: ["400", "500"], variable: "--fzl-geist", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--fzl-mono", display: "swap" });

export const metadata: Metadata = {
  title: { absolute: PUBLIC_SITE_TITLE },
  description: PUBLIC_SITE_DESCRIPTION,
  alternates: { canonical: "/" },
  openGraph: {
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
    url: `${PUBLIC_SITE_URL}/`,
    siteName: "FindEZ AI",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
  },
};

export default async function LandingPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  return <>
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(PUBLIC_SITE_STRUCTURED_DATA).replace(/</g, "\\u003c") }}
    />
    <LandingLab className={`${geist.variable} ${mono.variable}`} siteNavigation initialSignedIn={Boolean(user)} />
  </>;
}
