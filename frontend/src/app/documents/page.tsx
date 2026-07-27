import { redirect } from "next/navigation";

import { AppShell } from "@/components/site/app-shell";
import { DocumentsClient } from "@/components/site/documents-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export default async function DocumentsPage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/documents");
  }

  return (
    <AppShell>
      <DocumentsClient />
    </AppShell>
  );
}
