import { CollectionsClient } from "@/components/site/collections-client";
import { requireUser } from "@/lib/auth-guard";

export const metadata = { title: "Collections" };

export default async function CollectionsPage() {
  await requireUser("/collections");

  return <CollectionsClient />;
}
