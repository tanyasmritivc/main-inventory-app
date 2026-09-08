import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { safeAuthRedirect } from "@/lib/supabase/redirect";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const next = safeAuthRedirect(searchParams.get("next"));
  const code = searchParams.get("code");

  if (code && !searchParams.has("error")) {
    try {
      const supabase = await createSupabaseServerClient();
      const { error } = await supabase.auth.exchangeCodeForSession(code);
      if (!error) {
        return new NextResponse(null, {
          status: 303,
          headers: { Location: next, "Cache-Control": "no-store" },
        });
      }
    } catch {
      // Return a retryable sign-in screen without exposing server errors.
    }
  }

  return new NextResponse(null, {
    status: 303,
    headers: {
      Location: next.split("?")[0] === "/reset-password"
        ? "/reset-password?error=expired"
        : `/signin?auth_error=callback&redirect=${encodeURIComponent(next)}`,
      "Cache-Control": "no-store",
    },
  });
}
