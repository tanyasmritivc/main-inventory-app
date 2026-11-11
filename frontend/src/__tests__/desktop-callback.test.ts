/** @jest-environment node */
import { GET } from "../app/desktop/callback/route";
const state = "s".repeat(43);
const code = "c".repeat(32);
describe("desktop PKCE return page", () => {
  it("returns only the authorization code to the app with no scripts or caching", async () => {
    const response = GET(new Request(`https://www.findez.ai/desktop/callback?state=${state}&code=${code}`));
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    const html = await response.text();
    expect(html).toContain(`findez-desktop://auth/callback?state=${state}&amp;code=${code}`);
    expect(html).not.toContain("<script");
    expect(html).toContain('<meta name="referrer" content="no-referrer">');
  });
  it.each(["", `state=${state}&code=bad`, `state=${state}&state=${state}&code=${code}`, `state=<script>&code=${code}`])("rejects malformed callback: %s", async query => {
    const response = GET(new Request("https://www.findez.ai/desktop/callback?" + query));
    expect(response.status).toBe(400);
    expect(await response.text()).not.toContain("findez-desktop:");
  });
  it("never includes provider error text or bearer tokens in the return link", async () => {
    const response = GET(new Request(`https://www.findez.ai/desktop/callback?state=${state}&error=secret&access_token=private`));
    const html = await response.text();
    expect(html).toContain("error=auth_failed");
    expect(html).not.toContain("secret");
    expect(html).not.toContain("private");
  });
});
