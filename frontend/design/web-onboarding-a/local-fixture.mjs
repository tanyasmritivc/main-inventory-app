// Disposable, loopback-only auth/API fixtures for browser QA. No external I/O.
// Start: node design/web-onboarding-a/local-fixture.mjs
// Next dev must use the three localhost NEXT_PUBLIC values in IMPLEMENTATION.md.
import http from "node:http";
import { randomUUID } from "node:crypto";
const users = new Map(), accounts = new Map();
const encode = value => Buffer.from(JSON.stringify(value)).toString("base64url");
function session(user) {
  const now = Math.floor(Date.now() / 1000);
  return { access_token: `${encode({ alg: "HS256", typ: "JWT" })}.${encode({ sub: user.id, exp: now + 3600, iat: now, role: "authenticated", aud: "authenticated" })}.local-test-only`, token_type: "bearer", refresh_token: `fixture-${user.id}`, expires_in: 3600, expires_at: now + 3600, user };
}
http.createServer(async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "http://localhost:3086");
  res.setHeader("Access-Control-Allow-Headers", "authorization,apikey,content-type,x-client-info,x-supabase-api-version,prefer,range,accept-profile,content-profile");
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,OPTIONS,DELETE");
  res.setHeader("Content-Type", "application/json");
  const send = (data, status = 200) => { res.statusCode = status; res.end(JSON.stringify(data)); };
  if (req.method === "OPTIONS") return send({});
  const url = new URL(req.url, "http://localhost:3085"), path = url.pathname;
  let text = ""; for await (const chunk of req) text += chunk;
  let body = {}; try { body = JSON.parse(text || "{}"); } catch { return send({}, 400); }
  // Synthetic browser entry: no real signup, password, email or legal acceptance.
  if (path === "/fixture/enter") {
    const user = { id: randomUUID(), email: `qa-${randomUUID()}@example.test`, aud: "authenticated", role: "authenticated", email_confirmed_at: new Date().toISOString(), created_at: new Date().toISOString(), user_metadata: {}, app_metadata: { provider: "email", providers: ["email"] }, identities: [] };
    users.set(user.id, user); accounts.set(user.id, { organizations: [], workspaces: [], inventories: [{ inventory_id: randomUUID(), owner_user_id: user.id, name: "My inventory", is_default: true, workspace_id: "personal" }] });
    res.setHeader("Set-Cookie", `sb-localhost-auth-token=base64-${encode(session(user))}; Path=/; SameSite=Lax; Max-Age=3600`);
    res.setHeader("Location", "http://localhost:3086/onboarding"); res.statusCode = 302; return res.end();
  }
  if (path === "/auth/v1/signup" || path === "/auth/v1/token") {
    if (!body.email?.endsWith("@example.test")) return send({ message: "Use an @example.test address in this local fixture." }, 400);
    let user = [...users.values()].find(u => u.email === body.email);
    if (!user) {
      user = { id: randomUUID(), email: body.email, aud: "authenticated", role: "authenticated", email_confirmed_at: new Date().toISOString(), created_at: new Date().toISOString(), user_metadata: body.data || {}, app_metadata: { provider: "email", providers: ["email"] }, identities: [] };
      users.set(user.id, user); accounts.set(user.id, { organizations: [], workspaces: [], inventories: [{ inventory_id: randomUUID(), owner_user_id: user.id, name: "My inventory", is_default: true, workspace_id: "personal" }] });
    }
    return send(session(user));
  }
  if (path === "/auth/v1/logout") return send({});
  let id; try { id = JSON.parse(Buffer.from((req.headers.authorization || "").split(".")[1] || "", "base64url")).sub; } catch { /* Anonymous fixture request. */ }
  const user = users.get(id), data = accounts.get(id);
  if (!user) return send({ message: "Local fixture session required." }, 401);
  if (path === "/auth/v1/user") return send(user);
  if (path.startsWith("/rest/v1/")) return send(path.endsWith("profiles") ? [{ id, display_name: "Local QA" }] : []);
  const personal = { workspace_id: "personal", name: "Personal", kind: "personal", team_id: null, role: "owner", owner_user_id: id };
  if (req.method === "POST") {
    await new Promise(resolve => setTimeout(resolve, 450));
    if (path === "/organizations") { const organization = { organization_id: randomUUID(), name: body.name, owner_user_id: id, role: "owner" }; data.organizations.push(organization); return send({ organization }); }
    if (path === "/teams" || /^\/organizations\/[^/]+\/workspaces$/.test(path)) {
      const wid = randomUUID(), workspace = { workspace_id: wid, team_id: wid, name: body.name, owner_user_id: id, kind: "team", role: "owner", organization_id: path === "/teams" ? null : path.split("/")[2] };
      data.workspaces.push(workspace); return send(path === "/teams" ? { team: workspace } : { workspace });
    }
    if (/^\/inventory-workspaces\/[^/]+\/inventories$/.test(path)) { const inventory = { inventory_id: randomUUID(), owner_user_id: id, workspace_id: path.split("/")[2], name: body.name, is_default: false }; data.inventories.push(inventory); return send({ inventory }); }
    return send({});
  }
  if (path === "/organizations") return send({ organizations: data.organizations });
  if (path === "/inventory-workspaces") return send({ workspaces: [personal, ...data.workspaces] });
  if (/^\/organizations\/[^/]+$/.test(path)) return send({ organization: data.organizations.find(o => o.organization_id === path.split("/")[2]), workspaces: data.workspaces.filter(w => w.organization_id === path.split("/")[2]), members: [] });
  if (/^\/inventory-workspaces\/[^/]+\/(inventories|directory)$/.test(path)) {
    const wid = path.split("/")[2]; return send({ workspace: wid === "personal" ? personal : data.workspaces.find(w => w.workspace_id === wid), inventories: data.inventories.filter(i => i.workspace_id === wid), total: data.inventories.length, next_offset: null });
  }
  if (/^\/inventories\/[^/]+$/.test(path)) { const inventory = data.inventories.find(i => i.inventory_id === path.split("/")[2]); return send({ inventory: { ...inventory, workspace: inventory?.workspace_id === "personal" ? personal : data.workspaces.find(w => w.workspace_id === inventory?.workspace_id), can_open: true, can_edit: true, role: "owner" } }); }
  if (path.includes("notifications")) return send({ notifications: [], unread_count: 0 });
  return send({ items: [], spaces: [], recent_items: [], reviews: [], total: 0, count: 0 });
}).listen(3085, "127.0.0.1", () => process.stdout.write("Local onboarding auth/API fixtures: http://localhost:3085\n"));
