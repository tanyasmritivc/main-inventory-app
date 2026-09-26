import { AppShell } from "@/components/site/app-shell";
import { DocumentsClient } from "@/components/site/documents-client";
import { requireUser } from "@/lib/auth-guard";

export default async function DocumentsPage() {
  await requireUser("/documents");

  return (
    <AppShell>
      <DocumentsClient />
    </AppShell>
  );
}
