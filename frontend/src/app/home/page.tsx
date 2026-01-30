import Link from "next/link";
import { redirect } from "next/navigation";

import { createSupabaseServerClient } from "@/lib/supabase/server";
import { SiteNav } from "@/components/site/nav";
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

  const name = user.user_metadata?.full_name || user.email || "there";

  return (
    <div className="min-h-screen">
      <SiteNav variant="app" />
      <main className="w-full px-4 py-10">
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
      </main>
    </div>
  );
}
