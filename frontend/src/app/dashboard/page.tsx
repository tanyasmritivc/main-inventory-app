import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SiteNav } from "@/components/site/nav";
import { DashboardClient } from "@/components/site/dashboard-client";

export default async function DashboardPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin");
  }

  return (
    <div className="min-h-screen">
      <SiteNav variant="app" />
      <main className="mx-auto w-full max-w-6xl px-4 py-10">
        <DashboardClient />
      </main>
    </div>
  );
}
