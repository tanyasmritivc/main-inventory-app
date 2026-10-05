import type { Metadata } from "next";
import { LegalDocument } from "@/components/site/legal-document";
import { privacyIntro, privacySections } from "@/lib/legal-content";

// Draft previews must not be indexed or represented as an effective policy.
export const metadata: Metadata = {
  title: "Privacy Policy - Review Draft",
  description: "Review draft of FindEZ's privacy practices, data use, sharing and choices.",
  alternates: { canonical: "https://www.findez.ai/privacy" },
  robots: { index: false, follow: false },
};

export default function PrivacyPage() {
  return <LegalDocument kind="privacy" title="Privacy Policy" intro={privacyIntro} sections={privacySections} />;
}
