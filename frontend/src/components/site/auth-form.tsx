"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type Mode = "signin" | "signup";

const fieldStyle: React.CSSProperties = {
  borderRadius: 8,
  border: "1px solid #2c2c2e",
  background: "#111113",
  padding: "12px 14px",
  fontSize: 13,
  color: "#f5f5f7",
  outline: "none",
  width: "100%",
  boxSizing: "border-box",
  transition: "border-color 200ms, background 200ms",
  fontWeight: 400,
  letterSpacing: "-0.008em",
};

function focusField(e: React.FocusEvent<HTMLInputElement>) {
  e.currentTarget.style.borderColor = "#3a3a3c";
  e.currentTarget.style.background = "#1c1c1e";
}
function blurField(e: React.FocusEvent<HTMLInputElement>) {
  e.currentTarget.style.borderColor = "#2c2c2e";
  e.currentTarget.style.background = "#111113";
}

export function AuthForm(props: { mode: Mode }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get("redirect") || "/dashboard";

  const normalizedRedirect = redirect.startsWith("/onboarding/usage") ? "/dashboard" : redirect;

  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function errorMessage(err: unknown): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return "Authentication failed";
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (props.mode === "signup") {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
        });
        if (signUpError) throw signUpError;

        const userId = data.user?.id;
        if (userId) {
          try {
            await supabase
              .from("profiles")
              .upsert({ id: userId, first_name: firstName.trim(), last_name: lastName.trim() });
          } catch {
            // ignore
          }
        }

        router.push(`/onboarding/usage?redirect=${encodeURIComponent(normalizedRedirect)}`);
        router.refresh();
        return;
      }

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signInError) throw signInError;

      router.push(normalizedRedirect);
      router.refresh();
    } catch (err: unknown) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ minHeight: "100vh", background: "#000", display: "flex", alignItems: "center", justifyContent: "center", padding: "32px 16px" }}>
      <div style={{ width: "100%", maxWidth: 380, background: "#0a0a0a", border: "1px solid #1c1c1e", borderRadius: 14, padding: "36px 32px" }}>
        {/* Logo mark */}
        <div style={{ display: "flex", alignItems: "center", gap: 7, marginBottom: 28 }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
            <svg width="13" height="13" viewBox="0 0 11 11" fill="none">
              <path d="M1.5 9L5.5 2L9.5 9" stroke="#000" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M3 6.8h5" stroke="#000" strokeWidth="1.3" strokeLinecap="round"/>
            </svg>
          </div>
          <span style={{ fontSize: 16, fontWeight: 590, color: "#fff", letterSpacing: "-0.025em" }}>FindEZ</span>
        </div>
        <div style={{ fontSize: '11px', fontWeight: 400, color: '#6e6e73', textAlign: 'center', marginTop: '-12px', marginBottom: '16px', letterSpacing: '-0.005em' }}>
          A product by AIROBOTS
        </div>

        <h1 style={{ fontSize: 22, fontWeight: 700, color: "#fff", margin: "0 0 4px", letterSpacing: "-0.035em" }}>
          {props.mode === "signup" ? "Create account" : "Welcome back"}
        </h1>
        <p style={{ fontSize: 13, color: "#6e6e73", margin: "0 0 24px", letterSpacing: "-0.01em" }}>
          {props.mode === "signup"
            ? "Start tracking your inventory with smart search and sharing."
            : "Sign in to access your inventory and smart tools."}
        </p>

        <form
          onSubmit={onSubmit}
          style={{ display: "grid", gap: 18 }}
        >
      <style>{`input:-webkit-autofill, textarea:-webkit-autofill {
        -webkit-box-shadow: 0 0 0 1000px #111113 inset !important;
        -webkit-text-fill-color: #f5f5f7 !important;
        caret-color: #f5f5f7;
        border: 1px solid #2c2c2e !important;
        transition: background-color 5000s ease-in-out 0s;
      }
      input:-webkit-autofill:focus, textarea:-webkit-autofill:focus {
        -webkit-box-shadow: 0 0 0 1000px #1c1c1e inset !important;
        border: 1px solid #3a3a3c !important;
      }`}</style>
      {props.mode === "signup" ? (
        <div style={{ display: "grid", gap: 12, gridTemplateColumns: "repeat(2, minmax(0, 1fr))" }}>
          <div style={{ display: "grid", gap: 6 }}>
            <Label htmlFor="first_name" style={{ fontSize: 12, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>First name</Label>
            <Input
              id="first_name"
              name="first_name"
              type="text"
              autoComplete="given-name"
              required
              placeholder="Jane"
              style={fieldStyle}
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
              onFocus={focusField}
              onBlur={blurField}
            />
          </div>
          <div style={{ display: "grid", gap: 6 }}>
            <Label htmlFor="last_name" style={{ fontSize: 12, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Last name</Label>
            <Input
              id="last_name"
              name="last_name"
              type="text"
              autoComplete="family-name"
              required
              placeholder="Smith"
              style={fieldStyle}
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
              onFocus={focusField}
              onBlur={blurField}
            />
          </div>
        </div>
      ) : null}

      <div style={{ display: "grid", gap: 6 }}>
        <Label htmlFor="email" style={{ fontSize: 12, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Email</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete={props.mode === "signup" ? "email" : "username"}
          required
          placeholder="you@example.com"
          style={fieldStyle}
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onFocus={focusField}
          onBlur={blurField}
        />
      </div>

      <div style={{ display: "grid", gap: 6 }}>
        <Label htmlFor="password" style={{ fontSize: 12, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>Password</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete={props.mode === "signup" ? "new-password" : "current-password"}
          required
          minLength={8}
          placeholder={props.mode === "signup" ? "At least 8 characters" : "••••••••"}
          style={fieldStyle}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onFocus={focusField}
          onBlur={blurField}
        />
      </div>

      {props.mode === "signup" ? (
        <p style={{ margin: 0, fontSize: 12, color: "#a1a1a6", fontWeight: 400, letterSpacing: "-0.008em" }}>
          Strong passwords help keep your inventory secure. We never share your data.
        </p>
      ) : null}

      {error ? (
        <p style={{ margin: 0, color: "#ff453a", fontSize: 12, lineHeight: 1.5, fontWeight: 500 }}>{error}</p>
      ) : null}

      <Button
        type="submit"
        disabled={loading}
        style={{
          width: "100%",
          padding: 11,
          borderRadius: 8,
          background: "#fff",
          color: "#000",
          fontSize: 14,
          fontWeight: 510,
          letterSpacing: "-0.02em",
          border: "none",
          cursor: loading ? "not-allowed" : "pointer",
          opacity: loading ? 0.6 : 1,
          transition: "opacity 200ms",
        }}
      >
        {loading ? (props.mode === "signup" ? "Creating account…" : "Signing in…") : (props.mode === "signup" ? "Create account" : "Sign in")}
      </Button>
        </form>

        <p style={{ marginTop: 20, textAlign: "center", fontSize: 12, color: "#6e6e73", letterSpacing: "-0.008em" }}>
          {props.mode === "signup" ? (
            <>Already have an account? <Link href="/signin" style={{ color: "#a1a1a6", textDecoration: "underline" }}>Sign in</Link></>
          ) : (
            <>Don&apos;t have an account? <Link href="/signup" style={{ color: "#a1a1a6", textDecoration: "underline" }}>Sign up</Link></>
          )}
        </p>
      </div>
    </div>
  );
}
