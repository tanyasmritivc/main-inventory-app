import { requireUser } from "@/lib/auth-guard";
import { WorldEntry } from "@/components/site/world-entry";
export const metadata = {
  title: "Opening FindEZ",
  robots: { index: false, follow: false },
};
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const query = q?.slice(0, 4000) || "";
  await requireUser(
    `/worlds${query ? `?${new URLSearchParams({ q: query })}` : ""}`,
  );
  return <WorldEntry query={query} />;
}
