import { GET } from "@/app/auth/callback/route";
import { createSupabaseServerClient } from "@/lib/supabase/server";

jest.mock("@/lib/supabase/server", () => ({ createSupabaseServerClient: jest.fn() }));
const exchange = jest.fn();
beforeEach(() => {
  jest.clearAllMocks();
  (createSupabaseServerClient as jest.Mock).mockResolvedValue({ auth: { exchangeCodeForSession: exchange } });
  exchange.mockResolvedValue({ error: null });
});

test("exchanges the OAuth code before redirecting to the requested page", async () => {
  const response = await GET(new Request("https://findez.ai/auth/callback?code=test-code&next=/inventory"));
  expect(exchange).toHaveBeenCalledWith("test-code");
  expect(response.headers.get("location")).toBe("/inventory");
  expect(response.headers.get("cache-control")).toBe("no-store");
});

test.each(["https://evil.example", "//evil.example", "/\\evil.example", "/\nevil.example"])("rejects unsafe destination %s", async (next) => {
  const response = await GET(new Request(`https://findez.ai/auth/callback?code=test&next=${encodeURIComponent(next)}`));
  expect(response.headers.get("location")).toBe("/inventory");
});

test("failed exchanges return to sign-in instead of a protected page", async () => {
  exchange.mockResolvedValue({ error: new Error("expired") });
  const response = await GET(new Request("https://findez.ai/auth/callback?code=expired"));
  expect(response.headers.get("location")).toContain("/signin?auth_error=callback");
});

test("provider cancellation does not attempt a code exchange", async () => {
  const response = await GET(new Request("https://findez.ai/auth/callback?error=access_denied"));
  expect(exchange).not.toHaveBeenCalled();
  expect(response.headers.get("location")).toContain("/signin?auth_error=callback");
});


test("password recovery failures keep the reset-specific error", async () => {
  const response = await GET(new Request("https://findez.ai/auth/callback?next=/reset-password&error=access_denied"));
  expect(response.headers.get("location")).toBe("/reset-password?error=expired");
});

test("unexpected exchange failures return a retryable sign-in page", async () => {
  exchange.mockRejectedValue(new Error("network unavailable"));
  const response = await GET(new Request("https://findez.ai/auth/callback?code=test"));
  expect(response.headers.get("location")).toContain("/signin?auth_error=callback");
});


test("successful recovery exchanges the code and opens the password form", async () => {
  const response = await GET(new Request("https://findez.ai/auth/callback?code=recovery&next=/reset-password"));
  expect(exchange).toHaveBeenCalledWith("recovery");
  expect(response.headers.get("location")).toBe("/reset-password");
});

test("redirects remain on the public site behind the reverse proxy", async () => {
  const response = await GET(new Request("http://localhost:3000/auth/callback?code=test", {
    headers: { "x-forwarded-host": "findez.ai", "x-forwarded-proto": "https" },
  }));
  expect(response.headers.get("location")).toBe("/inventory");
});
