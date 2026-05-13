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
      <HomeInventoryClient locationFilter={collection} />
    </AppShell>
  );
}
