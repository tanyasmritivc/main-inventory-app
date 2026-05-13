"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { MoreVertical } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

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

  async function refreshToken() {
    const { data, error: sessionErr } = await supabase.auth.getSession();
    if (sessionErr) throw sessionErr;
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Missing session");
    setToken(accessToken);
    return accessToken;
  }

  async function load(currentToken?: string) {
    setError(null);
    setLoading(true);
    try {
      const t = currentToken || token || (await refreshToken());
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
      setOpenError("This document can’t be opened because its storage path is missing.");
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
      .catch(() => {
        setError("Authentication error. Please sign in again.");
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onUpload(file: File) {
    setError(null);
    setSuccess(null);
    setOpenError(null);
    setUploading(true);
    try {
      const t = token || (await refreshToken());
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

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      {/* Upload card */}
      <div className="glass-card" style={{ padding: "20px 24px" }}>
        <div className="label-section" style={{ marginBottom: 4 }}>Upload</div>
        <p style={{ fontSize: 12, color: "var(--text-muted)", marginBottom: 16 }}>Upload a manual, receipt, or important document</p>
        <div
          role="button"
          tabIndex={0}
          aria-label="Upload file"
          style={{
            borderRadius: 12, border: "1.5px dashed var(--fz-border)", background: "var(--surface)",
            padding: "32px 16px", textAlign: "center", cursor: "pointer", transition: "border-color 150ms, background 150ms",
          }}
          onClick={() => fileRef.current?.click()}
          onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") fileRef.current?.click(); }}
          onMouseEnter={(e) => { const el = e.currentTarget as HTMLDivElement; el.style.borderColor = "var(--border-hover)"; el.style.background = "var(--surface-hover)"; }}
          onMouseLeave={(e) => { const el = e.currentTarget as HTMLDivElement; el.style.borderColor = "var(--fz-border)"; el.style.background = "var(--surface)"; }}
        >
          <p style={{ fontSize: 13, color: "var(--text-secondary)" }}>{uploading ? "Uploading…" : "Drop a file here or click to browse"}</p>
          <p style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>PDF, plain text, PNG, JPG, WEBP</p>
        </div>
        <Input
          ref={fileRef}
          type="file"
          accept="application/pdf,text/plain,image/png,image/jpg,image/jpeg,image/webp"
          className="hidden"
          disabled={uploading}
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) onUpload(f);
            if (fileRef.current) fileRef.current.value = "";
          }}
        />
        {error ? <p style={{ fontSize: 13, color: "var(--danger)", marginTop: 10 }}>{error}</p> : null}
        {success ? <p style={{ fontSize: 13, color: "var(--success)", marginTop: 10 }}>{success}</p> : null}
      </div>

      {/* Document list card */}
      <div className="glass-card" style={{ padding: "20px 24px" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 16 }}>
          <div>
            <div className="label-section" style={{ marginBottom: 2 }}>Manuals &amp; Receipts</div>
            <p style={{ fontSize: 12, color: "var(--text-muted)" }}>Files are private — AI only reads what you approve.</p>
          </div>
          <Button type="button" variant="outline" onClick={() => load()} disabled={loading} style={{ flexShrink: 0 }}>
            Refresh
          </Button>
        </div>

        {loading ? <p style={{ fontSize: 13, color: "var(--text-muted)" }}>Loading…</p> : null}
        {openError ? <p style={{ fontSize: 13, color: "var(--danger)", marginBottom: 8 }}>{openError}</p> : null}
        {deleteError ? <p style={{ fontSize: 13, color: "var(--danger)", marginBottom: 8 }}>{deleteError}</p> : null}

        {docs.length === 0 && !loading ? (
          <div style={{ borderRadius: 10, border: "1px solid var(--fz-border)", background: "var(--surface)", padding: "24px 20px" }}>
            <p style={{ fontSize: 13, color: "var(--text-secondary)" }}>You haven&apos;t uploaded any files yet.</p>
            <p style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 6 }}>Files are private by default. AI can only read documents you approve.</p>
            <div style={{ marginTop: 16 }}>
              <Button type="button" onClick={() => fileRef.current?.click()} disabled={uploading}>
                Upload your first document
              </Button>
            </div>
          </div>
        ) : null}

        {docs.length ? (
          <div style={{ borderRadius: 10, border: "1px solid var(--fz-border)", overflow: "hidden" }}>
            {docs.map((d, idx) => (
              <div
                key={(d.storage_path || d.filename || "doc") + idx}
                role="button"
                tabIndex={0}
                onClick={() => onOpenDocument(d, (d.storage_path || d.filename || "doc") + idx)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    onOpenDocument(d, (d.storage_path || d.filename || "doc") + idx);
                  }
                }}
                style={{
                  display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12,
                  padding: "12px 16px", cursor: "pointer",
                  borderBottom: idx < docs.length - 1 ? "1px solid var(--fz-border)" : "none",
                  transition: "background 150ms",
                }}
                onMouseEnter={(e) => { (e.currentTarget as HTMLDivElement).style.background = "var(--surface-hover)"; }}
                onMouseLeave={(e) => { (e.currentTarget as HTMLDivElement).style.background = ""; }}
                aria-label={`Open ${d.filename || "document"}`}
              >
                <div style={{ minWidth: 0, flex: 1 }}>
                  <div style={{ fontSize: 14, fontWeight: 500, color: "#fff", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{d.filename || "Untitled"}</div>
                  <div style={{ fontSize: 12, color: "var(--text-muted)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {(d.mime_type || "unknown").toString()}{d.created_at ? ` · ${new Date(d.created_at).toLocaleDateString()}` : ""}
                  </div>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
                  <span style={{ fontSize: 12, color: "var(--text-muted)" }}>
                    {openingKey === (d.storage_path || d.filename || "doc") + idx ? "Opening…" : "Open"}
                  </span>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon-sm"
                        aria-label={`Open menu for ${d.filename || "document"}`}
                        onClick={(e) => e.stopPropagation()}
                        onKeyDown={(e) => e.stopPropagation()}
                      >
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" onClick={(e) => e.stopPropagation()}>
                      <DropdownMenuItem
                        variant="destructive"
                        onSelect={(e) => {
                          e.preventDefault();
                          const key = (d.storage_path || d.filename || "doc") + idx;
                          const storagePath = d.storage_path || null;
                          setConfirmDeleteKey(key);
                          setConfirmDeletePath(storagePath);
                        }}
                      >
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              </div>
            ))}
          </div>
        ) : null}

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
                <Button type="button" variant="outline" disabled={deletingKey !== null}>
                  Cancel
                </Button>
              </DialogClose>
              <Button
                type="button"
                variant="destructive"
                onClick={onDeleteDocument}
                disabled={deletingKey !== null}
              >
                {deletingKey ? "Deleting…" : "Delete"}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </div>
    </div>
  );
}
