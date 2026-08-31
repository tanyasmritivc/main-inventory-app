import Link from "next/link";
import { LegalDocument } from "@/components/site/legal-document";
import { MarketingNav } from "@/components/site/marketing-nav";
import { termsSections } from "@/lib/legal-content";

export const metadata = { title: "Terms of Service" };

export default function TermsPage() {
  return <div className="min-h-screen bg-background flex flex-col"><MarketingNav /><LegalDocument
    title="Terms of Service" effective="August 30, 2026"
    intro="These Terms are an agreement between you and AI Robots Inc (“AI Robots,” “FindEZ,” “we,” “us,” or “our”). By creating an account, accessing, or using the FindEZ mobile app, website, APIs, or related services (the “Service”), you agree to these Terms and our Privacy Policy. If you do not agree, do not use the Service."
    sections={termsSections}
    footer={<><Link href="/privacy" className="hover:underline">Privacy Policy</Link><span>·</span><Link href="/" className="hover:underline">Home</Link><span>© 2026 AI Robots Inc.</span></>}
  /></div>;
}
