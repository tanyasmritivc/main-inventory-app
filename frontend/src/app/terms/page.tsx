import Link from "next/link";
import { LegalDocument } from "@/components/site/legal-document";
import { MarketingNav } from "@/components/site/marketing-nav";
import { LEGAL_EFFECTIVE_DATE, termsSections } from "@/lib/legal-content";
import styles from "@/components/site/legal-document.module.css";

export const metadata = { title: "Terms of Service", description: "FindEZ account, content, sharing, payment, safety, and service terms.", alternates: { canonical: "/terms" } };

export default function TermsPage() {
  return <div className={styles.page}><MarketingNav /><LegalDocument
    title="Terms of Service" effective={LEGAL_EFFECTIVE_DATE}
    intro="These Terms are an agreement with AI Robots Inc for use of the FindEZ website, mobile app, APIs, and related services. By creating an account or using the service, you agree to these Terms. If you do not agree, do not use the service. The Privacy Policy separately explains how we handle information."
    sections={termsSections}
    footer={<><Link href="/privacy">Privacy Policy</Link><Link href="/privacy#cookies">Cookie details</Link><a href="mailto:info@findez.ai">Contact</a><span>© 2026 AI Robots Inc.</span></>}
  /></div>;
}
