import { redirect } from "next/navigation";

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
    <div className="min-h-screen w-full bg-[linear-gradient(160deg,#fff7f1,#fde9df,#f8d8c6)] text-foreground">
      <div className="min-h-screen w-full flex items-center justify-center px-4 py-10">
        <UsageOnboardingClient />
      </div>
    </div>
  );
}
