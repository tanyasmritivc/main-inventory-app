"use client";
import NextLink from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, type ComponentProps } from "react";
import { activeInventory, inventoryHref, isInventoryPage } from "@/lib/inventory-selection";

export default function InventoryLink(props: ComponentProps<typeof NextLink>) {
  const selected = activeInventory();
  let href = props.href;
  if (typeof href === "string") href = inventoryHref(href, selected);
  else if (selected && href.pathname && isInventoryPage(href.pathname)) {
    const query = typeof href.query === "string" ? Object.fromEntries(new URLSearchParams(href.query)) : href.query;
    href = { ...href, query: { ...query, inventory: selected.inventory_id } };
  }
  return <NextLink {...props} href={href} />;
}

export function useInventoryRouter() {
  const router = useRouter();
  return useMemo(() => ({
    ...router,
    push: (href: string, options?: Parameters<typeof router.push>[1]) => options ? router.push(inventoryHref(href), options) : router.push(inventoryHref(href)),
    replace: (href: string, options?: Parameters<typeof router.replace>[1]) => options ? router.replace(inventoryHref(href), options) : router.replace(inventoryHref(href)),
  }), [router]);
}
