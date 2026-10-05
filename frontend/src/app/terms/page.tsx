import type { Metadata } from "next";
import { LegalDocument } from "@/components/site/legal-document";
import { termsIntro, termsSections } from "@/lib/legal-content";

export const metadata: Metadata = {
  title: "Terms of Service - Review Draft",
  description: "Review draft of FindEZ's service terms, responsibilities and applicable rights.",
  alternates: { canonical: "https://www.findez.ai/terms" },
  robots: { index: false, follow: false },
};

export default function TermsPage() {
  return <LegalDocument kind="terms" title="Terms of Service" intro={termsIntro} sections={termsSections} />;
}
