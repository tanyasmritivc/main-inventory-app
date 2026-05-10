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
            <h2 className="text-[22px] font-semibold tracking-[-0.01em] text-white">Recent activity</h2>
            <p className="text-[14px] text-white/45">What&apos;s changed recently in your workspace.</p>
          </div>
          <HomeDocsClient />
        </section>
      </div>
    </AppShell>
  );
}
