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
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Documents</h1>
          <p className="text-sm text-muted-foreground">My uploaded files.</p>
        </div>
        <DocumentsClient />
      </div>
    </AppShell>
  );
}
