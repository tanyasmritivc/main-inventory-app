export type InventoryItem = {
  item_id: string;
  name: string;
  category: string;
  subcategory?: string | null;
  brand?: string | null;
  part_number?: string | null;
  tags?: string[] | null;
  confidence?: number | null;
  quantity: number;
  location: string;
  image_url?: string | null;
  barcode?: string | null;
  purchase_source?: string | null;
  notes?: string | null;
  created_at: string;
};

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

export class ApiError extends Error {
  status: number;
  upgrade_required: boolean;
  error: string | undefined;
  limitExceeded = false;
  limitData: unknown;

  constructor(message: string, status: number, detail: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.limitData = detail;
    const d =
      detail !== null && typeof detail === "object"
        ? (detail as Record<string, unknown>)
        : null;
    this.upgrade_required = Boolean(d?.upgrade_required);
    this.error = typeof d?.error === "string" ? (d.error as string) : undefined;
  }
}

function userFacingApiMessage(status: number, detail: unknown): string {
  const rawDetail = typeof detail === "string" ? detail.toLowerCase() : "";

  if (rawDetail.includes("share not found") || rawDetail.includes("revoked")) {
    return "We couldn't find an active space with that code. Ask the owner for a current code and try again.";
  }
  if (rawDetail.includes("cannot join your own")) {
    return "You already own this space. Send this code to a teammate signed in with a different FindEZ account.";
  }
  if (rawDetail.includes("already a member")) {
    return "You already have access to this space.";
  }
  if (status === 401) return "Your session has expired. Please sign in again.";
  if (status === 403) return "You don't have permission to do that.";
  if (status === 404) return "We couldn't find what you were looking for.";
  if (status === 429) return "You've reached a usage limit. Please try again later.";
  if (status >= 500) return "Something went wrong on our side. Please try again in a moment.";
  return "We couldn't complete that request. Please check the information and try again.";
}

async function apiFetch<T>(
  path: string,
  opts: { method?: string; token: string; body?: BodyInit | Record<string, unknown>; headers?: Record<string, string> }
): Promise<T> {
  let bodyToSend: BodyInit | undefined;
  const autoHeaders: Record<string, string> = {};
  if (opts.body !== undefined) {
    if (
      typeof opts.body === 'string' ||
      opts.body instanceof FormData ||
      opts.body instanceof Blob ||
      opts.body instanceof ArrayBuffer ||
      opts.body instanceof URLSearchParams
    ) {
      bodyToSend = opts.body as BodyInit;
    } else {
      bodyToSend = JSON.stringify(opts.body);
      autoHeaders['Content-Type'] = 'application/json';
    }
  }
  let res: Response;
  try {
    res = await fetch(`${apiBase()}${path}`, {
      method: opts.method || "GET",
      headers: {
        Authorization: `Bearer ${opts.token}`,
        ...autoHeaders,
        ...(opts.headers || {}),
      },
      body: bodyToSend,
    });
  } catch {
    throw new ApiError("We couldn't connect to FindEZ. Check your connection and try again.", 0, null);
  }

  if (!res.ok) {
    const text = await res.text();
    let bodyDetail: unknown = text;
    try {
      const parsed = JSON.parse(text) as Record<string, unknown>;
      bodyDetail = "detail" in parsed ? parsed.detail : parsed;
    } catch {}
    if (res.status === 429) {
      const err = new ApiError(userFacingApiMessage(res.status, bodyDetail), res.status, bodyDetail)
      err.limitExceeded = true
      throw err
    }
    throw new ApiError(userFacingApiMessage(res.status, bodyDetail), res.status, bodyDetail);
  }

  return (await res.json()) as T;
}

export async function searchItems(params: { token: string; query: string }) {
  return apiFetch<{ items: InventoryItem[]; parsed: Record<string, unknown> }>(
    "/search_items",
    {
      method: "POST",
      token: params.token,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ query: params.query }),
    }
  );
}

