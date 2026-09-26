import { AppShell } from "@/components/site/app-shell";
import { requireUser } from "@/lib/auth-guard";
import { SettingsClient } from "@/components/site/settings-client";

export default async function SettingsPage() {
  const user = await requireUser("/settings");

  return (
    <AppShell>
      <section className="product-page settings-page">
        <header className="product-page-header"><h1>Settings</h1></header>
        <SettingsClient email={user.email || null} />
      </section>
    </AppShell>
  );
}
