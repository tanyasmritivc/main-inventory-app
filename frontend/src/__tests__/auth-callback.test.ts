import { createServerClient } from "@supabase/ssr";
import { NextRequest } from "next/server";

import { GET } from "@/app/auth/callback/route";

jest.mock("@supabase/ssr", () => ({
  createServerClient: jest.fn(),
}));

describe("OAuth callback", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://auth.example.com";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";
    jest.clearAllMocks();
  });

  it("sets the exchanged session cookies on the redirect response", async () => {
    (createServerClient as jest.Mock).mockImplementation(
      (_url: string, _key: string, options: { cookies: { setAll: (cookies: unknown[]) => void } }) => ({
        auth: {
          exchangeCodeForSession: async () => {
            options.cookies.setAll([
              {
                name: "sb-access-token",
                value: "new-session",
                options: { httpOnly: true, path: "/", sameSite: "lax" },
              },
            ]);
            return { error: null };
          },
        },
      }),
    );

    const request = new NextRequest(
      "https://findez.ai/auth/callback?code=oauth-code&next=/inventory",
      {
        headers: {
          "x-forwarded-host": "findez.ai",
          "x-forwarded-proto": "https",
        },
      },
    );

    const response = await GET(request);

    expect(response.headers.get("location")).toBe("https://findez.ai/inventory");
    expect(response.cookies.get("sb-access-token")?.value).toBe("new-session");
  });
});
