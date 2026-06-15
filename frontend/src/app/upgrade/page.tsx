import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/site/app-shell";
import { UpgradeClient } from "@/components/site/upgrade-client";

export default async function UpgradePage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/upgrade");
  }

  return (
    <AppShell>
      <UpgradeClient />
    </AppShell>
  );
}
