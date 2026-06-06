"use client";

import { useEffect, useMemo, useState } from "react";
import { Link2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { createShare, deleteShare, getJoinedShares, getMyShares } from "@/lib/api";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

type ShareRecord = {
  id: string;
  share_name: string;
  code: string;
  permission: string;
  member_count: number;
  owner?: string;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  spaceName: string;
  token: string;
};

export function ShareSpaceModal({ open, onOpenChange, spaceName, token }: Props) {
  const [activeTab, setActiveTab] = useState<"link" | "email" | "joined">("link");
  const [permission, setPermission] = useState<"view" | "edit">("view");
  const [myShares, setMyShares] = useState<ShareRecord[]>([]);
  const [joinedShares, setJoinedShares] = useState<ShareRecord[]>([]);
  const [createdCode, setCreatedCode] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const shareLink = useMemo(() => (createdCode ? `https://findez.ai/join/${createdCode}` : ""), [createdCode]);

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function refreshShares() {
    if (!token) return;
    try {
      const my = await getMyShares({ token });
      setMyShares(my?.shares ?? (Array.isArray(my) ? my : []));
    } catch {
      setMyShares([]);
    }
    try {
      const joined = await getJoinedShares({ token });
      setJoinedShares(joined?.shares ?? (Array.isArray(joined) ? joined : []));
    } catch {
      setJoinedShares([]);
    }
  }

  useEffect(() => {
    refreshShares();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spaceName, token]);

  async function handleCreateShare() {
    setError(null);
    setLoading(true);
    try {
      const res = await createShare({ token, share_name: spaceName, permission });
      setCreatedCode(res.code ?? "");
      await refreshShares();
    } catch (err: unknown) {
      setError(errorMessage(err, "Unable to create share code"));
    } finally {
      setLoading(false);
    }
  }

  async function handleRevoke(id: string) {
    setError(null);
    setLoading(true);
    try {
      await deleteShare({ token, share_id: id });
      await refreshShares();
    } catch (err: unknown) {
      setError(errorMessage(err, "Unable to revoke share"));
    } finally {
      setLoading(false);
    }
  }

  async function copyText(value: string) {
    try {
      await navigator.clipboard.writeText(value);
    } catch {
      window.prompt("Copy this text", value);
    }
  }

  const activeShares = (myShares ?? []).filter((share) => share.share_name === spaceName);

  const ghostBtn: React.CSSProperties = {
    background: "rgba(255,255,255,0.05)",
    border: "1px solid rgba(255,255,255,0.10)",
    borderRadius: 99,
    padding: "6px 14px",
    fontSize: 13,
    color: "white",
    cursor: "pointer",
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="p-0 border-0 bg-transparent max-w-[480px] w-[90vw]">
        <div style={{ background: "#0d0d0d", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 20, padding: 28 }}>
          <DialogTitle style={{ fontSize: 18, fontFamily: "var(--font-syne)", fontWeight: 600, color: "white", marginBottom: 20, display: "block" }}>
            Share {spaceName}
          </DialogTitle>

          {/* Tabs */}
          <div style={{ display: "flex", borderBottom: "1px solid rgba(255,255,255,0.08)", marginBottom: 24 }}>
            {([{ key: "link", label: "Share Code" }, { key: "joined", label: "Joined Spaces" }] as const).map((tab) => (
              <button
                key={tab.key}
                type="button"
                onClick={() => setActiveTab(tab.key)}
                style={{
                  background: "none",
                  border: "none",
                  paddingBottom: 12,
                  marginRight: 24,
                  fontSize: 14,
                  cursor: "pointer",
                  color: activeTab === tab.key ? "white" : "rgba(255,255,255,0.40)",
                  fontWeight: activeTab === tab.key ? 500 : 400,
                  borderBottom: activeTab === tab.key ? "2px solid white" : "2px solid transparent",
                }}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {activeTab === "link" ? (
            <div>
              {/* Permission */}
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: "rgba(255,255,255,0.40)", marginBottom: 8 }}>Permission</div>
                <div style={{ display: "flex", gap: 8 }}>
                  {(["view", "edit"] as const).map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setPermission(p)}
                      style={{
                        borderRadius: 99,
                        padding: "6px 14px",
                        fontSize: 13,
                        cursor: "pointer",
                        background: permission === p ? "white" : "none",
                        color: permission === p ? "black" : "rgba(255,255,255,0.60)",
                        border: permission === p ? "none" : "1px solid rgba(255,255,255,0.15)",
                      }}
                    >
                      {p === "view" ? "View only" : "Can edit"}
                    </button>
                  ))}
                </div>
              </div>

              {/* Generate */}
              <button
                type="button"
                onClick={() => void handleCreateShare()}
                disabled={loading}
                style={{ width: "100%", background: "white", color: "black", border: "none", borderRadius: 99, padding: 11, fontSize: 14, fontWeight: 600, cursor: loading ? "not-allowed" : "pointer", marginTop: 16, opacity: loading ? 0.6 : 1 }}
              >
                Generate Code
              </button>
              {error ? <p style={{ fontSize: 13, color: "#ef4444", marginTop: 8 }}>{error}</p> : null}

              {/* Code display */}
              {createdCode ? (
                <div style={{ marginTop: 16 }}>
                  <div style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 20, textAlign: "center", fontFamily: "monospace", fontSize: 32, letterSpacing: 8, color: "white" }}>
                    {createdCode}
                  </div>
                  <div style={{ display: "flex", gap: 8, marginTop: 12, justifyContent: "center" }}>
                    <button type="button" onClick={() => void copyText(createdCode)} style={ghostBtn}>Copy Code</button>
                    <button type="button" onClick={() => void copyText(shareLink)} style={ghostBtn}>Copy Link</button>
                  </div>
                  <div style={{ display: "flex", gap: 8, marginTop: 12, alignItems: "center", fontSize: 12, color: "rgba(255,255,255,0.40)" }}>
                    <input
                      value={shareLink}
                      readOnly
                      style={{ flex: 1, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 10, padding: "8px 12px", color: "white", fontSize: 13 }}
                    />
                    <button
                      type="button"
                      onClick={() => void copyText(shareLink)}
                      style={{ width: 32, height: 32, borderRadius: "50%", background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.60)", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center" }}
                    >
                      <Link2 size={14} />
                    </button>
                  </div>
                </div>
              ) : null}

              {/* Active shares */}
              {activeShares.length > 0 ? (
                <div style={{ marginTop: 20 }}>
                  {activeShares.map((share) => (
                    <div key={share.id} style={{ padding: "12px 0", borderBottom: "1px solid rgba(255,255,255,0.05)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <div style={{ display: "flex", gap: 6 }}>
                        <span style={{ borderRadius: 6, padding: "3px 8px", fontSize: 11, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.60)" }}>{share.code}</span>
                        <span style={{ borderRadius: 6, padding: "3px 8px", fontSize: 11, background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.10)", color: "rgba(255,255,255,0.60)" }}>{share.permission}</span>
                      </div>
                      <button
                        type="button"
                        onClick={() => void handleRevoke(share.id)}
                        disabled={loading}
                        style={{ color: "rgba(239,68,68,0.60)", fontSize: 12, background: "none", border: "none", cursor: "pointer" }}
                        onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#ef4444"; }}
                        onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "rgba(239,68,68,0.60)"; }}
                      >
                        Revoke
                      </button>
                    </div>
                  ))}
                </div>
              ) : null}
            </div>
          ) : (
            <div>
              {(joinedShares ?? []).length > 0 ? (
                (joinedShares ?? []).map((share) => (
                  <div key={share.id} style={{ padding: "12px 0", borderBottom: "1px solid rgba(255,255,255,0.05)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                    <div>
                      <div style={{ fontSize: 14, color: "white", fontWeight: 500 }}>{share.share_name}</div>
                      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.40)", marginTop: 2 }}>{share.owner ?? "Unknown"} · {share.permission}</div>
                    </div>
                    <a href={`/inventory?shared=${share.id}`} style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 99, padding: "5px 12px", fontSize: 12, color: "white", textDecoration: "none" }}>
                      View
                    </a>
                  </div>
                ))
              ) : (
                <p style={{ fontSize: 14, color: "rgba(255,255,255,0.40)", textAlign: "center", padding: "24px 0" }}>No shared spaces joined yet.</p>
              )}
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
