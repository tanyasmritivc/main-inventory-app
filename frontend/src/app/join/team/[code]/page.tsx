import type { Metadata } from "next";
import Link from "next/link";

const APP_STORE_URL = "https://apps.apple.com/app/findez/id6746827458";

export const metadata: Metadata = {
  title: "Join a team",
  description: "Open a FindEZ team invitation.",
  robots: { index: false, follow: false },
};

export default async function TeamInvitationPage({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code: rawCode } = await params;
  const code = rawCode.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 6);
  const appUrl = `findez://team-invite?code=${encodeURIComponent(code)}`;

  return (
    <main
      style={{
        minHeight: "100dvh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        background: "radial-gradient(circle at 50% 8%, rgba(255,255,255,.08), transparent 32%), #090a0d",
        color: "#f5f5f7",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 500,
          padding: "42px 32px",
          border: "1px solid rgba(255,255,255,.11)",
          borderRadius: 26,
          background: "rgba(24,24,27,.92)",
          textAlign: "center",
          boxShadow: "0 24px 80px rgba(0,0,0,.42)",
        }}
      >
        <Link href="/" style={{ color: "#fff", textDecoration: "none", fontWeight: 700 }}>
          FindEZ
        </Link>
        <div aria-hidden="true" style={{ margin: "30px auto 20px", fontSize: 38 }}>◎</div>
        <h1 style={{ margin: 0, fontSize: 30, letterSpacing: "-.035em" }}>You’re invited to a team</h1>
        <p style={{ margin: "13px 0 26px", color: "rgba(255,255,255,.62)", lineHeight: 1.55 }}>
          Open FindEZ to accept the invitation.
        </p>
        <a
          href={appUrl}
          style={{ display: "block", padding: "14px 20px", borderRadius: 999, background: "#f5f5f7", color: "#111113", textDecoration: "none", fontWeight: 700 }}
        >
          Open in FindEZ
        </a>
        <a
          href={APP_STORE_URL}
          style={{ display: "block", marginTop: 12, padding: "13px 20px", borderRadius: 999, border: "1px solid rgba(255,255,255,.16)", color: "#f5f5f7", textDecoration: "none", fontWeight: 650 }}
        >
          Download on the App Store
        </a>
        <div style={{ marginTop: 27, paddingTop: 22, borderTop: "1px solid rgba(255,255,255,.09)" }}>
          <div style={{ color: "rgba(255,255,255,.45)", fontSize: 11, letterSpacing: ".14em" }}>JOIN CODE</div>
          <div style={{ marginTop: 7, fontSize: 24, fontWeight: 750, letterSpacing: ".2em" }}>{code}</div>
        </div>
      </section>
    </main>
  );
}
