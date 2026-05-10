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
          <h1 className="text-[28px] font-semibold tracking-[-0.01em] text-white">Manuals &amp; Receipts</h1>
          <p className="text-[14px] text-white/45">Upload and manage product manuals, receipts, and other documents.</p>
        </div>
        <DocumentsClient />
      </div>
    </AppShell>
  );
}
