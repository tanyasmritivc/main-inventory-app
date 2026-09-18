import Link from "next/link";
import { LegalDocument } from "@/components/site/legal-document";
import { MarketingNav } from "@/components/site/marketing-nav";
import { privacySections } from "@/lib/legal-content";

export const metadata = { title: "Privacy Policy" };

export default function PrivacyPage() {
  return <div className="min-h-screen bg-background flex flex-col"><MarketingNav /><LegalDocument
    title="Privacy Policy" effective="August 30, 2026"
    intro="AI Robots Inc (“AI Robots,” “FindEZ,” “we,” “us,” or “our”) provides FindEZ. This Policy explains what information FindEZ collects, why we use it, when it is disclosed, and the choices available to you."
    sections={privacySections}
    footer={<><Link href="/terms" className="hover:underline">Terms of Service</Link><span>·</span><Link href="/" className="hover:underline">Home</Link><span>© 2026 AI Robots Inc.</span></>}
  /></div>;
}
