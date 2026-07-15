import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { SharedSpaceClient } from "@/components/site/shared-space-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function SharedSpacePage({
  params,
}: {
  params: Promise<{ shareId: string }>;
}) {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/inventory");
  }

  const { shareId } = await params;

  return (
    <AppShell>
      <SharedSpaceClient shareId={shareId} />
    </AppShell>
  );
}