export type ExtractedInventoryItem = {
  name: string;
  category: string;
  subcategory?: string | null;
  quantity: number;
  brand?: string | null;
  part_number?: string | null;
  barcode?: string | null;
  tags?: string[] | null;
  confidence?: number | null;
  notes?: string | null;
  location?: string | null;
};

export async function extractFromImageMulti(params: { token: string; file: File }) {
  const form = new FormData();
  form.append("file", params.file);
  return apiFetch<{
    items: ExtractedInventoryItem[];
    summary: { total_detected: number; categories: Record<string, number> };
  }>("/inventory/extract_from_image", {
    method: "POST",
    token: params.token,
    body: form,
  });
}

export async function bulkCreate(params: {
  token: string;
  items: ExtractedInventoryItem[];
}) {
  return apiFetch<{ inserted: InventoryItem[]; failures: Array<Record<string, unknown>> }>(
    "/inventory/bulk_create",
    {
      method: "POST",
      token: params.token,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items: params.items }),
    }
  );
}

export async function addItem(params: {
  token: string;
  item: Omit<InventoryItem, "item_id" | "created_at">;
}) {
  return apiFetch<{ item: InventoryItem }>("/add_item", {
    method: "POST",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(params.item),
  });
}

export async function deleteItem(params: { token: string; item_id: string }) {
  const q = new URLSearchParams({ item_id: params.item_id });
  return apiFetch<{ deleted: boolean }>(`/delete_item?${q.toString()}`, {
    method: "DELETE",
    token: params.token,
    headers: { "Content-Type": "application/json" },
  });
}

export async function extractFromImage(params: { token: string; file: File }) {
  const form = new FormData();
  form.append("file", params.file);
  return apiFetch<{ extracted: Record<string, unknown>; image_url: string }>(
    "/extract_from_image",
    {
      method: "POST",
      token: params.token,
      body: form,
    }
  );
}

export async function processBarcode(params: { token: string; barcode: string }) {
  return apiFetch<{ result: Record<string, unknown> }>("/process_barcode", {
    method: "POST",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ barcode: params.barcode }),
  });
}

export async function updateItem(params: {
  token: string;
  item_id: string;
  updates: Partial<Omit<InventoryItem, "item_id" | "created_at">>;
}) {
  return apiFetch<{ item: InventoryItem }>("/update_item", {
    method: "PATCH",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ item_id: params.item_id, ...params.updates }),
  });
}

export async function aiCommand(params: { token: string; message: string }) {
  return apiFetch<{ tool: string | null; result: unknown; assistant_message: string }>("/ai_command", {
    method: "POST",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: params.message }),
  });
}

export async function importSpreadsheet(params: { token: string; file: File; location: string }) {
  const form = new FormData();
  form.append("file", params.file);
  form.append("location", params.location);
  return apiFetch<{ inserted: number; failures: number }>("/import/spreadsheet", {
    method: "POST",
    token: params.token,
    body: form,
  });
}

export async function createShare(params: { token: string; share_name: string; permission: "view" | "edit" }) {
  return apiFetch<{ share_code: string; code?: string; share_id: string; permission: string; member_count: number }>("/sharing/create", {
    method: "POST",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ share_name: params.share_name, permission: params.permission }),
  });
}

export async function getMyShares(params: { token: string }) {
  type MyShare = { share_id: string; share_name: string; share_code: string; code?: string; permission: string; member_count: number };
  const data = await apiFetch<{ shares?: MyShare[] } | MyShare[]>("/sharing/my-shares", { token: params.token });
  return { shares: Array.isArray(data) ? data : data.shares ?? [] };
}

