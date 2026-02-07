import { MarketingNav } from "@/components/site/marketing-nav";

export const metadata = {
  title: "Terms & Conditions",
};

export default function TermsPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <MarketingNav />

      <main className="mx-auto max-w-3xl px-6 py-10 prose prose-invert flex-1">
        <h1>Terms and Conditions</h1>

        <p>
          <strong>Last updated:</strong> 2/6/2026
        </p>

        <p>
          By accessing or using this application (the “Service”), you agree to be
          bound by these Terms and Conditions. If you do not agree to these
          terms, you may not use the Service.
        </p>

        <h2>Use of the Service</h2>

        <p>
          The Service is provided on an “as is” and “as available” basis. You
          agree to use the Service only for lawful purposes and in compliance
          with applicable laws and regulations.
        </p>

        <p>
          You are responsible for all activity conducted under your account and
          for maintaining the confidentiality of your login credentials.
        </p>

        <h2>Accounts</h2>

        <p>
          You must provide accurate and complete information when creating an
          account. We reserve the right to suspend or terminate accounts that
          violate these Terms or misuse the Service.
        </p>

        <h2>Data and Content</h2>

        <p>
          You retain ownership of all content you create or upload, including
          inventory data, images, and documents.
        </p>

        <p>
          You grant the Service a limited, non-exclusive right to process this
          content solely to provide and improve the Service.
        </p>

        <h2>AI Features</h2>

        <p>
          The Service may use AI-powered features to analyze uploaded data in
          order to extract inventory information or generate insights.
        </p>

        <p>
          AI-generated results are provided for convenience only and may not be
          fully accurate. You are responsible for reviewing and verifying all
          outputs.
        </p>

        <h2>Third-Party Services</h2>

        <p>
          The Service relies on third-party providers for authentication, data
          storage, and AI processing. Your use of the Service may also be subject
          to the terms and policies of those providers.
        </p>

        <h2>No Warranties</h2>

        <p>
          We make no warranties, express or implied, regarding reliability,
          availability, accuracy, or fitness for a particular purpose.
        </p>

        <h2>Limitation of Liability</h2>

        <p>
          To the fullest extent permitted by law, we shall not be liable for any
          indirect, incidental, consequential, or special damages arising out
          of or related to your use of the Service.
        </p>

        <h2>Termination</h2>

        <p>
          We may suspend or terminate access to the Service at any time, with or
          without notice, for any reason.
        </p>

        <h2>Changes to These Terms</h2>

        <p>
          We may update these Terms periodically. Continued use of the Service
          constitutes acceptance of the updated Terms.
        </p>

        <h2>Contact</h2>

        <p>
          If you have questions about these Terms, contact us at:
          <br />
          <strong>vinodrexfms@ai-robots.co</strong>
        </p>
      </main>
    </div>
  );
}
