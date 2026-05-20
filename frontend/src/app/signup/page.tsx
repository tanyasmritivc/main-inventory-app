"use client";

import { Suspense } from "react";
import Link from "next/link";

import { AuthForm } from "@/components/site/auth-form";

export default function SignUpPage() {
  return (
    <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", padding: "24px" }}>
      <div style={{ width: "100%", maxWidth: 400 }}>
        <div style={{ textAlign: "center", marginBottom: 32 }}>
          <div className="font-display" style={{ fontSize: 22, fontWeight: 700, color: "#fff", letterSpacing: "-0.4px", marginBottom: 8 }}>FindEZ</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: "#fff", marginBottom: 8 }}>Create account</div>
          <p style={{ fontSize: 14, color: "rgba(255,255,255,0.45)", marginTop: 0 }}>Sign in to your inventory</p>
        </div>
        <div className="glass-card" style={{ padding: 28 }}>
          <Suspense fallback={null}>
            <AuthForm mode="signup" />
          </Suspense>
        </div>
        <p style={{ marginTop: 20, textAlign: "center", fontSize: 13, color: "rgba(255,255,255,0.40)" }}>
          Already have an account?{" "}
          <Link href="/signin" style={{ color: "rgba(255,255,255,0.70)", textDecoration: "none" }} onMouseOver={(e) => { (e.currentTarget as HTMLElement).style.color = "#fff"; }} onMouseOut={(e) => { (e.currentTarget as HTMLElement).style.color = "rgba(255,255,255,0.70)"; }}>Sign in</Link>
        </p>
      </div>
    </div>
  );
}
