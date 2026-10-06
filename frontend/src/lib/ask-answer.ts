export type AskSource = { kind: string; label: string; detail: string };
export type AskRow = {
  id: string;
  name: string;
  availableQuantity: number;
  requiredQuantity?: number;
  location: string;
  status?: "have" | "low" | "missing";
};
export type AskAnswerContext = {
  sources: AskSource[];
  rows: AskRow[];
  rowsTruncated: boolean;
  photoUrl?: string;
};

export function parseAskContext(value: unknown): AskAnswerContext | undefined {
  if (!value || typeof value !== "object") return undefined;
  const raw = value as Record<string, unknown>;
  const text = (value: unknown, limit = 200) =>
    typeof value === "string" ? value.slice(0, limit) : "";
  const count = (value: unknown) =>
    typeof value === "number" && Number.isSafeInteger(value) && value >= 0
      ? value
      : undefined;
  const sources: AskSource[] = [];
  for (const value of (Array.isArray(raw.sources) ? raw.sources : []).slice(
    0,
    20,
  )) {
    if (!value || typeof value !== "object") continue;
    const kind = text(value.kind),
      label = text(value.label);
    if (
      label &&
      [
        "inventory",
        "project",
        "document",
        "history",
        "spaces",
        "photo",
      ].includes(kind)
    )
      sources.push({ kind, label, detail: text(value.detail, 400) });
  }
  const rows: AskRow[] = [];
  for (const value of (Array.isArray(raw.rows) ? raw.rows : []).slice(0, 100)) {
    if (!value || typeof value !== "object") continue;
    const name = text(value.name),
      availableQuantity = count(value.available_quantity),
      requiredQuantity = count(value.required_quantity);
    if (!name || availableQuantity === undefined) continue;
    rows.push({
      id: text(value.id),
      name,
      availableQuantity,
      requiredQuantity,
      location: text(value.location),
      status:
        requiredQuantity === undefined
          ? undefined
          : availableQuantity >= requiredQuantity
            ? "have"
            : availableQuantity === 0
              ? "missing"
              : "low",
    });
  }
  return {
    sources,
    rows,
    rowsTruncated: raw.rows_truncated === true,
    photoUrl: text(raw.photo_url, 2000) || undefined,
  };
}

export function trustedAskPhotoUrl(
  value: string | undefined,
  owner: string | null,
  origins: string[],
): string | undefined {
  if (!value || !owner) return undefined;
  try {
    const url = new URL(value);
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      url.hash ||
      !origins.some((origin) => new URL(origin).origin === url.origin)
    )
      return undefined;
    const parts = url.pathname.split("/").filter(Boolean);
    return parts.length === 7 &&
      parts[0] === "storage" &&
      parts[1] === "v1" &&
      parts[2] === "object" &&
      ["public", "sign"].includes(parts[3]) &&
      parts[5] === owner &&
      /^ask-[a-f0-9]{32}\.jpg$/.test(parts[6])
      ? value
      : undefined;
  } catch {
    return undefined;
  }
}
