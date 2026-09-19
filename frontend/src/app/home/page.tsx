import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function HomePage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/home");
  }

  return (
    <AppShell>
      <HomeInventoryClient mode="home" />
    </AppShell>
  );
}
