import { redirect } from "next/navigation";
import { AppShell } from "@/components/site/app-shell";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function ProtectedAppPage({ children, returnTo }: { children: React.ReactNode; returnTo: string }) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/signin?redirect=${encodeURIComponent(returnTo)}`);
  return <AppShell>{children}</AppShell>;
}
