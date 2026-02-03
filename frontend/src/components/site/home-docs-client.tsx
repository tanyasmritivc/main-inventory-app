"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";

type ActivityEntry = {
  activity_id: string;
  summary: string;
  created_at: string;
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

export function HomeDocsClient() {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const fileRef = useRef<HTMLInputElement | null>(null);

  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [activities, setActivities] = useState<ActivityEntry[]>([]);

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function refreshToken() {
    const { data, error: sessionErr } = await supabase.auth.getSession();
    if (sessionErr) throw sessionErr;
    const accessToken = data.session?.access_token;
    if (!accessToken) throw new Error("Missing session");
    setToken(accessToken);
    return accessToken;
  }

  async function loadActivity(currentToken?: string) {
    const t = currentToken || token || (await refreshToken());
    const res = await apiFetch<{ activities: ActivityEntry[] }>("/activity/recent", { method: "GET", token: t });
    setActivities(res.activities || []);
  }

  useEffect(() => {
    refreshToken()
      .then((t) => loadActivity(t))
      .catch(() => {
        setError("Authentication error. Please sign in again.");
      });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function onUpload(file: File) {
    setError(null);
    setSuccess(null);
    setLoading(true);
    try {
      const t = token || (await refreshToken());
      const form = new FormData();
      form.append("file", file);

      const res = await apiFetch<{ document: { filename: string }; activity_summary: string }>("/documents/upload", {
        method: "POST",
        token: t,
        body: form,
      });

      setSuccess(res.activity_summary || `Uploaded ${res.document.filename}`);
      await loadActivity(t);
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to upload document"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <Card className="lg:col-span-2">
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
          <CardDescription>Jump into your next task.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3 sm:grid-cols-2">
          <Button asChild variant="outline" className="justify-start transition-transform hover:-translate-y-0.5">
            <Link href="/dashboard">Start a chat</Link>
          </Button>
          <div>
            <Input
              ref={fileRef}
              type="file"
              className="hidden"
              accept="application/pdf,image/png,image/jpg,image/jpeg,image/webp"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onUpload(f);
                if (fileRef.current) fileRef.current.value = "";
              }}
            />
            <Button
              type="button"
              variant="outline"
              className="w-full justify-start transition-transform hover:-translate-y-0.5"
              onClick={() => {
                router.push("/home");
                fileRef.current?.click();
              }}
              disabled={loading}
            >
              Upload a document
            </Button>
          </div>
        </CardContent>

        {error ? <p className="px-6 pb-6 text-sm text-destructive">{error}</p> : null}
        {success ? <p className="px-6 pb-6 text-sm text-muted-foreground">{success}</p> : null}
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Recent Activity</CardTitle>
          <CardDescription>Latest events</CardDescription>
        </CardHeader>
        <CardContent className="space-y-2 text-sm">
          {activities.map((a) => (
            <div
              key={a.activity_id}
              className="flex items-center justify-between"
              role="button"
              tabIndex={0}
              onClick={() => {
                const s = (a.summary || "").toLowerCase();
                if (s.includes("used assist") || s.includes("start a chat") || s.includes("chat")) {
                  router.push("/dashboard");
                  return;
                }
                if (s.includes("searched inventory") || s.includes("scanned image") || s.includes("saved scanned items")) {
                  router.push("/dashboard");
                  return;
                }
                if (s.includes("uploaded document")) {
                  router.push("/home");
                  return;
                }
                router.push("/dashboard");
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  (e.currentTarget as HTMLDivElement).click();
                }
              }}
            >
              <span className="text-muted-foreground">{a.summary}</span>
              <span className="text-muted-foreground">{new Date(a.created_at).toLocaleDateString()}</span>
            </div>
          ))}

          {activities.length === 0 ? (
            <div className="text-muted-foreground">
              No recent activity yet. Try asking FindEZ to add an item, or upload your first document.
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
