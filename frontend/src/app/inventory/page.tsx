import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function InventoryPage(props: { searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  const searchParams = (await props.searchParams) ?? {};
  const collectionParam = searchParams.collection;
  const collection = typeof collectionParam === "string" ? collectionParam : undefined;
  const spaceParam = searchParams.space;
  const initialSpace = typeof spaceParam === "string" ? spaceParam : collection;
  const itemParam = searchParams.item;
  const initialItem = typeof itemParam === "string" ? itemParam : undefined;
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    const destination = new URL("https://findez.ai/inventory");
    if (initialSpace) destination.searchParams.set("space", initialSpace);
    if (initialItem) destination.searchParams.set("item", initialItem);
    redirect(`/signin?redirect=${encodeURIComponent(destination.pathname + destination.search)}`);
  }

  return (
    <AppShell>
      <HomeInventoryClient mode="inventory" locationFilter={initialSpace} itemFilter={initialItem} />
    </AppShell>
  );
}