export async function getJoinedShares(params: { token: string }) {
  type JoinedShare = { share_id: string; share_name: string; owner?: string; permission: string };
  type JoinedMembership = {
    share_id?: string;
    share_name?: string;
    permission?: string;
    owner?: string;
    team_shares?: JoinedShare | JoinedShare[] | null;
  };
  const data = await apiFetch<{ shares?: JoinedMembership[] } | JoinedMembership[]>("/sharing/joined", { token: params.token });
  const memberships = Array.isArray(data) ? data : data.shares ?? [];
  const shares = memberships.flatMap((membership): JoinedShare[] => {
    const nested = Array.isArray(membership.team_shares)
      ? membership.team_shares[0]
      : membership.team_shares ?? membership;
    if (!nested) return [];
    const shareId = nested.share_id ?? membership.share_id;
    if (!shareId) return [];
    return [{
      share_id: shareId,
      share_name: nested.share_name || "Shared space",
      permission: nested.permission || "view",
      owner: nested.owner ?? membership.owner,
    }];
  });
  return { shares };
}

export async function deleteShare(params: { token: string; share_id: string }) {
  return apiFetch<{ deleted: boolean }>(`/sharing/${params.share_id}`, {
    method: "DELETE",
    token: params.token,
  });
}

export async function joinShare(params: { token: string; share_code: string }) {
  return apiFetch<{ share_id: string; share_name: string; permission: string }>("/sharing/join", {
    method: "POST",
    token: params.token,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ share_code: params.share_code }),
  });
}

export async function getUsage({ token }: { token: string }) {
  return apiFetch<Record<string, unknown>>('/usage', { token })
}

export async function checkUsage({ token, feature }: { token: string; feature: string }) {
  return apiFetch<{
    allowed: boolean;
    current?: number;
    limit?: number;
    feature_label?: string;
  }>('/usage/check', {
    method: 'POST',
    token,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ feature }),
  })
}

export async function incrementUsage({ token, feature }: { token: string; feature: string }) {
  return apiFetch<{ count: number; feature: string }>('/usage/increment', {
    method: 'POST',
    token,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ feature }),
  })
}

// Checkouts
export async function checkoutItem({ token, itemId, checkedOutBy, dueBackAt, notes }: {
  token: string; itemId: string; checkedOutBy: string; dueBackAt?: string; notes?: string;
}) {
  return apiFetch<{ checkout: Record<string, unknown> }>('/checkouts/checkout', {
    method: 'POST',
    token,
    body: { item_id: itemId, checked_out_by: checkedOutBy, due_back_at: dueBackAt, notes },
  });
}

export async function returnItem({ token, checkoutId }: { token: string; checkoutId: string }) {
  return apiFetch<{ returned: boolean }>('/checkouts/return', {
    method: 'POST',
    token,
    body: { checkout_id: checkoutId },
  });
}

export async function getActiveCheckouts({ token }: { token: string }) {
  return apiFetch<{ checkouts: Record<string, unknown>[] }>('/checkouts/active', {
    method: 'GET',
    token,
  });
}

export async function getItemCheckouts({ token, itemId }: { token: string; itemId: string }) {
  return apiFetch<{ checkouts: Record<string, unknown>[] }>(`/checkouts/item/${itemId}`, {
    method: 'GET',
    token,
  });
}

// Share members
export async function getShareMembers({ token, shareId }: { token: string; shareId: string }) {
  return apiFetch<Record<string, unknown>[]>(`/sharing/${shareId}/members`, {
    method: 'GET',
    token,
  });
}

export async function leaveShare({ token, shareId }: { token: string; shareId: string }) {
  return apiFetch<{ left: boolean }>(`/sharing/${shareId}/leave`, {
    method: 'DELETE',
    token,
  });
}

export async function removeShareMember({ token, shareId, memberId }: { token: string; shareId: string; memberId: string }) {
  return apiFetch<{ removed: boolean }>(`/sharing/${shareId}/members/${memberId}`, {
    method: 'DELETE',
    token,
  });
}

export async function updateSharedItem(params: {
  token: string;
  shareId: string;
  itemId: string;
  updates: Partial<Pick<InventoryItem, 'name' | 'category' | 'quantity' | 'image_url' | 'barcode' | 'purchase_source' | 'notes'>>;
}) {
  return apiFetch<{ item: InventoryItem }>(`/sharing/${params.shareId}/items/${params.itemId}`, {
    method: 'PATCH',
    token: params.token,
    body: params.updates,
  });
}

