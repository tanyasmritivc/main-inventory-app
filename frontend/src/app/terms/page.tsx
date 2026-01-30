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
          </div>

          <footer className="border-t pt-6 text-xs text-muted-foreground">
            <div className="flex flex-wrap items-center gap-3">
              <Link href="/privacy" className="hover:underline">
                Privacy Policy
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
