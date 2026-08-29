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
    pathname.startsWith("/settings") ||
    pathname.startsWith("/upgrade") ||
    pathname.startsWith("/upgrade-success");

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/signin";
    url.searchParams.set("redirect", pathname);
    return NextResponse.redirect(url);
  }

  if ((pathname === "/signin" || pathname === "/signup") && user) {
    const url = request.nextUrl.clone();
    url.pathname = "/settings";
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: [
    "/settings/:path*",
    "/upgrade/:path*",
    "/upgrade-success/:path*",
    "/signin",
    "/signup",
  ],
};
