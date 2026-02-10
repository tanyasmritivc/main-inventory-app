import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SettingsClient } from "@/components/site/settings-client";
import { Settings as SettingsIcon } from "lucide-react";
import { UpgradeCheckoutLink } from "@/components/site/upgrade-checkout-link";

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

        <div>
          <div className="text-sm font-medium">Free usage limits</div>
          <div className="mt-2 space-y-1 text-sm text-muted-foreground">
            <div>💬 AI chat prompts: 10 / month</div>
            <div>📦 Manual items: 10</div>
            <div>📷 Photo scans: 3</div>
          </div>
          <UpgradeCheckoutLink className="mt-2 inline-block text-sm text-muted-foreground underline" />
        </div>

        <SettingsClient email={user.email || null} />
      </div>
    </AppShell>
  );
}
