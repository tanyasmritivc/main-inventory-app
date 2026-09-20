import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { CollectionsClient } from "@/components/site/collections-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function CollectionsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/collections");
  }

  return (
    <AppShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-[28px] font-semibold tracking-[-0.01em] text-[#000000]">Smart Collections</h1>
          <p className="text-[14px] text-[#65545e]">Pre-built views for common tasks</p>
        </div>
        <CollectionsClient />
      </div>
    </AppShell>
  );
}
