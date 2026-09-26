import { redirect } from "next/navigation";
import { signInPath } from "@/lib/auth-paths";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export { signInPath };

/**
 * Server-side guard for authenticated pages. Verifies the user with Supabase Auth
 * before any protected content renders and redirects to sign-in otherwise.
 */
export async function requireUser(returnTo: string) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(signInPath(returnTo));
  return user;
}
