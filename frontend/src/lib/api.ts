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

async function apiFetch<T>(
  path: string,
  opts: { method?: string; token: string; body?: BodyInit; headers?: Record<string, string> }
): Promise<T> {
  const res = await fetch(`${apiBase()}${path}`, {
    method: opts.method || "GET",
    headers: {
      Authorization: `Bearer ${opts.token}`,
      ...(opts.headers || {}),
    },
    body: opts.body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
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
