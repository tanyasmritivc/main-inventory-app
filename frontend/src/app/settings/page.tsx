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
      <div style={{ maxWidth: 600 }}>
        <h1 style={{ fontSize: 28, fontFamily: "var(--font-syne)", fontWeight: 600, color: "white", margin: 0 }}>Settings</h1>
        <p style={{ fontSize: 14, color: "rgba(255,255,255,0.45)", marginTop: 8, marginBottom: 40 }}>Manage your account.</p>
        <SettingsClient email={user.email || null} />
      </div>
    </AppShell>
  );
}
