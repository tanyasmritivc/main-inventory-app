import Link from "next/link";

export default function BillingCancelPage() {
  return (
    <div
      style={{
        background: "#0a0a0a",
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "40px 24px",
        fontFamily: "var(--font-dm-sans, 'DM Sans', system-ui, sans-serif)",
        color: "#f5f5f7",
      }}
    >
      <div
        style={{
          width: 64,
          height: 64,
          borderRadius: "50%",
          background: "rgba(255,255,255,0.05)",
          border: "1px solid rgba(255,255,255,0.1)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 24,
          marginBottom: 28,
          color: "rgba(255,255,255,0.4)",
        }}
      >
        ←
      </div>

      <h1
        style={{
          fontFamily: "var(--font-syne, 'Syne', sans-serif)",
          fontSize: 26,
          fontWeight: 700,
          letterSpacing: "-0.02em",
          color: "#fff",
          margin: 0,
          marginBottom: 12,
          textAlign: "center",
        }}
      >
        No worries.
      </h1>

      <p
        style={{
          fontSize: 15,
          color: "rgba(255,255,255,0.45)",
          textAlign: "center",
          maxWidth: 340,
          lineHeight: 1.6,
          marginBottom: 36,
        }}
      >
        Your checkout was cancelled. Your current plan is unchanged — upgrade any time from Settings or Pricing.
      </p>

      <div style={{ display: "flex", flexDirection: "column", gap: 12, width: "100%", maxWidth: 280 }}>
        <Link
          href="/pricing"
          style={{
            display: "block",
            background: "#fff",
            color: "#000",
            textDecoration: "none",
            borderRadius: 99,
            padding: "13px 0",
            fontSize: 14,
            fontWeight: 700,
            textAlign: "center",
          }}
        >
          View plans
        </Link>
        <Link
          href="/home"
          style={{
            display: "block",
            background: "transparent",
            color: "rgba(255,255,255,0.45)",
            textDecoration: "none",
            borderRadius: 99,
            padding: "12px 0",
            fontSize: 14,
            textAlign: "center",
          }}
        >
          Back to Dashboard
        </Link>
      </div>
    </div>
  );
}
