import { requireUser } from "@/lib/auth-guard";
import { WorldWorkspace } from "@/components/site/world-workspace";
export const metadata = {
  title: "Your organization",
  robots: { index: false, follow: false },
};
export default async function WorldPage({
  params,
  searchParams,
}: {
  params: Promise<{ worldId: string }>;
  searchParams: Promise<{ view?: string; q?: string; space?: string }>;
}) {
  const { worldId } = await params;
  const query = await searchParams;
  const retained = new URLSearchParams();
  if (query.view) retained.set("view", query.view);
  if (query.space) retained.set("space", query.space);
  if (query.q) retained.set("q", query.q.slice(0, 4000));
  await requireUser(
    `/worlds/${encodeURIComponent(worldId)}${retained.size ? `?${retained}` : ""}`,
  );
  return (
    <WorldWorkspace
      worldId={worldId}
      orderSpaceId={query.space}
      view={query.view || "chat"}
      initialQuery={query.q?.slice(0, 4000) || ""}
    />
  );
}
