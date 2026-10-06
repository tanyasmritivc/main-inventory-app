import { AppShell } from "@/components/site/app-shell";
import { DocumentsClient } from "@/components/site/documents-client";
import { requireUser } from "@/lib/auth-guard";

export default async function DocumentsPage({
  searchParams,
}: {
  searchParams: Promise<{ item?: string }>;
}) {
  const { item } = await searchParams;
  await requireUser("/documents");

  return (
    <AppShell>
      <DocumentsClient initialItem={typeof item === "string" ? item : ""} />
    </AppShell>
  );
}
