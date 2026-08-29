import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Get the FindEZ app",
  description: "Use the FindEZ iOS app for inventory, sharing, scanning, and AI tools.",
  robots: { index: false, follow: false },
};

const APP_STORE_URL = "https://apps.apple.com/app/findez/id6746827458";

export default function MobileAppPage() {
  return (
    <main
      style={{
        minHeight: "100dvh",
        display: "grid",
        placeItems: "center",
        padding: 24,
        background:
          "radial-gradient(circle at 50% 10%, rgba(20,184,166,0.16), transparent 34%), #090a12",
        color: "#f5f5f7",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 560,
          padding: "48px 36px",
          border: "1px solid rgba(255,255,255,0.09)",
          borderRadius: 24,
          background: "rgba(17,17,19,0.88)",
          textAlign: "center",
          boxShadow: "0 24px 80px rgba(0,0,0,0.35)",
        }}
      >
        <Link
          href="/"
          style={{ color: "#fff", textDecoration: "none", fontSize: 16, fontWeight: 700 }}
        >
          FindEZ AI
        </Link>
        <div
          aria-hidden="true"
          style={{
            width: 72,
            height: 72,
            margin: "32px auto 24px",
            borderRadius: 20,
            display: "grid",
            placeItems: "center",
            background: "linear-gradient(145deg, #2dd4bf, #0f766e)",
            fontSize: 34,
            boxShadow: "0 16px 40px rgba(20,184,166,0.24)",
          }}
        >
          F
        </div>
        <h1 style={{ margin: 0, fontSize: 34, letterSpacing: "-0.04em" }}>
          FindEZ lives on your iPhone
        </h1>
        <p
          style={{
            margin: "16px auto 28px",
            maxWidth: 430,
            color: "rgba(255,255,255,0.58)",
            fontSize: 16,
            lineHeight: 1.6,
          }}
        >
          Inventory, shared spaces, document imports, barcode and photo scanning, checkouts,
          shopping lists, and AI tools are available in the mobile app.
        </p>
        <a
          href={APP_STORE_URL}
          style={{
            display: "inline-block",
            padding: "13px 24px",
            borderRadius: 999,
            background: "#fff",
            color: "#090a12",
            textDecoration: "none",
            fontSize: 15,
            fontWeight: 700,
          }}
        >
          Open or download FindEZ
        </a>
        <div
          style={{
            marginTop: 28,
            display: "flex",
            justifyContent: "center",
            gap: 20,
            flexWrap: "wrap",
            fontSize: 13,
          }}
        >
          <Link href="/settings" style={{ color: "rgba(255,255,255,0.68)" }}>
            Manage account
          </Link>
          <Link href="/pricing" style={{ color: "rgba(255,255,255,0.68)" }}>
            View pricing
          </Link>
          <Link href="/" style={{ color: "rgba(255,255,255,0.68)" }}>
            Back to website
          </Link>
        </div>
      </section>
    </main>
  );
}
