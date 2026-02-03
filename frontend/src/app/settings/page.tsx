import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SettingsClient } from "@/components/site/settings-client";

export default async function SettingsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/settings");
  }

  return (
    <AppShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
          <p className="text-sm text-muted-foreground">Account and preferences.</p>
        </div>
        <SettingsClient email={user.email || null} />
      </div>
    </AppShell>
  );
}
