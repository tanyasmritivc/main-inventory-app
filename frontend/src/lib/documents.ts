export type DocumentEntry = {
  storage_path: string;
  user_id?: string;
  filename: string;
  display_name?: string;
  mime_type?: string | null;
  file_type?: string | null;
  size_bytes?: number;
  created_at?: string;
  item_id?: string | null;
};
export function documentKind(doc: DocumentEntry) {
  const name = doc.filename.toLowerCase(),
    mime = doc.mime_type?.toLowerCase() ?? "";
  if (
    (mime.startsWith("text/") && mime !== "text/csv") ||
    name.endsWith(".txt")
  )
    return "notes";
  if (mime.startsWith("image/")) return "images";
  if (mime === "application/pdf" || name.endsWith(".pdf")) return "pdfs";
  return "files";
}
export function trustedDocumentUrl(
  value: string,
  owner: string,
  origins: string[],
) {
  try {
    const url = new URL(value),
      parts = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      url.hash ||
      !origins
        .filter(Boolean)
        .some((origin) => new URL(origin).origin === url.origin)
    )
      return undefined;
    if (
      parts.length < 7 ||
      parts[0] !== "storage" ||
      parts[1] !== "v1" ||
      parts[2] !== "object" ||
      !["sign", "public"].includes(parts[3]) ||
      parts[4] !== "documents" ||
      parts[5] !== owner ||
      parts
        .slice(6)
        .some(
          (p) => p === "." || p === ".." || p.includes("/") || p.includes("\\"),
        )
    )
      return undefined;
    return value;
  } catch {
    return undefined;
  }
}
export function ownedNotePath(path: string, owner: string) {
  const parts = path.split("/");
  return (
    parts[0] === owner &&
    parts.length >= 2 &&
    parts.every((p) => p && p !== "." && p !== ".." && !p.includes("\\"))
  );
}
