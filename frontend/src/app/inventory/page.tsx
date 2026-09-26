import { AppShell } from "@/components/site/app-shell";
import { HomeInventoryClient } from "@/components/site/home-inventory-client";
import { requireUser } from "@/lib/auth-guard";

export default async function InventoryPage(props: { searchParams?: Promise<Record<string, string | string[] | undefined>> }) {
  const searchParams = (await props.searchParams) ?? {};
  const collectionParam = searchParams.collection;
  const collection = typeof collectionParam === "string" ? collectionParam : undefined;
  const spaceParam = searchParams.space;
  const initialSpace = typeof spaceParam === "string" ? spaceParam : collection;
  const itemParam = searchParams.item;
  const initialItem = typeof itemParam === "string" ? itemParam : undefined;
  const destination = new URL("https://findez.ai/inventory");
  if (initialSpace) destination.searchParams.set("space", initialSpace);
  if (initialItem) destination.searchParams.set("item", initialItem);
  await requireUser(destination.pathname + destination.search);

  return (
    <AppShell>
      <HomeInventoryClient mode="inventory" locationFilter={initialSpace} itemFilter={initialItem} />
    </AppShell>
  );
}
