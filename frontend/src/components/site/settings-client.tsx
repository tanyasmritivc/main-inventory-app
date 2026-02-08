"use client";

import { useEffect, useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { asUsageType, USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);
  const [usageType, setUsageType] = useState<UsageType | null>(null);
  const [usageLoading, setUsageLoading] = useState(false);
  const [usageError, setUsageError] = useState<string | null>(null);

  useEffect(() => {
    let mounted = true;
    setUsageLoading(true);
    setUsageError(null);
    supabase
      .auth.getUser()
      .then(({ data }) => {
        const user = data.user;
        if (!user) return null;
        return supabase.from("profiles").select("usage_type").eq("id", user.id).maybeSingle();
      })
      .then((res) => {
        if (!mounted) return;
        const data = (res as { data?: Record<string, unknown> | null } | null)?.data || null;
        setUsageType(asUsageType(data?.usage_type));
      })
      .catch(() => {
        if (!mounted) return;
        setUsageType(null);
      })
      .finally(() => {
        if (!mounted) return;
        setUsageLoading(false);
      });

    return () => {
      mounted = false;
    };
  }, [supabase]);

  async function saveUsageType(next: UsageType | null) {
    if (usageLoading) return;
    setUsageLoading(true);
    setUsageError(null);
    try {
      const {
        data: { user },
        error: userErr,
      } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      if (!user) return;

      await supabase.from("profiles").upsert({ id: user.id, usage_type: next });
      setUsageType(next);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save preference";
      setUsageError(msg);
    } finally {
      setUsageLoading(false);
    }
  }

  async function onSignOut() {
    if (signingOut) return;
    setSigningOut(true);
    try {
      await supabase.auth.signOut();
      window.location.href = "/";
    } finally {
      setSigningOut(false);
    }
  }

  return (
    <div className="grid gap-6 md:grid-cols-[320px_1fr] md:items-start">
      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
          <CardDescription>You’re signed in as:</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-sm font-medium leading-relaxed">{props.email || "your account"}</div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
          <CardDescription>Manage your session and sign out when you’re done.</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="text-sm text-muted-foreground">Sign out of FindEZ on this device.</div>
          <Button type="button" variant="outline" onClick={onSignOut} disabled={signingOut}>
            {signingOut ? "Signing out…" : "Sign out"}
          </Button>
        </CardContent>
      </Card>

      <Card className="md:col-start-2">
        <CardHeader>
          <CardTitle>Preferences</CardTitle>
          <CardDescription>Personalize suggestions and example prompts.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="text-sm text-muted-foreground">What best describes how you’ll use FindEZ?</div>
          <select
            className="h-10 w-full rounded-md border bg-background px-3 text-sm"
            value={usageType || ""}
            onChange={(e) => {
              const next = asUsageType(e.target.value) as UsageType | null;
              void saveUsageType(next);
            }}
            disabled={usageLoading}
          >
            <option value="">Not set</option>
            {USAGE_TYPE_OPTIONS.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>

          {usageError ? <p className="text-sm text-destructive">{usageError}</p> : null}

          <div className="flex items-center justify-end">
            <Button type="button" variant="outline" onClick={() => saveUsageType(null)} disabled={usageLoading || !usageType}>
              Clear
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
