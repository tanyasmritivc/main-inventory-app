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
          <h1 className="text-[28px] font-semibold tracking-[-0.01em] text-white">Settings</h1>
          <p className="text-[14px] text-white/45">Manage your account and preferences.</p>
        </div>

        <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.03] p-5">
          <div className="text-[13px] font-semibold text-white/60 uppercase tracking-widest mb-3">Free plan</div>
          <div className="space-y-2">
            <div className="flex items-center justify-between text-[13px]">
              <span className="text-white/60">AI chat prompts</span>
              <span className="text-white/40">10 / month</span>
            </div>
            <div className="flex items-center justify-between text-[13px]">
              <span className="text-white/60">Manual items</span>
              <span className="text-white/40">10</span>
            </div>
            <div className="flex items-center justify-between text-[13px]">
              <span className="text-white/60">Photo scans</span>
              <span className="text-white/40">3</span>
            </div>
          </div>
          <UpgradeCheckoutLink className="mt-3 inline-block text-[13px] text-white/40 hover:text-white underline-offset-4 hover:underline transition-colors" />
        </div>

        <SettingsClient email={user.email || null} />
      </div>
    </AppShell>
  );
}
