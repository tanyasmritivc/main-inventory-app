import { AppShell } from "@/components/site/app-shell";
import { SharedSpaceClient } from "@/components/site/shared-space-client";
import { requireUser } from "@/lib/auth-guard";

export default async function SharedSpacePage({
  params,
}: {
  params: Promise<{ shareId: string }>;
}) {
  const { shareId } = await params;
  await requireUser(`/sharing/${encodeURIComponent(shareId)}`);

  return (
    <AppShell>
      <SharedSpaceClient shareId={shareId} />
    </AppShell>
  );
}
