import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

export async function middleware(request: NextRequest) {
  const response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
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
  const isProtected =
    pathname.startsWith("/dashboard") ||
    pathname.startsWith("/home") ||
    pathname.startsWith("/inventory") ||
    pathname.startsWith("/checkout") ||
    pathname.startsWith("/collections") ||
    pathname.startsWith("/documents") ||
    pathname.startsWith("/settings") ||
    pathname.startsWith("/sharing") ||
    pathname.startsWith("/shopping-list") ||
    pathname.startsWith("/upgrade") ||
    pathname.startsWith("/upgrade-success") ||
    pathname.startsWith("/onboarding");

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/signin";
    url.searchParams.set("redirect", pathname);
    return NextResponse.redirect(url);
  }

  if ((pathname === "/signin" || pathname === "/signup") && user) {
    const url = request.nextUrl.clone();
    url.pathname = "/home";
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/home/:path*",
    "/inventory/:path*",
    "/checkout/:path*",
    "/collections/:path*",
    "/documents/:path*",
    "/settings/:path*",
    "/sharing/:path*",
    "/shopping-list/:path*",
    "/upgrade/:path*",
    "/upgrade-success/:path*",
    "/onboarding/:path*",
    "/signin",
    "/signup",
  ],
};
