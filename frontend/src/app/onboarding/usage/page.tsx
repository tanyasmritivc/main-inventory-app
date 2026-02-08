import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { UsageOnboardingClient } from "@/components/site/usage-onboarding-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function UsageOnboardingPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/onboarding/usage");
  }

  return (
    <AppShell>
      <div className="min-h-[60vh] flex items-center justify-center">
        <UsageOnboardingClient />
      </div>
    </AppShell>
  );
}
