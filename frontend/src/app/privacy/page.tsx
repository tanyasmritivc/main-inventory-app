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
            <p className="text-sm text-muted-foreground">Last updated: January 2026</p>
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
            <p>support@yourappdomain.com</p>

            <h2 className="text-base font-semibold tracking-tight">Delete Account</h2>
            <p>
              To delete your account and all associated data, email us at support@yourappdomain.com
              <br />
              from your registered email address.
            </p>

            <div className="whitespace-pre-wrap">{`Privacy Policy

Last updated: [INSERT DATE]

We respect your privacy and are committed to protecting it.

This application collects only the information necessary to provide its core functionality, including but not limited to authentication details, inventory data, uploaded documents, and usage-related metadata. We do not sell your personal information.

Information We Collect
- Account information (such as email address and name, if provided)
- Inventory and content you choose to create or upload
- Usage data required to operate, maintain, and improve the service

How We Use Information
We use collected information solely to:
- Provide and operate the service
- Maintain security and prevent abuse
- Improve functionality and user experience

Data Storage and Security
Data is stored using third-party infrastructure providers. While reasonable safeguards are used, no system can be guaranteed to be completely secure.

Third-Party Services
This application relies on third-party services for authentication, data storage, and AI-powered features. Your use of the service is also subject to the terms and privacy policies of those providers.

Your Choices
You may stop using the service at any time. If you have questions about your data, contact the application owner.

---

Terms and Conditions

Last updated: [INSERT DATE]

By accessing or using this application, you agree to the following terms.

Use of the Service
The service is provided “as is” and “as available.” You agree to use it only for lawful purposes and are responsible for all activity conducted under your account.

No Warranties
We make no warranties, expressed or implied, regarding reliability, availability, accuracy, or fitness for a particular purpose.

Limitation of Liability
To the fullest extent permitted by law, the application owner shall not be liable for any direct, indirect, incidental, consequential, or special damages arising out of or related to your use of the service.

Data and Content
You retain ownership of the content you create or upload. You grant the application a limited right to process this content solely to provide the service.

Changes and Termination
We may modify or discontinue the service at any time without notice. We may update these terms periodically. Continued use of the service constitutes acceptance of the updated terms.`}</div>
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
            </div>
          </footer>
        </div>
      </main>
    </div>
  );
}
