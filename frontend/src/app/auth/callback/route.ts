import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
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
    const response = NextResponse.redirect(new URL(next, publicOrigin));
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            for (const { name, value } of cookiesToSet) {
              request.cookies.set(name, value);
            }
            for (const { name, value, options } of cookiesToSet) {
              response.cookies.set(name, value, options);
            }
          },
        },
      },
    );
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return response;
  }

  const failure = new URL("/reset-password", publicOrigin);
  failure.searchParams.set("error", "expired");
  return NextResponse.redirect(failure);
}
