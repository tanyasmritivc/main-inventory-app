"use client";

import { useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

type Mode = "signin" | "signup";

const fieldStyle: React.CSSProperties = {
  borderRadius: 12,
  border: "1px solid rgba(255,255,255,0.10)",
  background: "rgba(255,255,255,0.05)",
  padding: "11px 14px",
  fontSize: 14,
  color: "#fff",
  outline: "none",
  width: "100%",
  boxSizing: "border-box",
  transition: "border-color 200ms",
};

function focusField(e: React.FocusEvent<HTMLInputElement>) {
  e.currentTarget.style.borderColor = "rgba(255,255,255,0.30)";
}
function blurField(e: React.FocusEvent<HTMLInputElement>) {
  e.currentTarget.style.borderColor = "rgba(255,255,255,0.10)";
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
      } else {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (signInError) throw signInError;
      }

      router.push(normalizedRedirect);
      router.refresh();
    } catch (err: unknown) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <form
      className="grid gap-4"
      onSubmit={onSubmit}
      style={{ display: "flex", flexDirection: "column", gap: 16 }}
    >
      {props.mode === "signup" ? (
        <div style={{ display: "flex", gap: 12 }}>
          <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 6 }}>
            <Label htmlFor="first_name" style={{ fontSize: 12, color: "var(--text-secondary)" }}>First Name</Label>
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
              <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 6 }}>
                <Label htmlFor="last_name" style={{ fontSize: 12, color: "var(--text-secondary)" }}>Last Name</Label>
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
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <Label htmlFor="email" style={{ fontSize: 13, color: "rgba(255,255,255,0.60)", display: "block", marginBottom: 6 }}>Email</Label>
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
          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <Label htmlFor="password" style={{ fontSize: 13, color: "rgba(255,255,255,0.60)", display: "block", marginBottom: 6 }}>Password</Label>
            <Input
              id="password"
              name="password"
              type="password"
              autoComplete={props.mode === "signup" ? "new-password" : "current-password"}
              required
              placeholder={props.mode === "signup" ? "At least 8 characters" : "••••••••"}
              style={fieldStyle}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              onFocus={focusField}
              onBlur={blurField}
            />
          </div>
          {error ? (
            <p style={{ fontSize: 13, color: "var(--danger)" }}>{error}</p>
          ) : null}
          <Button
            type="submit"
            disabled={loading}
            style={{
              width: "100%",
              marginTop: 24,
              padding: 12,
              borderRadius: 99,
              background: "#fff",
              color: "#000",
              fontSize: 14,
              fontWeight: 600,
              border: "none",
              cursor: loading ? "not-allowed" : "pointer",
              opacity: loading ? 0.5 : 1,
              transition: "opacity 150ms",
            }}
            onMouseEnter={(e) => { if (!loading) (e.currentTarget as HTMLElement).style.opacity = "0.88"; }}
            onMouseLeave={(e) => { if (!loading) (e.currentTarget as HTMLElement).style.opacity = "1"; }}
          >
            {loading ? (props.mode === "signup" ? "Creating account…" : "Signing in…") : (props.mode === "signup" ? "Create account" : "Sign in")}
          </Button>
    </form>
  );
}
