import { apiBase } from "@/lib/api";

export type KeyScope = "items:read" | "items:write" | "import:write" | "workspace:read" | "org:read" | "org:write";
export type IntegrationKey = {
  id: string; workspace_id: string | null; name: string; key_prefix: string;
  scopes: KeyScope[]; created_at: string; last_used_at: string | null;
  expires_at: string | null; revoked_at: string | null;
};
export type KeyWorkspace = { team_id: string; name: string };
export type CreateIntegrationKey = {
  name: string; workspace_id: string | null; scopes: KeyScope[]; expires_at: string | null;
};

const ERROR_MESSAGES: Record<string, string> = {
  workspace_access_denied: "Only the team owner can manage integrations for this workspace.",
  organization_required: "Create a team first, then return here to create its API key.",
  invalid_expiration: "Choose an expiration date in the future.",
  invalid_api_key: "This API key is invalid. Check that you copied the entire key.",
  revoked_api_key: "This API key has been revoked.",
  expired_api_key: "This API key has expired.",
  wrong_environment: "This key belongs to a different FindEZ environment.",
  insufficient_scope: "This key does not have permission for that operation.",
  key_not_found: "This key was not found or has already been revoked. Refresh the list.",
  rate_limit_exceeded: "This key has reached its request limit. Try again in a minute.",
};

async function request<T>(path: string, token: string, method = "GET", body?: unknown): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${apiBase().replace(/\/$/, "")}/api/v1${path}`, {
      method, cache: "no-store",
      headers: { Authorization: `Bearer ${token}`, ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw new Error("Could not connect to FindEZ. Check your connection and try again.");
  }
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const code = data?.detail?.code;
    throw new Error(ERROR_MESSAGES[code] ?? (response.status === 401
      ? "Your session has expired. Sign in again."
      : "The request could not be completed. Please try again."));
  }
  if (data === null) throw new Error("FindEZ returned an invalid response. Please try again.");
  return data as T;
}

export const listIntegrationKeys = (token: string) => request<{ keys: IntegrationKey[] }>("/keys", token);
export const listKeyWorkspaces = (token: string) => request<{ workspaces: KeyWorkspace[] }>("/keys/workspaces", token);
export const createIntegrationKey = (token: string, body: CreateIntegrationKey) => request<IntegrationKey & { key: string }>("/keys", token, "POST", body);
export const revokeIntegrationKey = (token: string, id: string) => request<{ revoked: true; revoked_at: string }>(`/keys/${encodeURIComponent(id)}`, token, "DELETE");

export async function testIntegrationKey(key: string): Promise<string> {
  const identity = await request<{ scopes: KeyScope[] }>("/whoami", key);
  if (identity.scopes.includes("items:read") || identity.scopes.includes("org:read")) {
    const count = await request<{ value: number }>("/query", key, "POST", { resource: "items", aggregate: "count" });
    return `Connected. This key can read ${count.value} inventory items.`;
  }
  if (identity.scopes.includes("workspace:read")) {
    await request("/workspaces/summary", key);
    return "Connected. Workspace access verified.";
  }
  return "Key authentication passed. Write permissions were not exercised.";
}

export function integrationKeyStatus(key: Pick<IntegrationKey, "revoked_at" | "expires_at">): "Active" | "Expired" | "Revoked" {
  if (key.revoked_at) return "Revoked";
  if (key.expires_at && Date.parse(key.expires_at) <= Date.now()) return "Expired";
  return "Active";
}
