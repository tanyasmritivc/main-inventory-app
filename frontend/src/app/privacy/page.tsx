import Link from "next/link";
import { LegalDocument } from "@/components/site/legal-document";
import { MarketingNav } from "@/components/site/marketing-nav";
import { LEGAL_EFFECTIVE_DATE, privacySections } from "@/lib/legal-content";
import styles from "@/components/site/legal-document.module.css";

export const metadata = { title: "Privacy Policy", description: "How FindEZ handles information, permissions, device storage, and privacy requests.", alternates: { canonical: "/privacy" } };

export default function PrivacyPage() {
  return <div className={styles.page}><MarketingNav /><LegalDocument
    title="Privacy Policy" effective={LEGAL_EFFECTIVE_DATE}
    intro="How FindEZ handles your information and the choices available to you. This is the shared policy for our website, mobile app, and APIs."
    sections={privacySections}
    footer={<><Link href="/terms">Terms of Service</Link><a href="mailto:info@findez.ai">Privacy requests</a><span>© 2026 AI Robots Inc.</span></>}
  /></div>;
}
