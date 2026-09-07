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

export function apiBase() {
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

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  return (text ? JSON.parse(text) : undefined) as T;
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
    contact_email: string; avatar_color: string; avatar_url?: string;
    organization?: string; profile_role?: string; is_pro: boolean;
  }>('/profile/me', { method: 'GET', token });
}

export async function updateProfile({ token, displayName, contactEmail, avatarColor, organization, profileRole }: {
  token: string; displayName?: string; contactEmail?: string; avatarColor?: string; organization?: string; profileRole?: string;
}) {
  return apiFetch<{ updated: boolean }>('/profile/update', {
    method: 'PATCH',
    token,
    body: {
      ...(displayName !== undefined && { display_name: displayName }),
      ...(contactEmail !== undefined && { contact_email: contactEmail }),
      ...(avatarColor !== undefined && { avatar_color: avatarColor }),
      ...(organization !== undefined && { organization }),
      ...(profileRole !== undefined && { profile_role: profileRole }),
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
  pilot_mode?: boolean;
  pilot_ends_at?: string | null;
  pilot_notice?: string | null;
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
  program: 'robotics' | 'ftc' | 'frc' | 'fll' | 'vex' | 'education' | 'makerspace' | 'club' | 'business' | 'other';
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

// ── Activity and notifications ───────────────────────────────────────────────

export type ActivityEntry = {
  id?: string;
  activity_id?: string;
  action?: string;
  summary: string;
  display_text?: string;
  activity_type?: string;
  team_id?: string;
  team_name?: string;
  actor_name?: string;
  metadata?: Record<string, unknown>;
  created_at: string;
  is_read?: boolean;
};

export async function getRecentActivity({ token, limit = 50 }: { token: string; limit?: number }) {
  return apiFetch<{ activities: ActivityEntry[] }>(`/activity/recent?limit=${limit}`, { token });
}

export async function getNotifications({ token }: { token: string }) {
  return apiFetch<{ notifications: ActivityEntry[]; unread_count: number }>('/notifications', { token });
}

export async function markNotificationsRead({ token }: { token: string }) {
  return apiFetch<{ marked_read: number }>('/notifications/read', { method: 'POST', token });
}

// ── Assist conversations ─────────────────────────────────────────────────────

export type ConversationSummary = {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
};

export type ConversationMessage = {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
};

export async function getConversations({ token }: { token: string }) {
  return apiFetch<ConversationSummary[]>('/conversations', { token });
}

export async function getConversation({ token, conversationId }: { token: string; conversationId: string }) {
  return apiFetch<{ conversation: ConversationSummary; messages: ConversationMessage[] }>(
    `/conversations/${conversationId}`,
    { token },
  );
}

export async function deleteConversation({ token, conversationId }: { token: string; conversationId: string }) {
  return apiFetch<{ deleted: boolean }>(`/conversations/${conversationId}`, { method: 'DELETE', token });
}

export async function streamAiCommand({
  token,
  message,
  conversationId,
  onDelta,
  onConversationId,
}: {
  token: string;
  message: string;
  conversationId?: string | null;
  onDelta: (delta: string) => void;
  onConversationId?: (id: string) => void;
}) {
  const response = await fetch(`${apiBase()}/ai_command?stream=true`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'text/event-stream',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ message, conversation_id: conversationId || null }),
  });
  if (!response.ok || !response.body) {
    const detail = await response.text();
    throw new ApiError(userFacingApiMessage(response.status, detail), response.status, detail);
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    const blocks = buffer.split('\n\n');
    buffer = blocks.pop() ?? '';
    for (const block of blocks) {
      for (const line of block.split('\n')) {
        if (!line.startsWith('data: ')) continue;
        const payload = line.slice(6);
        if (payload === '[DONE]') continue;
        try {
          const event = JSON.parse(payload) as { content?: string; conversation_id?: string; error?: string };
          if (event.error) throw new Error(event.error);
          if (event.content) onDelta(event.content);
          if (event.conversation_id) onConversationId?.(event.conversation_id);
        } catch (error) {
          if (error instanceof SyntaxError) continue;
          throw error;
        }
      }
    }
  }
}

// ── Teams ────────────────────────────────────────────────────────────────────

export type TeamRole = 'owner' | 'mentor' | 'member' | 'viewer';
export type TeamSpace = Space & {
  user_id: string;
  team_space_id: string;
  linked_by: string;
  owned_by_me: boolean;
};
export type TeamMember = {
  user_id: string;
  member_id?: string;
  role: TeamRole;
  display_name?: string;
  contact_email?: string;
  avatar_url?: string;
  avatar_color?: string;
  organization?: string;
  profile_role?: string;
};
export type TeamBoardTask = {
  task_id: string;
  title: string;
  description?: string;
  task_type: 'task' | 'part_request' | 'checklist';
  status: 'todo' | 'doing' | 'done';
  priority: 'normal' | 'high' | 'urgent';
  assigned_to?: string | null;
  due_at?: string | null;
  created_by?: string;
  created_at?: string;
  updated_at?: string;
};
export type TeamDocument = {
  team_document_id: string;
  filename: string;
  mime_type?: string;
  size_bytes?: number;
  uploaded_by?: string;
  created_at: string;
};

export async function joinTeam({ token, code }: { token: string; code: string }) {
  return apiFetch<{ membership: { team_id: string; user_id: string; role: TeamRole } }>('/teams/join', {
    method: 'POST',
    token,
    body: { code: code.trim().toUpperCase() },
  });
}

export async function getTeamWorkspace({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ team: TeamData & { owner_user_id: string; join_code?: string }; role: TeamRole }>(`/teams/${teamId}/workspace`, { token });
}

export async function getTeamSpaces({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ spaces: TeamSpace[]; role: TeamRole }>(`/teams/${teamId}/spaces`, { token });
}

export async function createTeamSpace({ token, teamId, name }: { token: string; teamId: string; name: string }) {
  return apiFetch<{ space: TeamSpace }>(`/teams/${teamId}/spaces`, { method: 'POST', token, body: { name } });
}

export async function attachTeamSpace({ token, teamId, spaceId }: { token: string; teamId: string; spaceId: string }) {
  return apiFetch<{ space: TeamSpace }>(`/teams/${teamId}/spaces/attach`, { method: 'POST', token, body: { space_id: spaceId } });
}

export async function detachTeamSpace({ token, teamId, spaceId }: { token: string; teamId: string; spaceId: string }) {
  return apiFetch<{ removed: boolean }>(`/teams/${teamId}/spaces/${spaceId}`, { method: 'DELETE', token });
}

export async function getTeamSpaceItems({ token, teamId, spaceId }: { token: string; teamId: string; spaceId: string }) {
  return apiFetch<{ space: TeamSpace; items: InventoryItem[]; role: TeamRole }>(`/teams/${teamId}/spaces/${spaceId}/items`, { token });
}

export async function addTeamSpaceItem({ token, teamId, spaceId, item }: { token: string; teamId: string; spaceId: string; item: Partial<InventoryItem> & { name: string; quantity: number } }) {
  return apiFetch<{ item: InventoryItem }>(`/teams/${teamId}/spaces/${spaceId}/items`, { method: 'POST', token, body: item });
}

export async function updateTeamSpaceItem({ token, teamId, spaceId, itemId, updates }: { token: string; teamId: string; spaceId: string; itemId: string; updates: Partial<InventoryItem> }) {
  return apiFetch<{ item: InventoryItem }>(`/teams/${teamId}/spaces/${spaceId}/items/${itemId}`, { method: 'PATCH', token, body: { item_id: itemId, ...updates } });
}

export async function deleteTeamSpaceItem({ token, teamId, spaceId, itemId }: { token: string; teamId: string; spaceId: string; itemId: string }) {
  return apiFetch<{ deleted: boolean }>(`/teams/${teamId}/spaces/${spaceId}/items/${itemId}`, { method: 'DELETE', token });
}

export async function getTeamMembers({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ members?: TeamMember[] } | TeamMember[]>(`/teams/${teamId}/members`, { token }).then((data) => Array.isArray(data) ? data : data.members ?? []);
}

export async function updateTeamMemberRole({ token, teamId, userId, role }: { token: string; teamId: string; userId: string; role: TeamRole }) {
  return apiFetch<{ updated: boolean }>(`/teams/${teamId}/members/${userId}`, { method: 'PATCH', token, body: { role } });
}

export async function removeTeamMember({ token, teamId, userId }: { token: string; teamId: string; userId: string }) {
  return apiFetch<{ removed: boolean }>(`/teams/${teamId}/members/${userId}`, { method: 'DELETE', token });
}

export async function rotateTeamJoinCode({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ join_code: string }>(`/teams/${teamId}/join-code/rotate`, { method: 'POST', token });
}

export async function getTeamInvite({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ team_name: string; join_code: string; invite_url: string }>(`/teams/${teamId}/invite`, { token });
}

export async function emailTeamInvite({ token, teamId, email }: { token: string; teamId: string; email: string }) {
  return apiFetch<{ sent: boolean; email: string }>(`/teams/${teamId}/invite`, { method: 'POST', token, body: { email: email.trim() } });
}

export async function leaveTeam({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ left: boolean }>(`/teams/${teamId}/leave`, { method: 'DELETE', token });
}

export async function deleteTeam({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ deleted: boolean }>(`/teams/${teamId}`, { method: 'DELETE', token });
}

export async function getTeamBoard({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ tasks: TeamBoardTask[]; role: TeamRole }>(`/teams/${teamId}/board`, { token });
}

export async function createTeamBoardTask({ token, teamId, task }: { token: string; teamId: string; task: Partial<TeamBoardTask> & { title: string } }) {
  return apiFetch<{ task: TeamBoardTask }>(`/teams/${teamId}/board`, { method: 'POST', token, body: task });
}

export async function updateTeamBoardTask({ token, teamId, taskId, updates }: { token: string; teamId: string; taskId: string; updates: Partial<TeamBoardTask> & { clear_assignee?: boolean } }) {
  return apiFetch<{ task: TeamBoardTask }>(`/teams/${teamId}/board/${taskId}`, { method: 'PATCH', token, body: updates });
}

export async function deleteTeamBoardTask({ token, teamId, taskId }: { token: string; teamId: string; taskId: string }) {
  return apiFetch<{ deleted: boolean }>(`/teams/${teamId}/board/${taskId}`, { method: 'DELETE', token });
}

export async function getTeamActivity({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ activity: ActivityEntry[] }>(`/teams/${teamId}/activity`, { token });
}

export async function getTeamDocuments({ token, teamId }: { token: string; teamId: string }) {
  return apiFetch<{ documents: TeamDocument[]; role: TeamRole }>(`/teams/${teamId}/documents`, { token });
}

export async function uploadTeamDocument({ token, teamId, file }: { token: string; teamId: string; file: File }) {
  const form = new FormData();
  form.append('file', file);
  return apiFetch<{ document: TeamDocument }>(`/teams/${teamId}/documents`, { method: 'POST', token, body: form });
}

export async function openTeamDocument({ token, teamId, documentId }: { token: string; teamId: string; documentId: string }) {
  return apiFetch<{ url: string }>(`/teams/${teamId}/documents/${documentId}/open`, { token });
}

export async function deleteTeamDocument({ token, teamId, documentId }: { token: string; teamId: string; documentId: string }) {
  return apiFetch<void>(`/teams/${teamId}/documents/${documentId}`, { method: 'DELETE', token });
}

// ── Project kits / BOM readiness ─────────────────────────────────────────────

export type ProjectKit = {
  id: string;
  name: string;
  location: string;
  share_id?: string | null;
  created_at?: string;
  updated_at?: string;
  can_edit?: boolean;
  summary?: { total_lines: number; ready_lines: number; partial_lines: number; missing_lines: number; readiness_percent: number };
  items?: Array<Record<string, unknown>>;
};

export async function getProjectKits({ token, location, shareId }: { token: string; location: string; shareId?: string }) {
  const query = new URLSearchParams({ location });
  if (shareId) query.set('share_id', shareId);
  return apiFetch<{ kits: ProjectKit[] }>(`/project-kits?${query}`, { token });
}

export async function createProjectKit({ token, name, location, file, shareId }: { token: string; name: string; location: string; file: File; shareId?: string }) {
  const form = new FormData();
  form.append('name', name);
  form.append('location', location);
  form.append('file', file);
  if (shareId) form.append('share_id', shareId);
  return apiFetch<ProjectKit>('/project-kits', { method: 'POST', token, body: form });
}

export async function getProjectKit({ token, kitId }: { token: string; kitId: string }) {
  return apiFetch<ProjectKit>(`/project-kits/${kitId}`, { token });
}

export async function reserveProjectKit({ token, kitId }: { token: string; kitId: string }) {
  return apiFetch<ProjectKit>(`/project-kits/${kitId}/reserve`, { method: 'POST', token });
}

export async function releaseProjectKit({ token, kitId }: { token: string; kitId: string }) {
  return apiFetch<ProjectKit>(`/project-kits/${kitId}/reservations`, { method: 'DELETE', token });
}

export async function deleteProjectKit({ token, kitId }: { token: string; kitId: string }) {
  return apiFetch<{ deleted: boolean }>(`/project-kits/${kitId}`, { method: 'DELETE', token });
}

export async function analyzeBom({ token, location, file, shareId }: { token: string; location: string; file: File; shareId?: string }) {
  const form = new FormData();
  form.append('file', file);
  form.append('location', location);
  if (shareId) form.append('share_id', shareId);
  return apiFetch<{ summary: ProjectKit['summary']; items: Array<Record<string, unknown>> }>('/inventory/bom/analyze', { method: 'POST', token, body: form });
}

// ── Profile extras ───────────────────────────────────────────────────────────

export async function uploadProfilePhoto({ token, file }: { token: string; file: File }) {
  const form = new FormData();
  form.append('photo', file);
  return apiFetch<{ avatar_url: string }>('/profile/photo', { method: 'POST', token, body: form });
}

export async function deleteProfilePhoto({ token }: { token: string }) {
  return apiFetch<{ deleted: boolean }>('/profile/photo', { method: 'DELETE', token });
}
