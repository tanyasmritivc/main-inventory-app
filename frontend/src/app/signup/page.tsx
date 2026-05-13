import { Suspense } from "react";
import Link from "next/link";

import { AuthForm } from "@/components/site/auth-form";

export default function SignUpPage() {
  return (
    <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", padding: "24px" }}>
      <div style={{ width: "100%", maxWidth: 400 }}>
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div className="font-display" style={{ fontSize: 22, fontWeight: 700, color: "#fff", letterSpacing: "-0.4px" }}>FindEZ</div>
          <p style={{ fontSize: 13, color: "var(--text-secondary)", marginTop: 6 }}>Create your free account</p>
        </div>
        <div className="glass-card" style={{ padding: 28 }}>
          <Suspense fallback={null}>
            <AuthForm mode="signup" />
          </Suspense>
        </div>
        <p style={{ marginTop: 20, textAlign: "center", fontSize: 13, color: "var(--text-muted)" }}>
          Already have an account?{" "}
          <Link href="/signin" style={{ color: "var(--text-secondary)", textDecoration: "none" }}>Sign in</Link>
        </p>
      </div>
    </div>
  );
}
