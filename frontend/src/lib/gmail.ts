import { accountRequest } from "@/lib/account-request";
import { getAccessSession } from "@/lib/session";
import { callbackParameters, commercePath } from "@/lib/commerce";

const key = "findez.gmail.pending";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
type Pending = { accountId: string; inventoryId: string; connectionId: string; state: string; expires: number };

export function gmailRedirect(result: { connection_id: string; authorization_url: string; expires_in: number }, accountId: string, inventoryId: string, origin: string, storage: Storage) {
  const url = new URL(result.authorization_url);
  const callback = new URL(url.searchParams.get("redirect_uri") || "");
  const state = url.searchParams.get("state");
  if (url.origin !== "https://accounts.google.com" || url.username || url.password || url.hash || url.pathname !== "/o/oauth2/v2/auth" ||
      callback.origin !== origin || callback.pathname !== "/connect/gmail/callback" || callback.search || callback.hash ||
      !state || url.searchParams.getAll("state").length !== 1 || url.searchParams.getAll("redirect_uri").length !== 1 ||
      url.searchParams.get("scope") !== "https://www.googleapis.com/auth/gmail.readonly" ||
      !uuid.test(result.connection_id) || !uuid.test(inventoryId) || result.expires_in !== 600) throw new Error("Gmail authorization could not be prepared. Check the callback configuration.");
  const pending: Pending = { accountId, inventoryId, connectionId: result.connection_id, state, expires: Date.now() + 600000 };
  storage.setItem(key, JSON.stringify(pending));
  return url.href;
}

export async function completeGmail(browser: Pick<Window, "location" | "history" | "sessionStorage">) {
  const search = browser.location.search;
  browser.history.replaceState(null, "", browser.location.pathname);
  const params = callbackParameters(search);
  let pending: Pending;
  try { pending = JSON.parse(browser.sessionStorage.getItem(key) || "null"); }
  catch { throw new Error("Start the Gmail connection again from Connections."); }
  browser.sessionStorage.removeItem(key);
  if (!pending || pending.state !== params.state || !uuid.test(pending.inventoryId) || !uuid.test(pending.connectionId) ||
      !Number.isFinite(pending.expires) || pending.expires < Date.now() || pending.expires > Date.now() + 600000 || params.error || !params.code) throw new Error("Gmail authorization expired or was cancelled. Return to Connections to start again.");
  const session = await getAccessSession();
  if (!session || session.accountId !== pending.accountId) throw new Error("Sign in to the FindEZ account that started this connection and start again.");
  const result = await accountRequest<{ connected: boolean }>(pending.accountId, "/commerce/gmail/complete", { method: "POST", body: {
    inventory_id: pending.inventoryId, connection_id: pending.connectionId, state: params.state, code: params.code,
  } });
  if (!result.connected) throw new Error("Gmail connection was not confirmed. Check Connections before retrying.");
  return commercePath(pending.inventoryId);
}