// Profile
export async function getMyProfile({ token }: { token: string }) {
  return apiFetch<{
    user_id: string; email: string; display_name: string;
    contact_email: string; avatar_color: string; is_pro: boolean;
  }>('/profile/me', { method: 'GET', token });
}

export async function updateProfile({ token, displayName, contactEmail, avatarColor }: {
  token: string; displayName?: string; contactEmail?: string; avatarColor?: string;
}) {
  return apiFetch<{ updated: boolean }>('/profile/update', {
    method: 'PATCH',
    token,
    body: {
      ...(displayName !== undefined && { display_name: displayName }),
      ...(contactEmail !== undefined && { contact_email: contactEmail }),
      ...(avatarColor !== undefined && { avatar_color: avatarColor }),
    },
  });
}

// Billing — /billing/* endpoints

export type LimitsResponse = {
  tier: 'free' | 'pro' | 'team_member';
  items: { used: number; max: number | null };
  spaces: { used: number; max: number | null };
  chats: { used: number; max: number | null; resets_at: string };
  scans: { used: number; max: number | null; daily_used: number; daily_max: number | null; resets_at: string };
  plan?: { name: string; renews_at: string | null } | null;
};

export async function getMyLimits({ token }: { token: string }) {
  return apiFetch<LimitsResponse>('/me/limits', { method: 'GET', token });
}

export async function createBillingCheckout({
  token,
  plan,
  program,
  team_name,
}: {
  token: string;
  plan: 'ftc_season' | 'frc_season' | 'district';
  program: 'ftc' | 'frc' | 'vex' | 'fll';
  team_name: string;
}) {
  return apiFetch<{ url: string }>('/billing/checkout', {
    method: 'POST',
    token,
    body: { plan, program, team_name },
  });
}

export async function createBillingPortal({ token }: { token: string }) {
  return apiFetch<{ url: string }>('/billing/portal', { method: 'POST', token });
}

export type TeamData = {
  team_id: string;
  name: string;
  role: string;
  join_code?: string;
  plan?: string | null;
  program?: string;
  plan_expires_at?: string | null;
};

export async function getMyTeams({ token }: { token: string }) {
  return apiFetch<{ teams: TeamData[] }>('/teams', { method: 'GET', token });
}

export async function createTeam({
  token,
  name,
  program,
  rookie = false,
}: {
  token: string;
  name: string;
  program: 'ftc' | 'frc' | 'vex' | 'fll';
  rookie?: boolean;
}) {
  return apiFetch<{ team: { team_id: string; name: string; join_code?: string; plan?: string | null; plan_expires_at?: string | null } }>('/teams', {
    method: 'POST',
    token,
    body: { name, program, rookie },
  });
}

// ── Spaces ────────────────────────────────────────────────────────────────────

export type Space = {
  id: string;
  name: string;
  created_at: string | null;
  item_count?: number;
};

export async function getSpaces({ token }: { token: string }): Promise<Space[]> {
  const raw = await apiFetch<unknown>('/spaces', { token });
  if (Array.isArray(raw)) return raw as Space[];
  if (raw !== null && typeof raw === 'object' && Array.isArray((raw as Record<string, unknown>).spaces)) {
    return (raw as { spaces: Space[] }).spaces;
  }
  console.error('[getSpaces] unexpected payload shape:', raw);
  return [];
}

export async function createSpace({ token, name }: { token: string; name: string }) {
  return apiFetch<{ space: Space }>('/spaces', {
    method: 'POST',
    token,
    body: { name },
  });
}

export async function renameSpace({ token, spaceId, name }: { token: string; spaceId: string; name: string }) {
  return apiFetch<{ space: Space }>(`/spaces/${spaceId}`, {
    method: 'PATCH',
    token,
    body: { name },
  });
}

export async function deleteSpace({ token, spaceId }: { token: string; spaceId: string }) {
  return apiFetch<{ deleted: boolean }>(`/spaces/${spaceId}`, {
    method: 'DELETE',
    token,
  });
}
