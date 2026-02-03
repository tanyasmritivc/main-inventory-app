"use client";

import { useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

export function SettingsClient(props: { email: string | null }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [signingOut, setSigningOut] = useState(false);

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
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
          <CardDescription>Signed in as {props.email || "your account"}.</CardDescription>
        </CardHeader>
        <CardContent className="flex items-center justify-between gap-2">
          <div className="text-sm text-muted-foreground">Manage your session and sign out when you’re done.</div>
          <Button type="button" variant="outline" onClick={onSignOut} disabled={signingOut}>
            {signingOut ? "Signing out…" : "Sign out"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
