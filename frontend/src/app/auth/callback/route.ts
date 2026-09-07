import { NextResponse } from "next/server";

import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const forwardedHost = request.headers.get("x-forwarded-host");
  const forwardedProtocol = request.headers.get("x-forwarded-proto") || "https";
  const publicOrigin = forwardedHost
    ? `${forwardedProtocol}://${forwardedHost}`
    : url.origin;
  const code = url.searchParams.get("code");
  const requestedNext = url.searchParams.get("next") || "/inventory";
  const next = requestedNext.startsWith("/") && !requestedNext.startsWith("//")
    ? requestedNext
    : "/inventory";

  if (code) {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(next, publicOrigin));
  }

  const failure = new URL("/reset-password", publicOrigin);
  failure.searchParams.set("error", "expired");
  return NextResponse.redirect(failure);
}
