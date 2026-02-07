import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-background">
      <MarketingNav />
      <main className="mx-auto w-full max-w-3xl px-4 py-14">
        <div className="space-y-8">
          <header className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight">Privacy Policy</h1>
            <p className="text-sm text-muted-foreground">Last updated: 2/6/2026</p>
          </header>

          <div className="space-y-4 text-sm leading-7 text-foreground/90">
            <p>We respect your privacy. This Privacy Policy explains how we collect, use, and protect your information.</p>

            <h2 className="text-base font-semibold tracking-tight">Information We Collect</h2>
            <p>When you use the app, we may collect:</p>
            <ul className="list-disc pl-5 space-y-1 text-foreground/90">
              <li>Account information (such as email address)</li>
              <li>Inventory data you create or upload</li>
              <li>Images you upload for inventory scanning</li>
              <li>Usage data related to app functionality</li>
            </ul>

            <h2 className="text-base font-semibold tracking-tight">How We Use Your Information</h2>
            <p>We use your data to:</p>
            <ul className="list-disc pl-5 space-y-1 text-foreground/90">
              <li>Provide inventory management features</li>
              <li>Process images and extract inventory items</li>
              <li>Generate AI-assisted insights based on your data</li>
              <li>Improve app reliability and performance</li>
            </ul>

            <h2 className="text-base font-semibold tracking-tight">AI &amp; Image Processing</h2>
            <p>Uploaded images may be processed using AI services to extract inventory information.</p>
            <p>Your data is processed only for your account and is not shared with other users.</p>

            <h2 className="text-base font-semibold tracking-tight">Data Storage &amp; Security</h2>
            <p>Your data is stored securely. Each user can only access their own inventory and documents.</p>

            <h2 className="text-base font-semibold tracking-tight">Data Sharing</h2>
            <p>We do not sell your personal data.</p>
            <p>
              We only share data with third-party services strictly necessary to operate the app (such as cloud storage and AI
              processing).
            </p>

            <h2 className="text-base font-semibold tracking-tight">Data Deletion</h2>
            <p>You may delete your account and associated data at any time. See “Delete Account” instructions below.</p>

            <h2 className="text-base font-semibold tracking-tight">Contact</h2>
            <p>If you have questions about this policy, contact us at:</p>
            <p>vinodrexfms@ai-robots.co</p>

            <h2 className="text-base font-semibold tracking-tight">Delete Account</h2>
            <p>
              To delete your account and all associated data, email us at vinodrexfms@ai-robots.co
              <br />
              from your registered email address.
            </p>
          </div>

          <footer className="border-t pt-6 text-xs text-muted-foreground">
            <div className="flex flex-wrap items-center gap-3">
              <Link href="/terms" className="hover:underline">
                Terms of Service
              </Link>
              <span aria-hidden="true">·</span>
              <Link href="/terms" className="hover:underline">
                Terms &amp; Conditions
              </Link>
              <span aria-hidden="true">·</span>
              <Link href="/" className="hover:underline">
                Home
              </Link>
              © 2026 FindEZ. All rights reserved.
            </div>
          </footer>
        </div>
      </main>
    </div>
  );
}
