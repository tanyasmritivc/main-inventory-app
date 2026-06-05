"use client";

import { Suspense } from "react";
import Link from "next/link";

import { AuthForm } from "@/components/site/auth-form";

export default function SignInPage() {
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: "32px", background: "radial-gradient(circle at top, rgba(86, 95, 255, 0.14), transparent 30%), #02040f" }}>
      <div style={{ width: "100%", maxWidth: 420, padding: "32px", borderRadius: 28, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", boxShadow: "0 36px 120px rgba(0,0,0,0.35)" }}>
        <div style={{ textAlign: "center", marginBottom: 28 }}>
          <div className="font-display" style={{ fontSize: 22, fontWeight: 700, color: "#fff", letterSpacing: "-0.04em", marginBottom: 10 }}>FindEZ</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: "#fff", marginBottom: 10 }}>Welcome back</div>
          <p style={{ fontSize: 15, color: "rgba(255,255,255,0.58)", margin: 0 }}>Sign in to access your smart inventory, reports, and sharing tools.</p>
        </div>
        <div style={{ borderRadius: 20, overflow: "hidden" }}>
          <div style={{ padding: "28px 1px 1px", background: "linear-gradient(180deg, rgba(255,255,255,0.12), transparent)" }}>
            <div style={{ padding: "24px", borderRadius: 20, background: "rgba(0,0,0,0.52)" }}>
              <Suspense fallback={null}>
                <AuthForm mode="signin" />
              </Suspense>
            </div>
          </div>
        </div>
        <p style={{ marginTop: 24, textAlign: "center", fontSize: 13, color: "rgba(255,255,255,0.44)" }}>
          Don&apos;t have an account?{' '}
          <Link href="/signup" style={{ color: "#fff", fontWeight: 600, textDecoration: "none" }}>Sign up</Link>
        </p>
      </div>
    </div>
  );
}
