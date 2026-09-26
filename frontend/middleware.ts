import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";
import { normalizeAuthNext } from "@/lib/auth-callback";
import { signInPath } from "@/lib/auth-paths";
import { isProtectedPath } from "@/lib/protected-routes";

/**
 * Keeps the Supabase session fresh for server rendering. Server Components cannot
 * write cookies, so token refresh must happen here and be persisted on the response.
 *
 * Anonymous requests for authenticated routes are redirected here, before any HTML
 * streams. Each page still calls `requireUser()` (lib/auth-guard.ts) on the server
 * as the authoritative check.
 */
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
          response = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const pathname = request.nextUrl.pathname;
  if (!user && isProtectedPath(pathname)) {
    const redirect = NextResponse.redirect(new URL(signInPath(pathname + request.nextUrl.search), request.url));
    for (const cookie of response.cookies.getAll()) redirect.cookies.set(cookie);
    return redirect;
  }

  if ((pathname === "/signin" || pathname === "/signup") && user) {
    // Signed-in visitors continue to their requested local destination.
    const target = new URL(normalizeAuthNext(request.nextUrl.searchParams.get("redirect")), request.url);
    const redirect = NextResponse.redirect(target);
    for (const cookie of response.cookies.getAll()) redirect.cookies.set(cookie);
    return redirect;
  }

  return response;
}

export const config = {
  matcher: [
    // Everything except static assets, images, and well-known files such as the
    // apple-app-site-association, which must be served without redirects.
    "/((?!_next/static|_next/image|images/|docs/api/.*\\.json|\\.well-known/|favicon\\.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|txt|xml|json)$).*)",
  ],
};
