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
      <section className="product-page settings-page">
        <header className="product-page-header"><div><h1>Settings</h1><p>Manage your profile, integrations, and account.</p></div></header>
        <SettingsClient email={user.email || null} />
      </section>
    </AppShell>
  );
}
