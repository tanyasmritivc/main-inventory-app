import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function InventoryPage(props: { searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/inventory");
  }

  const searchParams = (await props.searchParams) ?? {};
  const collectionParam = searchParams.collection;
  const collection = typeof collectionParam === "string" ? collectionParam : undefined;

  return (
    <AppShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-[28px] font-semibold tracking-[-0.01em] text-white">Inventory</h1>
          <p className="text-[14px] text-white/45">What do you have? Search and filter your saved items.</p>
        </div>
        <HomeInventoryClient locationFilter={collection} />
      </div>
    </AppShell>
  );
}
