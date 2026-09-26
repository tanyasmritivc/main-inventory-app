import { AppShell } from "@/components/site/app-shell";
import { CollectionsClient } from "@/components/site/collections-client";
import { requireUser } from "@/lib/auth-guard";

export default async function CollectionsPage() {
  await requireUser("/collections");

  return (
    <AppShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-[28px] font-semibold tracking-[-0.01em] text-[#000000]">Smart Collections</h1>
          <p className="text-[14px] text-[#65545e]">Pre-built views for common tasks</p>
        </div>
        <CollectionsClient />
      </div>
    </AppShell>
  );
}
