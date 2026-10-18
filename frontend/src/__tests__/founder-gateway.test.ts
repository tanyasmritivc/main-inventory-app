import { NextRequest } from "next/server";
import { GET, POST } from "@/app/api/founder/[...path]/route";

const originalFetch = global.fetch;
const context = (path: string[]) => ({ params: Promise.resolve({ path }) });
beforeEach(() => { global.fetch = jest.fn(); });
afterAll(() => { global.fetch = originalFetch; });

test("forwards the founder token to the fixed local service without website cookies", async () => {
  (global.fetch as jest.Mock).mockResolvedValue(new Response('{"ok":true}', { status: 200 }));
  const response = await GET(new NextRequest("https://findez.ai/api/founder/v1/snapshot", { headers: { Authorization: "Bearer founder-test-token", Cookie: "website-cookie=private" } }), context(["v1", "snapshot"]));
  const [target, options] = (global.fetch as jest.Mock).mock.calls[0];
  expect(target).toBe("http://127.0.0.1:8031/dashboard/v1/snapshot");
  expect(options.headers.get("Authorization")).toBe("Bearer founder-test-token");
  expect(options.headers.get("Cookie")).toBeNull();
  expect(options.cache).toBe("no-store");
  expect(response.headers.get("Cache-Control")).toContain("no-store");
});

test("preserves the service's unauthenticated rejection", async () => {
  (global.fetch as jest.Mock).mockResolvedValue(new Response('{"detail":"Sign in"}', { status: 401 }));
  const response = await GET(new NextRequest("https://findez.ai/api/founder/v1/snapshot"), context(["v1", "snapshot"]));
  expect(response.status).toBe(401);
  expect(await response.json()).toEqual({ detail: "Sign in" });
});

test.each([["v1", "issues", "..", "snapshot"], ["https:", "example.test"], ["v1", "admin", "users"]])("rejects unexpected routes before making network requests: %j", async (...path: string[]) => {
  const response = await GET(new NextRequest("https://findez.ai/api/founder/invalid"), context(path));
  expect(response.status).toBe(404);
  expect(global.fetch).not.toHaveBeenCalled();
});

test("bounds issue and login request sizes before forwarding", async () => {
  const request = new NextRequest("https://findez.ai/api/founder/v1/issues", { method: "POST", body: "x".repeat(16_385) });
  const response = await POST(request, context(["v1", "issues"]));
  expect(response.status).toBe(413);
  expect(global.fetch).not.toHaveBeenCalled();
});

test("does not expose a local service failure", async () => {
  (global.fetch as jest.Mock).mockRejectedValue(new Error("private server details"));
  const response = await GET(new NextRequest("https://findez.ai/api/founder/v1/snapshot"), context(["v1", "snapshot"]));
  expect(response.status).toBe(503);
  expect(await response.text()).not.toContain("private server details");
});
