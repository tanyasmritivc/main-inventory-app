import { apiRequest, type ApiRequestOptions } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export async function accountToken(accountId: string): Promise<string> {
  const { data, error } = await createSupabaseBrowserClient().auth.getSession();
  if (error || !data.session || data.session.user.id !== accountId) {
    throw new Error("Your account changed. Reopen this page and try again.");
  }
  return data.session.access_token;
}

// Writes and their results belong to the account that initiated the action.
// Never replace that captured credential with a later account's session.
export async function accountRequest<T>(
  accountId: string,
  path: string,
  options: ApiRequestOptions = {},
): Promise<T> {
  const token = await accountToken(accountId);
  const result = await apiRequest<T>(path, {
    ...options,
    token,
    bindToToken: true,
  });
  await accountToken(accountId);
  return result;
}
