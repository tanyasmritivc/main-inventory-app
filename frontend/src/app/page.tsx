import type { Metadata } from "next";
import { publicFonts } from "@/components/landing-v5/fonts";
import { workbenchFonts } from "@/components/landing-v5/workbench-fonts";
import { LandingV5 } from "@/components/landing-v5/LandingV5";
import { PUBLIC_SITE_DESCRIPTION, PUBLIC_SITE_STRUCTURED_DATA, PUBLIC_SITE_TITLE, PUBLIC_SITE_URL } from "@/lib/public-positioning";
export const metadata: Metadata = {
  title: { absolute: PUBLIC_SITE_TITLE },
  description: PUBLIC_SITE_DESCRIPTION,
  alternates: { canonical: "/" },
  openGraph: {
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
    url: `${PUBLIC_SITE_URL}/`,
    siteName: "FindEZ",
    type: "website",
    images: [{ url: "/brand/findez-petals-512.png", width: 512, height: 512, alt: "FindEZ" }],
  },
  twitter: {
    card: "summary",
    images: ["/brand/findez-petals-512.png"],
    title: PUBLIC_SITE_TITLE,
    description: PUBLIC_SITE_DESCRIPTION,
  },
};

export default function LandingPage() {
  return <>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(PUBLIC_SITE_STRUCTURED_DATA).replace(/</g, "\\u003c") }} />
    <LandingV5 className={`${publicFonts} ${workbenchFonts}`} />
  </>;
}
