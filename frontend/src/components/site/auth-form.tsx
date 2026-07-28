"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import BorderGlow from "@/components/ui/BorderGlow";

type Mode = "signin" | "signup";

interface AuthFormProps {
  mode?: Mode;
  onToggleMode?: (mode: Mode) => void;
  onSuccess?: () => void;
}

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

export function AuthForm({ mode = "signin", onToggleMode, onSuccess }: AuthFormProps) {
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

  const handleGoogleSignIn = async () => {
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: `${window.location.origin}/dashboard` }
    });
  };

  const handleAppleSignIn = async () => {
    await supabase.auth.signInWithOAuth({
      provider: 'apple',
      options: { redirectTo: `${window.location.origin}/dashboard` }
    });
  };

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      if (mode === "signup") {
        const { data, error: signUpError } = await supabase.auth.signUp({
          email,
          password,
        });
        if (signUpError) throw signUpError;

        const userId = data.user?.id;
        if (firstName.trim().length > 50 || lastName.trim().length > 50) {
          setError("Name must be under 50 characters.");
          return;
        }
        if (userId) {
          try {
            await supabase
              .from("profiles")
              .upsert({ id: userId, first_name: firstName.trim(), last_name: lastName.trim() });
          } catch {
            // ignore
          }
        }

        onSuccess?.();
        router.push(`/onboarding/usage?redirect=${encodeURIComponent(normalizedRedirect)}`);
        router.refresh();
        return;
      }

      const { error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (signInError) throw signInError;

      onSuccess?.();
      router.push(normalizedRedirect);
      router.refresh();
    } catch (err: unknown) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  const card = (
    <BorderGlow
        edgeSensitivity={30}
        glowColor="174 72 56"
        backgroundColor="#0d0d0d"
        borderRadius={16}
        glowRadius={40}
        glowIntensity={1.2}
        coneSpread={25}
        animated={false}
        colors={['#14b8a6', '#0891b2', '#06b6d4']}
        fillOpacity={0.4}
        className="w-full max-w-[380px]"
      >
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
        <div style={{ fontSize: '11px', color: '#6e6e73', textAlign: 'center', marginTop: '-8px', marginBottom: '16px', letterSpacing: '-0.005em' }}>
          A product of AI Robots Inc
        </div>

        <h1 style={{ fontSize: 22, fontWeight: 700, color: "#fff", margin: "0 0 4px", letterSpacing: "-0.035em" }}>
          {mode === "signup" ? "Create account" : "Welcome back"}
        </h1>
        <p style={{ fontSize: 13, color: "#6e6e73", margin: "0 0 24px", letterSpacing: "-0.01em" }}>
          {mode === "signup"
            ? "Start tracking your inventory with smart search and sharing."
            : "Sign in to access your inventory and smart tools."}
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
          <button
            type="button"
            onClick={handleGoogleSignIn}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              gap: '10px', width: '100%', padding: '11px 16px',
              background: 'rgba(255,255,255,0.06)',
              border: '1px solid rgba(255,255,255,0.12)',
              borderRadius: '10px', color: '#fff', fontSize: '14px',
              fontWeight: 500, cursor: 'pointer',
            }}
          >
            <svg width="18" height="18" viewBox="0 0 48 48">
              <path fill="#FFC107" d="M43.6 20H24v8h11.3C33.6 33.1 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 7.9 3l5.7-5.7C34.1 6.5 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20c11 0 20-9 20-20 0-1.3-.1-2.7-.4-4z"/>
              <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.5 15.1 18.9 12 24 12c3.1 0 5.8 1.1 7.9 3l5.7-5.7C34.1 6.5 29.3 4 24 4c-7.6 0-14.2 4.2-17.7 10.7z"/>
              <path fill="#4CAF50" d="M24 44c5.2 0 9.9-1.9 13.5-5l-6.2-5.2C29.3 35.3 26.8 36 24 36c-5.2 0-9.6-2.9-11.3-7.1l-6.5 5C9.8 39.8 16.4 44 24 44z"/>
              <path fill="#1976D2" d="M43.6 20H24v8h11.3c-.8 2.3-2.3 4.2-4.3 5.5l6.2 5.2C41 35.1 44 30 44 24c0-1.3-.1-2.7-.4-4z"/>
            </svg>
            Continue with Google
          </button>

          <button
            type="button"
            onClick={handleAppleSignIn}
            style={{
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              gap: '10px', width: '100%', padding: '11px 16px',
              background: 'rgba(255,255,255,0.06)',
              border: '1px solid rgba(255,255,255,0.12)',
              borderRadius: '10px', color: '#fff', fontSize: '14px',
              fontWeight: 500, cursor: 'pointer',
            }}
          >
            <svg width="18" height="18" viewBox="0 0 814 1000" fill="white">
              <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103.7 40.8-165.9 40.8s-105-37.3-155.5-127.4C46 790.9 0 663.6 0 541.8c0-194 127.4-296.9 250.2-296.9 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8 1.3 15.6 1.9 18.1 3.2.6 8.4 1.3 13.6 1.3 45.4 0 102.5-30.4 135.5-71.3z"/>
            </svg>
            Continue with Apple
          </button>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '20px' }}>
          <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.1)' }} />
          <span style={{ color: 'rgba(255,255,255,0.3)', fontSize: '12px' }}>or</span>
          <div style={{ flex: 1, height: '1px', background: 'rgba(255,255,255,0.1)' }} />
        </div>

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
      {mode === "signup" ? (
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
          autoComplete={mode === "signup" ? "email" : "username"}
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
          autoComplete={mode === "signup" ? "new-password" : "current-password"}
          required
          minLength={8}
          placeholder={mode === "signup" ? "At least 8 characters" : "••••••••"}
          style={fieldStyle}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onFocus={focusField}
          onBlur={blurField}
        />
      </div>

      {mode === "signup" ? (
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
        {loading ? (mode === "signup" ? "Creating account…" : "Signing in…") : (mode === "signup" ? "Create account" : "Sign in")}
      </Button>
        </form>

        <p style={{ marginTop: 20, textAlign: "center", fontSize: 12, color: "#6e6e73", letterSpacing: "-0.008em" }}>
          {mode === "signup" ? (
            <>Already have an account?{" "}
              {onToggleMode
                ? <button onClick={() => onToggleMode("signin")} style={{ color: "#a1a1a6", textDecoration: "underline", background: "none", border: "none", cursor: "pointer", fontSize: "inherit", padding: 0, letterSpacing: "-0.008em" }}>Sign in</button>
                : <Link href="/signin" style={{ color: "#a1a1a6", textDecoration: "underline" }}>Sign in</Link>
              }
            </>
          ) : (
            <>Don&apos;t have an account?{" "}
              {onToggleMode
                ? <button onClick={() => onToggleMode("signup")} style={{ color: "#a1a1a6", textDecoration: "underline", background: "none", border: "none", cursor: "pointer", fontSize: "inherit", padding: 0, letterSpacing: "-0.008em" }}>Sign up</button>
                : <Link href="/signup" style={{ color: "#a1a1a6", textDecoration: "underline" }}>Sign up</Link>
              }
            </>
          )}
        </p>
      </div>
      </BorderGlow>
  );

  if (onSuccess) return card;

  return (
    <div style={{ minHeight: "100vh", background: "#000", display: "flex", alignItems: "center", justifyContent: "center", padding: "32px 16px" }}>
      {card}
    </div>
  );
}
