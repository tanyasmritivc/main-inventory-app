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
          <h1 className="text-2xl font-semibold tracking-tight">Collections</h1>
          <p className="text-sm text-muted-foreground">Jump into the spaces you actually use.</p>
        </div>
        <CollectionsClient />
      </div>
    </AppShell>
  );
}
