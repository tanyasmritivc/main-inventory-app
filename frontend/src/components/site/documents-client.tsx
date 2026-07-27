"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";

const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

type DocumentEntry = {
  storage_path?: string;
  filename?: string;
  mime_type?: string | null;
  file_type?: string | null;
  size_bytes?: number | null;
  created_at?: string | null;
};

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

async function apiFetch<T>(path: string, opts: { method?: string; token: string; body?: BodyInit; headers?: Record<string, string> }) {
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

async function apiDelete(path: string, opts: { token: string }) {
  const res = await fetch(`${apiBase()}${path}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${opts.token}`,
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
}

function fileTypeIcon(mime: string | null | undefined, filename: string | undefined): string {
  const m = (mime || "").toLowerCase();
  const n = (filename || "").toLowerCase();
  if (m.startsWith("image/")) return "\u{1f5bc}\ufe0f";
  if (m === "application/pdf") return "\u{1f4c4}";
  if (n.endsWith(".xlsx") || n.endsWith(".xls") || m.includes("spreadsheet") || m.includes("excel")) return "\u{1f4ca}";
  if (n.endsWith(".csv") || m === "text/csv") return "\u{1f4cb}";
  return "\u{1f4ce}";
}

export function DocumentsClient() {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const fileRef = useRef<HTMLInputElement | null>(null);

  const [token, setToken] = useState<string | null>(null);
  const [docs, setDocs] = useState<DocumentEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [openError, setOpenError] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [openingKey, setOpeningKey] = useState<string | null>(null);
  const [deletingKey, setDeletingKey] = useState<string | null>(null);
  const [confirmDeleteKey, setConfirmDeleteKey] = useState<string | null>(null);
  const [confirmDeletePath, setConfirmDeletePath] = useState<string | null>(null);

  const [pendingSpreadsheet, setPendingSpreadsheet] = useState<File | null>(null);
  const [showSpaceSelector, setShowSpaceSelector] = useState(false);
  const [targetSpace, setTargetSpace] = useState("");
  const [importResult, setImportResult] = useState<{ inserted: number; failures: number } | null>(null);
  const [importing, setImporting] = useState(false);

  async function refreshToken(): Promise<string> {
    try {
      const supabase = createSupabaseBrowserClient();
      const { data: { session } } = await supabase.auth.getSession();
      return session?.access_token ?? "";
    } catch {
      return "";
    }
  }

  async function load(currentToken?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
      if (!t) return;
      const res = await apiFetch<{ documents: DocumentEntry[] }>("/documents", { method: "GET", token: t });
      setDocs(res.documents || []);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to load documents");
    } finally {
      setLoading(false);
    }
  }

  async function onOpenDocument(doc: DocumentEntry, key: string) {
    setOpenError(null);
    setDeleteError(null);
    const storagePath = doc.storage_path;
    if (!storagePath) {
      setOpenError("This document can't be opened because its storage path is missing.");
      return;
    }

    setOpeningKey(key);
    try {
      const { data, error: signedErr } = await supabase.storage.from("documents").createSignedUrl(storagePath, 120);
      if (signedErr) {
        setOpenError(signedErr.message || "Failed to open document");
        return;
      }
      if (!data?.signedUrl) {
        setOpenError("Failed to open document");
        return;
      }
      window.open(data.signedUrl, "_blank", "noopener,noreferrer");
    } catch (err: unknown) {
      setOpenError(err instanceof Error ? err.message : "Failed to open document");
    } finally {
      setOpeningKey(null);
    }
  }

  async function onDeleteDocument() {
    setDeleteError(null);
    const storagePath = confirmDeletePath;
    const key = confirmDeleteKey;
    if (!storagePath || !key) {
      setDeleteError("Failed to delete document");
      return;
    }

    setDeletingKey(key);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const q = new URLSearchParams({ storage_path: storagePath });
      await apiDelete(`/documents?${q.toString()}`, { token: t });
      setDocs((prev) => prev.filter((d) => d.storage_path !== storagePath));
      setConfirmDeleteKey(null);
      setConfirmDeletePath(null);
    } catch (err: unknown) {
      setDeleteError(err instanceof Error ? err.message : "Failed to delete document");
    } finally {
      setDeletingKey(null);
    }
  }

  useEffect(() => {
    refreshToken()
      .then((t) => load(t))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onUpload(file: File) {
    setError(null);
    setSuccess(null);
    setOpenError(null);
    setUploading(true);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const form = new FormData();
      form.append("file", file);
      const res = await apiFetch<{ document: { filename?: string }; activity_summary?: string }>("/documents/upload", {
        method: "POST",
        token: t,
        body: form,
      });
      setSuccess(res.activity_summary || (res.document?.filename ? `Uploaded ${res.document.filename}` : "Uploaded"));
      await load(t);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Failed to upload document");
    } finally {
      setUploading(false);
    }
  }

  async function handleSpreadsheetImport() {
    if (!pendingSpreadsheet || !targetSpace.trim()) return;
    setImporting(true);
    try {
      const t = token || (await refreshToken());
      if (!t) return;
      const formData = new FormData();
      formData.append("file", pendingSpreadsheet);
      formData.append("location", targetSpace.trim());
      const res = await fetch(`${apiBase()}/import/spreadsheet`, {
        method: "POST",
        headers: { Authorization: `Bearer ${t}` },
        body: formData,
      });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      setImportResult({ inserted: data.inserted ?? 0, failures: data.failures ?? 0 });
      setShowSpaceSelector(false);
      setPendingSpreadsheet(null);
      setTargetSpace("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Import failed");
    } finally {
      setImporting(false);
    }
  }

  const handleFileSelect = (file: File) => {
    const name = file.name.toLowerCase();
    if (name.endsWith(".xlsx") || name.endsWith(".xls") || name.endsWith(".csv")) {
      setPendingSpreadsheet(file);
      setShowSpaceSelector(true);
    } else {
      onUpload(file);
    }
  };

  return (
    <div style={{ padding: "36px 40px", maxWidth: "1100px", fontFamily: FONT, WebkitFontSmoothing: "antialiased" as any }}>

      {/* Import success banner */}
      {importResult && (
        <div style={{ background: "rgba(50,215,75,0.08)", border: "1px solid rgba(50,215,75,0.20)", borderRadius: 10, padding: "12px 16px", marginBottom: 16, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontSize: 13, fontWeight: 510, color: "#32d74b" }}>
              ✓ Import complete — {importResult.inserted} items added to inventory
            </div>
            {importResult.failures > 0 && (
              <div style={{ fontSize: 11, color: "#6e6e73", marginTop: 2 }}>
                {importResult.failures} rows could not be parsed
              </div>
            )}
          </div>
          <button onClick={() => setImportResult(null)} style={{ background: "none", border: "none", color: "#6e6e73", cursor: "pointer", fontSize: 16 }}>×</button>
        </div>
      )}

      {/* Upload section */}
      <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: "0.08em", textTransform: "uppercase" as any, color: "#6e6e73", marginBottom: 8 }}>Upload</div>
      <div
        role="button"
        tabIndex={0}
        aria-label="Upload file"
        style={{ background: "rgba(255,255,255,0.02)", border: "1px dashed rgba(255,255,255,0.12)", borderRadius: 14, padding: "52px 24px", textAlign: "center" as any, cursor: "pointer", marginBottom: 32, backdropFilter: "blur(8px)", WebkitBackdropFilter: "blur(8px)" as any, transition: "border-color 0.16s, background 0.16s" }}
        onClick={() => fileRef.current?.click()}
        onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") fileRef.current?.click(); }}
        onMouseEnter={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(255,255,255,0.22)"; el.style.background = "rgba(255,255,255,0.04)"; }}
        onMouseLeave={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(255,255,255,0.12)"; el.style.background = "rgba(255,255,255,0.02)"; }}
      >
        <div style={{ fontSize: 28, color: "rgba(255,255,255,0.15)", marginBottom: 12 }}>↑</div>
        <div style={{ fontSize: 14, color: "#a1a1a6", marginBottom: 4 }}>Drop a file here or click to browse</div>
        <div style={{ fontSize: 12, color: "#6e6e73" }}>PDF, images, Excel (.xlsx, .xls), CSV — AI extracts items automatically</div>
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="application/pdf,text/plain,image/png,image/jpg,image/jpeg,image/webp,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel,text/csv,.xlsx,.xls,.csv"
        style={{ display: "none" }}
        disabled={uploading}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) handleFileSelect(f);
          if (fileRef.current) fileRef.current.value = "";
        }}
      />

      {error ? <p style={{ fontSize: 12, color: "#ff453a", marginBottom: 8, fontWeight: 500 }}>{error}</p> : null}
      {success ? <p style={{ fontSize: 12, color: "#32d74b", marginBottom: 8, fontWeight: 500 }}>{success}</p> : null}

      {/* Documents list section */}
      <div style={{ display: "flex", justifyContent: "flex-end", alignItems: "center", marginBottom: 6 }}>
        <button
          type="button"
          onClick={() => load()}
          disabled={loading}
          style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 8, padding: "6px 14px", fontSize: 12, color: "#a1a1a6", cursor: loading ? "not-allowed" : "pointer", fontFamily: "inherit", backdropFilter: "blur(8px)", transition: "background 0.15s" }}
          onMouseEnter={(e) => { if (!loading) (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.09)"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.05)"; }}
        >
          Refresh
        </button>
      </div>

      {loading ? <p style={{ fontSize: 13, color: "#6e6e73", marginBottom: 8 }}>Loading…</p> : null}
      {openError ? <p style={{ fontSize: 13, color: "#ff453a", marginBottom: 8 }}>{openError}</p> : null}
      {deleteError ? <p style={{ fontSize: 13, color: "#ff453a", marginBottom: 8 }}>{deleteError}</p> : null}

      {docs.length === 0 && !loading ? (
        <div style={{ textAlign: "center" as any, padding: "40px 0", fontSize: 13, color: "#3a3a3c" }}>
          No documents yet. Upload your first file above.
        </div>
      ) : null}

      {docs.length ? (
        <div>
          {docs.map((d, idx) => {
            const key = (d.storage_path || d.filename || "doc") + idx;
            const icon = fileTypeIcon(d.mime_type, d.filename);
            return (
              <div
                key={key}
                style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 16px", background: "rgba(255,255,255,0.02)", border: "1px solid rgba(255,255,255,0.07)", borderRadius: 10, marginBottom: 6, transition: "background 0.12s" }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.04)"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.02)"; }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 12, flex: 1, minWidth: 0 }}>
                  <span style={{ fontSize: 20, flexShrink: 0 }}>{icon}</span>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 510, color: "#f5f5f7", letterSpacing: "-0.015em", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{d.filename || "Untitled"}</div>
                    <div style={{ fontSize: 11, color: "#6e6e73", marginTop: 2, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                      {(d.mime_type || "unknown")}{d.created_at ? ` · ${new Date(d.created_at).toLocaleDateString()}` : ""}
                    </div>
                  </div>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 4, flexShrink: 0 }}>
                  <button
                    type="button"
                    onClick={() => onOpenDocument(d, key)}
                    style={{ fontSize: 12, color: "#a1a1a6", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 6, padding: "4px 12px", cursor: "pointer", marginRight: 6, fontFamily: "inherit", transition: "background 0.15s" }}
                    onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.09)"; }}
                    onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.04)"; }}
                  >
                    {openingKey === key ? "Opening…" : "Open"}
                  </button>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <button
                        type="button"
                        aria-label={`Open menu for ${d.filename || "document"}`}
                        onClick={(e) => e.stopPropagation()}
                        onKeyDown={(e) => e.stopPropagation()}
                        style={{ fontSize: 16, color: "#3a3a3c", background: "transparent", border: "none", cursor: "pointer", padding: "4px 6px", lineHeight: 1, fontFamily: "inherit" }}
                      >
                        ⋯
                      </button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
                      <DropdownMenuItem
                        variant="destructive"
                        onSelect={(e) => {
                          e.preventDefault();
                          setConfirmDeleteKey(key);
                          setConfirmDeletePath(d.storage_path || null);
                        }}
                      >
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            );
          })}
        </div>
      ) : null}

      {/* Delete confirmation dialog */}
      <Dialog
        open={!!confirmDeleteKey && !!confirmDeletePath}
        onOpenChange={(open) => {
          if (!open) {
            setConfirmDeleteKey(null);
            setConfirmDeletePath(null);
          }
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete document</DialogTitle>
            <DialogDescription>Are you sure you want to delete this document? This cannot be undone.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <button type="button" disabled={deletingKey !== null} style={{ background: "transparent", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 8, padding: "8px 16px", fontSize: 13, color: "#a1a1a6", cursor: "pointer", fontFamily: "inherit" }}>Cancel</button>
            </DialogClose>
            <button
              type="button"
              onClick={onDeleteDocument}
              disabled={deletingKey !== null}
              style={{ background: "#ff453a", border: "none", borderRadius: 8, padding: "8px 16px", fontSize: 13, color: "#fff", fontWeight: 510, cursor: deletingKey ? "not-allowed" : "pointer", fontFamily: "inherit", opacity: deletingKey ? 0.6 : 1 }}
            >
              {deletingKey ? "Deleting…" : "Delete"}
            </button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Space selector dialog for spreadsheet import */}
      <Dialog
        open={showSpaceSelector}
        onOpenChange={(open) => {
          if (!open) {
            setShowSpaceSelector(false);
            setPendingSpreadsheet(null);
            setTargetSpace("");
          }
        }}
      >
        <DialogContent style={{ background: "rgba(15,15,20,0.95)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 14, padding: 28, backdropFilter: "blur(20px)" }}>
          <DialogHeader>
            <DialogTitle>Import to Inventory</DialogTitle>
            <DialogDescription>Which space should these items go into?</DialogDescription>
          </DialogHeader>
          <div style={{ marginTop: 12 }}>
            <input
              placeholder="Space name e.g. Garage, Kitchen, Robotics"
              value={targetSpace}
              onChange={(e) => setTargetSpace(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter" && targetSpace.trim() && !importing) handleSpreadsheetImport(); }}
              style={{ width: "100%", background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 10, padding: "11px 16px", fontSize: 13, color: "#f5f5f7", outline: "none", fontFamily: "inherit", letterSpacing: "-0.01em", backdropFilter: "blur(8px)", transition: "border-color 0.15s", boxSizing: "border-box" as any }}
              onFocus={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "rgba(255,255,255,0.25)"; }}
              onBlur={(e) => { (e.currentTarget as HTMLElement).style.borderColor = "rgba(255,255,255,0.10)"; }}
            />
          </div>
          {pendingSpreadsheet && (
            <div style={{ fontSize: 11, color: "#6e6e73", marginTop: 8 }}>File: {pendingSpreadsheet.name}</div>
          )}
          <DialogFooter style={{ marginTop: 20 }}>
            <DialogClose asChild>
              <button type="button" style={{ background: "transparent", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 8, padding: "8px 16px", fontSize: 13, color: "#a1a1a6", cursor: "pointer", fontFamily: "inherit" }}>Cancel</button>
            </DialogClose>
            <button
              type="button"
              disabled={importing || !targetSpace.trim()}
              onClick={handleSpreadsheetImport}
              style={{ background: "#fff", color: "#000", border: "none", borderRadius: 8, padding: "8px 20px", fontSize: 13, fontWeight: 510, cursor: importing || !targetSpace.trim() ? "not-allowed" : "pointer", fontFamily: "inherit", opacity: importing || !targetSpace.trim() ? 0.5 : 1 }}
            >
              {importing ? "Importing…" : "Import"}
            </button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
