import type { Metadata } from "next";
import { Plus_Jakarta_Sans, Geist_Mono } from "next/font/google";
import { LandingV3 } from "@/components/landing-v3/LandingV3";
import { PUBLIC_SITE_DESCRIPTION, PUBLIC_SITE_STRUCTURED_DATA, PUBLIC_SITE_TITLE, PUBLIC_SITE_URL } from "@/lib/public-positioning";
const jakarta = Plus_Jakarta_Sans({ subsets: ["latin"], weight: ["400", "500", "600"], variable: "--landing-jakarta", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], weight: ["400", "500"], variable: "--landing-mono", display: "swap" });
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

export default function LandingPage() {
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(PUBLIC_SITE_STRUCTURED_DATA).replace(/</g, "\\u003c") }} />
    <LandingV3 className={`${jakarta.variable} ${mono.variable}`} />
  </>;
}
