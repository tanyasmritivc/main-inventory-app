import { AppShell } from "@/components/site/app-shell";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
import { requireUser } from "@/lib/auth-guard";

export default async function HomePage() {
  await requireUser("/home");

  return (
    <AppShell>
      <HomeInventoryClient mode="home" />
    </AppShell>
  );
}
