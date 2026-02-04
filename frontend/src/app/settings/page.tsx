import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SettingsClient } from "@/components/site/settings-client";
import { Settings as SettingsIcon } from "lucide-react";

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
          <div className="flex items-center gap-2">
            <SettingsIcon className="h-5 w-5 text-muted-foreground" aria-hidden="true" />
            <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
          </div>
          <p className="text-sm text-muted-foreground">Manage your account and preferences</p>
        </div>
        <SettingsClient email={user.email || null} />
      </div>
    </AppShell>
  );
}
