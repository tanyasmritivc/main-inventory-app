import Link from "next/link";

import { MarketingNav } from "@/components/site/marketing-nav";

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-background">
      <MarketingNav />
      <main className="mx-auto w-full max-w-3xl px-4 py-14">
        <div className="space-y-8">
          <header className="space-y-2">
            <h1 className="text-2xl font-semibold tracking-tight">Terms of Service</h1>
          </header>

          <div className="space-y-4 text-sm leading-7 text-foreground/90">
            <p>By using this app, you agree to the following terms.</p>

            <h2 className="text-base font-semibold tracking-tight">Use of the App</h2>
            <p>
              The app is provided “as is” for managing inventory. You are responsible for the accuracy of the data you enter or
              upload.
            </p>

            <h2 className="text-base font-semibold tracking-tight">Accounts</h2>
            <p>You are responsible for maintaining the security of your account.</p>

            <h2 className="text-base font-semibold tracking-tight">Acceptable Use</h2>
            <p>You agree not to misuse the app, interfere with its operation, or attempt to access other users’ data.</p>

            <h2 className="text-base font-semibold tracking-tight">AI Features</h2>
            <p>AI features provide assistance based on your data and may not always be accurate. You are responsible for verifying results.</p>

            <h2 className="text-base font-semibold tracking-tight">Termination</h2>
            <p>We may suspend or terminate accounts that violate these terms.</p>

            <h2 className="text-base font-semibold tracking-tight">Liability</h2>
            <p>We are not liable for losses resulting from reliance on inventory data or AI-generated insights.</p>

            <h2 className="text-base font-semibold tracking-tight">Changes</h2>
            <p>We may update these terms from time to time.</p>

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
              <Link href="/privacy" className="hover:underline">
                Privacy Policy
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
