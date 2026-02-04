"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
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
  const [openingKey, setOpeningKey] = useState<string | null>(null);

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
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Upload</CardTitle>
          <CardDescription>Upload a file to your private document library.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Input
            ref={fileRef}
            type="file"
            accept="application/pdf,text/plain,image/png,image/jpg,image/jpeg,image/webp"
            disabled={uploading}
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) onUpload(f);
              if (fileRef.current) fileRef.current.value = "";
            }}
          />
          {uploading ? <p className="text-sm text-muted-foreground">Uploading…</p> : null}
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
          {success ? <p className="text-sm text-muted-foreground">{success}</p> : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>My Documents</CardTitle>
          <CardDescription>Files you’ve uploaded are stored and will still be here after refresh or sign-in.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm text-muted-foreground">AI is blocked from reading documents until you approve access.</p>
            <Button type="button" variant="outline" onClick={() => load()} disabled={loading}>
              Refresh
            </Button>
          </div>

          {loading ? <p className="text-sm text-muted-foreground">Loading…</p> : null}
          {openError ? <p className="text-sm text-destructive">{openError}</p> : null}

          {docs.length === 0 && !loading ? (
            <div className="rounded-md border p-4 text-sm text-muted-foreground">
              <p>You haven’t uploaded any documents yet.</p>
              <p className="mt-2">Documents are private by default. AI can only read files you approve.</p>
              <div className="mt-4">
                <Button type="button" onClick={() => fileRef.current?.click()} disabled={uploading}>
                  Upload a document
                </Button>
              </div>
            </div>
          ) : null}

          {docs.length ? (
            <div className="rounded-md border">
              <div className="divide-y">
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
                    className="flex cursor-pointer items-center justify-between gap-3 px-4 py-3 outline-none focus-visible:ring-2 focus-visible:ring-ring"
                    aria-label={`Open ${d.filename || "document"}`}
                  >
                    <div className="min-w-0">
                      <div className="truncate text-sm font-medium">{d.filename || "Untitled"}</div>
                      <div className="truncate text-xs text-muted-foreground">
                        {(d.mime_type || "unknown").toString()} {d.created_at ? `· ${new Date(d.created_at).toLocaleDateString()}` : ""}
                      </div>
                    </div>
                    <div className="shrink-0 text-xs text-muted-foreground">
                      {openingKey === (d.storage_path || d.filename || "doc") + idx ? "Opening…" : "Open"}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
