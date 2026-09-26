import { NextRequest } from "next/server";
import { redirect } from "next/navigation";
import { createServerClient } from "@supabase/ssr";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { requireUser, signInPath } from "@/lib/auth-guard";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
import CheckoutPage from "@/app/checkout/page";
import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { isProtectedPath, PROTECTED_ROUTE_PREFIXES } from "@/lib/protected-routes";
import { config, middleware } from "../../middleware";

class RedirectSignal extends Error {
  constructor(public destination: string) { super(`redirect:${destination}`); }
}

jest.mock("next/navigation", () => ({
  redirect: jest.fn((destination: string) => { throw new RedirectSignal(destination); }),
}));
jest.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient: jest.fn() }));
jest.mock("@supabase/ssr", () => ({ createServerClient: jest.fn() }));
jest.mock("@/components/site/app-shell", () => ({ AppShell: ({ children }: { children: unknown }) => children }));
jest.mock("@/components/site/checkout-client", () => ({ CheckoutClient: () => "checkout-client" }));

function serverUser(user: unknown) {
  jest.mocked(createSupabaseServerClient).mockResolvedValue({
    auth: { getUser: async () => ({ data: { user } }) },
  } as unknown as Awaited<ReturnType<typeof createSupabaseServerClient>>);
}

beforeEach(() => jest.clearAllMocks());

describe("server auth guard", () => {
  test("redirects an anonymous visitor to sign-in with an encoded return path", async () => {
    serverUser(null);
    await expect(requireUser("/inventory?space=Shelf B")).rejects.toMatchObject({
      destination: "/signin?redirect=%2Finventory%3Fspace%3DShelf%20B",
    });
    expect(redirect).toHaveBeenCalledTimes(1);
  });

  test("returns the verified user", async () => {
    serverUser({ id: "u1", email: "a@example.com" });
    await expect(requireUser("/home")).resolves.toMatchObject({ id: "u1" });
    expect(redirect).not.toHaveBeenCalled();
  });

  test("protected pages do not render content before authentication", async () => {
    serverUser(null);
    await expect(ProtectedAppPage({ children: "secret", returnTo: "/teams" })).rejects.toBeInstanceOf(RedirectSignal);
    serverUser({ id: "u1" });
    await expect(ProtectedAppPage({ children: "secret", returnTo: "/teams" })).resolves.toBeTruthy();
  });

  test("Check-outs is guarded on the server like the other workspace pages", async () => {
    serverUser(null);
    const page = CheckoutPage();
    await expect(Promise.resolve(page.type(page.props))).rejects.toMatchObject({
      destination: signInPath("/checkout"),
    });
  });
});

describe("middleware", () => {
  function sessionUser(user: unknown) {
    jest.mocked(createServerClient).mockReturnValue({
      auth: { getUser: async () => ({ data: { user } }) },
    } as unknown as ReturnType<typeof createServerClient>);
  }

  test("sends a signed-in visitor on /signin to the requested local destination", async () => {
    sessionUser({ id: "u1" });
    const response = await middleware(new NextRequest("https://findez.ai/signin?redirect=%2Finventory%3Fspace%3DShelf"));
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe("https://findez.ai/inventory?space=Shelf");
  });

  test("never redirects a signed-in visitor off-site", async () => {
    sessionUser({ id: "u1" });
    const response = await middleware(new NextRequest("https://findez.ai/signup?redirect=https://attacker.example"));
    expect(response.headers.get("location")).toBe("https://findez.ai/home");
  });

  test("redirects anonymous workspace requests before any page streams", async () => {
    sessionUser(null);
    const response = await middleware(new NextRequest("https://findez.ai/inventory?space=Shelf%20B"));
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe(
      "https://findez.ai/signin?redirect=%2Finventory%3Fspace%3DShelf%2520B",
    );
    for (const path of ["/settings", "/documents", "/checkout", "/sharing/share-1"]) {
      const next = await middleware(new NextRequest(`https://findez.ai${path}`));
      expect(next.headers.get("location")).toBe(`https://findez.ai${signInPath(path)}`);
    }
  });

  test("leaves public routes open to anonymous visitors", async () => {
    sessionUser(null);
    for (const path of ["/", "/signin", "/signup", "/join/ABC123", "/join/team/TEAM12", "/privacy", "/terms", "/mobile-app", "/docs/api", "/auth/callback", "/reset-password"]) {
      const response = await middleware(new NextRequest(`https://findez.ai${path}`));
      expect(response.headers.get("location")).toBeNull();
    }
  });

  test("the matcher skips the AASA and static assets but covers app routes", () => {
    const pattern = new RegExp(`^${config.matcher[0]}$`);
    expect(pattern.test("/home")).toBe(true);
    expect(pattern.test("/inventory")).toBe(true);
    expect(pattern.test("/signin")).toBe(true);
    expect(pattern.test("/.well-known/apple-app-site-association")).toBe(false);
    expect(pattern.test("/images/findez-mark.svg")).toBe(false);
    expect(pattern.test("/_next/static/chunk.js")).toBe(false);
    expect(pattern.test("/docs/api/findez-openapi.json")).toBe(false);
  });
});

describe("protected route inventory", () => {
  const appDir = path.join(__dirname, "../app");
  function pages(dir: string): string[] {
    return readdirSync(dir).flatMap((name) => {
      const full = path.join(dir, name);
      if (statSync(full).isDirectory()) return pages(full);
      return name === "page.tsx" ? [full] : [];
    });
  }
  const guarded = pages(appDir)
    .filter((file) => /requireUser\(|ProtectedAppPage/.test(readFileSync(file, "utf8")))
    .map((file) => `/${path.relative(appDir, path.dirname(file))}`.replace(/\[[^\]]+\]/g, "x"));

  test("every server-guarded page is covered by the middleware list", () => {
    expect(guarded.length).toBeGreaterThan(10);
    for (const route of guarded) expect([route, isProtectedPath(route)]).toEqual([route, true]);
  });

  test("every protected prefix has a server-guarded page", () => {
    for (const prefix of PROTECTED_ROUTE_PREFIXES) {
      expect([prefix, guarded.some((route) => route === prefix || route.startsWith(`${prefix}/`))]).toEqual([prefix, true]);
    }
  });
});
