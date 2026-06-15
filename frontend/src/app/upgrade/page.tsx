import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/site/app-shell";
import { UpgradeClient } from "@/components/site/upgrade-client";

export default async function UpgradePage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/upgrade");
  }

  return (
    <AppShell>
      <div style={{ maxWidth: 720 }}>
        <h1
          style={{
            fontSize: 28,
            fontFamily: "var(--font-syne)",
            fontWeight: 600,
            color: "white",
            margin: 0,
          }}
        >
          Upgrade to Pro
        </h1>
        <p
          style={{
            fontSize: 14,
            color: "rgba(255,255,255,0.45)",
            marginTop: 8,
            marginBottom: 40,
          }}
        >
          Choose a plan that works for you.
        </p>
        <UpgradeClient />
      </div>
    </AppShell>
  );
}
