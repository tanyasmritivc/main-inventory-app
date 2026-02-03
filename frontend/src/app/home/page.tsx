import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/site/app-shell";
import { HomeDocsClient } from "@/components/site/home-docs-client";
import { Button } from "@/components/ui/button";

export default async function HomePage() {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/signin?redirect=/home");
  }

  let firstName: string | null = null;
  try {
    const { data: profile } = await supabase.from("profiles").select("first_name,last_name").eq("id", user.id).maybeSingle();
    firstName = (profile?.first_name || "").trim() || null;

    if (!firstName) {
      const md = (user.user_metadata || {}) as Record<string, unknown>;
      const given = typeof md.given_name === "string" ? md.given_name.trim() : "";
      const family = typeof md.family_name === "string" ? md.family_name.trim() : "";
      if (given || family) {
        await supabase.from("profiles").upsert({ id: user.id, first_name: given, last_name: family });
        firstName = given || null;
      }
    }
  } catch {
    // ignore
  }

  const name = firstName || user.email || "there";

  return (
    <AppShell>
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-2 duration-500">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-semibold tracking-tight">Welcome back, {name} 👋</h1>
            <p className="text-sm text-muted-foreground">Here’s a quick overview of your workspace.</p>
          </div>
          <Button asChild variant="outline">
            <Link href="/dashboard">Start a chat</Link>
          </Button>
        </div>

        <HomeDocsClient />
      </div>
    </AppShell>
  );
}
