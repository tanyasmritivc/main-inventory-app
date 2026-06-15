import Link from "next/link";

export default function UpgradeSuccessPage() {
  return (
    <div
      style={{
        minHeight: "100dvh",
        background: "#000",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "24px",
      }}
    >
      <div
        style={{
          maxWidth: 420,
          width: "100%",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          textAlign: "center",
          gap: 0,
        }}
      >
        {/* Green checkmark */}
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: "50%",
            background: "rgba(48, 209, 88, 0.12)",
            border: "1px solid rgba(48, 209, 88, 0.3)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            marginBottom: 28,
          }}
        >
          <svg
            width="32"
            height="32"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#30D158"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </div>

        {/* Heading */}
        <h1
          style={{
            fontFamily: "var(--font-syne, 'Syne', sans-serif)",
            fontSize: 28,
            fontWeight: 700,
            color: "#fff",
            margin: 0,
            marginBottom: 12,
            lineHeight: 1.2,
          }}
        >
          You&apos;re now on FindEZ Pro! 🎉
        </h1>

        {/* Subtext */}
        <p
          style={{
            fontFamily: "var(--font-dm-sans, sans-serif)",
            fontSize: 15,
            color: "rgba(255,255,255,0.55)",
            margin: 0,
            marginBottom: 8,
            lineHeight: 1.6,
          }}
        >
          A receipt has been sent to your email.
        </p>
        <p
          style={{
            fontFamily: "var(--font-dm-sans, sans-serif)",
            fontSize: 15,
            color: "rgba(255,255,255,0.55)",
            margin: 0,
            marginBottom: 36,
            lineHeight: 1.6,
          }}
        >
          Open the FindEZ app to start using your Pro features.
        </p>

        {/* CTA */}
        <Link
          href="/dashboard"
          style={{
            display: "inline-block",
            width: "100%",
            padding: "14px 0",
            background: "#fff",
            color: "#000",
            fontFamily: "var(--font-dm-sans, sans-serif)",
            fontSize: 15,
            fontWeight: 600,
            borderRadius: 99,
            textDecoration: "none",
            textAlign: "center",
          }}
        >
          Go to Dashboard
        </Link>
      </div>
    </div>
  );
}
