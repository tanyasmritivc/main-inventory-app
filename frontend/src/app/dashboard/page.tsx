import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/site/app-shell";
import { DashboardClient } from "@/components/site/dashboard-client";
import { HomeDocsClient } from "@/components/site/home-docs-client";

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin");
  }

  return (
    <AppShell>
      <div className="space-y-10">
        <DashboardClient />

        <section aria-label="Recent activity" className="space-y-4">
          <div>
            <h2 className="text-xl font-semibold tracking-tight">Recent activity</h2>
            <p className="text-sm text-muted-foreground">What’s changed recently in your workspace.</p>
          </div>
          <HomeDocsClient />
        </section>
      </div>
    </AppShell>
  );
}
