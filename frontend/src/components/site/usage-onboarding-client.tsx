"use client";

import { useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { USAGE_TYPE_OPTIONS, type UsageType } from "@/lib/personalization";

export function UsageOnboardingClient() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get("redirect") || "/dashboard";
  const normalizedRedirect = redirect.startsWith("/onboarding/usage") ? "/dashboard" : redirect;

  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function finish() {
    router.push(normalizedRedirect);
    router.refresh();
  }

  async function onChoose(value: UsageType) {
    if (saving) return;
    setSaving(true);
    setError(null);
    try {
      const {
        data: { user },
        error: userErr,
      } = await supabase.auth.getUser();
      if (userErr) throw userErr;
      if (!user) {
        await finish();
        return;
      }

      await supabase.from("profiles").upsert({ id: user.id, usage_type: value });
      await finish();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Failed to save preference";
      setError(msg);
    } finally {
      setSaving(false);
    }
  }

  async function onSkip() {
    if (saving) return;
    await finish();
  }

  return (
    <Card className="w-full max-w-xl">
      <CardHeader>
        <CardTitle>What best describes how you’ll use FindEZ?</CardTitle>
        <CardDescription>This helps personalize suggestions. You can skip now and change this later.</CardDescription>
      </CardHeader>
      <CardContent className="grid gap-3">
        {USAGE_TYPE_OPTIONS.map((opt) => (
          <Button key={opt.value} type="button" variant="outline" disabled={saving} onClick={() => onChoose(opt.value)}>
            {opt.label}
          </Button>
        ))}

        {error ? <p className="text-sm text-destructive">{error}</p> : null}

        <div className="flex items-center justify-end gap-2 pt-2">
          <Button type="button" variant="ghost" disabled={saving} onClick={onSkip}>
            Skip
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
