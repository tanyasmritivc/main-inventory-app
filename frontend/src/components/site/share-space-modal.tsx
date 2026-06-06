"use client";

import { useEffect, useMemo, useState } from "react";
import { createShare, deleteShare, getJoinedShares, getMyShares, joinShare } from "@/lib/api";
import { Dialog, DialogContent } from "@/components/ui/dialog";

const FONT = "'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif";

type ShareRecord = {
  share_id?: string;
  id?: string;
  share_name: string;
  share_code?: string;
  code?: string;
  permission: string;
  member_count?: number;
  owner?: string;
};

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  spaceName: string;
  token: string;
};

export function ShareSpaceModal({ open, onOpenChange, spaceName, token }: Props) {
  const [activeTab, setActiveTab] = useState<"link" | "joined">("link");
  const [permission, setPermission] = useState<"view" | "edit">("view");
  const [myShares, setMyShares] = useState<ShareRecord[]>([]);
  const [joinedShares, setJoinedShares] = useState<ShareRecord[]>([]);
  const [createdCode, setCreatedCode] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [joinCode, setJoinCode] = useState("");
  const [joining, setJoining] = useState(false);
  const [joinError, setJoinError] = useState<string | null>(null);
  const [joinSuccess, setJoinSuccess] = useState<string | null>(null);

  const shareLink = useMemo(() => (createdCode ? `https://findez.ai/join/${createdCode}` : ""), [createdCode]);

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function loadShares() {
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
    loadShares();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spaceName, token]);

  async function handleCreateShare() {
    setError(null);
    setLoading(true);
    try {
      const res = await createShare({ token, share_name: spaceName, permission });
      setCreatedCode((res as any).share_code ?? (res as any).code ?? "");
      await loadShares();
    } catch (err: unknown) {
      setError(errorMessage(err, "Unable to create share code"));
    } finally {
      setLoading(false);
    }
  }

  async function handleRevoke(share: ShareRecord) {
    setError(null);
    setLoading(true);
    try {
      const id = share.share_id ?? share.id ?? "";
      await deleteShare({ token, share_id: id });
      await loadShares();
    } catch (err: unknown) {
      setError(errorMessage(err, "Unable to revoke share"));
    } finally {
      setLoading(false);
    }
  }

  async function handleJoinSpace() {
    if (joinCode.length !== 6 || !token) return;
    setJoining(true);
    setJoinError(null);
    setJoinSuccess(null);
    try {
      const result = await joinShare({ token, share_code: joinCode });
      setJoinSuccess(`Joined "${(result as any)?.share_name ?? "space"}" successfully!`);
      setJoinCode("");
      await loadShares();
    } catch (err) {
      setJoinError(err instanceof Error ? err.message : "Invalid code or already joined");
    } finally {
      setJoining(false);
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
    borderRadius: 8,
    padding: "7px 16px",
    fontSize: 13,
    color: "#f5f5f7",
    cursor: "pointer",
    fontFamily: "inherit",
  };

  const badgeStyle: React.CSSProperties = {
    background: "rgba(255,255,255,0.06)",
    border: "1px solid rgba(255,255,255,0.10)",
    borderRadius: 6,
    padding: "3px 10px",
    fontSize: 12,
    fontFamily: "'SF Mono', ui-monospace, monospace",
    letterSpacing: 2,
    color: "rgba(255,255,255,0.6)",
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="p-0 border-0 bg-transparent max-w-[480px] w-[90vw]">
        <div style={{ background: "rgba(12,12,16,0.96)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 16, padding: 28, backdropFilter: "blur(20px)", WebkitBackdropFilter: "blur(20px)" as any, fontFamily: FONT }}>
          <div style={{ fontSize: 17, fontWeight: 590, letterSpacing: "-0.025em", color: "#f5f5f7", marginBottom: 20 }}>
            Share {spaceName}
          </div>

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
                  fontFamily: "inherit",
                  color: activeTab === tab.key ? "#fff" : "rgba(255,255,255,0.40)",
                  fontWeight: activeTab === tab.key ? 510 : 400,
                  borderBottom: activeTab === tab.key ? "2px solid #fff" : "2px solid transparent",
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
                <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: "0.08em", textTransform: "uppercase" as any, color: "#6e6e73", marginBottom: 8 }}>Permission</div>
                <div style={{ display: "flex", gap: 8 }}>
                  {(["view", "edit"] as const).map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setPermission(p)}
                      style={{
                        borderRadius: 8,
                        padding: "6px 14px",
                        fontSize: 13,
                        cursor: "pointer",
                        fontFamily: "inherit",
                        background: permission === p ? "#fff" : "rgba(255,255,255,0.05)",
                        color: permission === p ? "#000" : "rgba(255,255,255,0.60)",
                        border: permission === p ? "none" : "1px solid rgba(255,255,255,0.15)",
                        fontWeight: permission === p ? 510 : 400,
                      }}
                    >
                      {p === "view" ? "View only" : "Can edit"}
                    </button>
                  ))}
                </div>
              </div>

              {/* Generate button */}
              <button
                type="button"
                onClick={() => void handleCreateShare()}
                disabled={loading}
                style={{ width: "100%", background: "#fff", color: "#000", border: "none", borderRadius: 10, padding: 12, fontSize: 14, fontWeight: 510, cursor: loading ? "not-allowed" : "pointer", marginTop: 16, opacity: loading ? 0.6 : 1, fontFamily: "inherit" }}
              >
                {loading ? "Generating…" : "Generate Code"}
              </button>
              {error ? <p style={{ fontSize: 12, color: "#ff453a", marginTop: 8 }}>{error}</p> : null}

              {/* Code display */}
              {createdCode ? (
                <div style={{ marginTop: 16 }}>
                  <div style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 12, padding: 20, textAlign: "center" as any, fontFamily: "'SF Mono', ui-monospace, monospace", fontSize: 32, letterSpacing: 12, color: "#fff" }}>
                    {createdCode}
                  </div>
                  <div style={{ display: "flex", gap: 8, marginTop: 12, justifyContent: "center" }}>
                    <button type="button" onClick={() => void copyText(createdCode)} style={ghostBtn}>Copy Code</button>
                    <button type="button" onClick={() => void copyText(shareLink)} style={ghostBtn}>Copy Link</button>
                  </div>
                  <div style={{ marginTop: 10, display: "flex", gap: 8, alignItems: "center" }}>
                    <input
                      value={shareLink}
                      readOnly
                      style={{ flex: 1, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 10, padding: "8px 12px", color: "#a1a1a6", fontSize: 12, outline: "none", fontFamily: "inherit" }}
                    />
                  </div>
                </div>
              ) : null}

              {/* Active shares for this space */}
              {activeShares.length > 0 ? (
                <div style={{ marginTop: 20 }}>
                  {activeShares.map((share, idx) => {
                    const key = share.share_id ?? share.id ?? String(idx);
                    const displayCode = share.share_code ?? share.code ?? "N/A";
                    return (
                      <div key={key} style={{ padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                        <div style={{ display: "flex", gap: 6 }}>
                          <span style={badgeStyle}>{displayCode}</span>
                          <span style={{ ...badgeStyle, letterSpacing: 0 }}>{share.permission}</span>
                        </div>
                        <button
                          type="button"
                          onClick={() => void handleRevoke(share)}
                          disabled={loading}
                          style={{ color: "rgba(255,100,100,0.7)", fontSize: 12, background: "none", border: "none", cursor: "pointer", fontFamily: "inherit" }}
                          onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.color = "#ff453a"; }}
                          onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.color = "rgba(255,100,100,0.7)"; }}
                        >
                          Revoke
                        </button>
                      </div>
                    );
                  })}
                </div>
              ) : null}
            </div>
          ) : (
            <div>
              {/* Join by code */}
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 10, fontWeight: 510, letterSpacing: "0.08em", textTransform: "uppercase" as any, color: "#6e6e73", marginBottom: 8 }}>
                  Join a Space
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <input
                    value={joinCode}
                    onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                    placeholder="Enter 6-character code"
                    maxLength={6}
                    style={{ flex: 1, background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 8, padding: "9px 14px", fontSize: 13, color: "#f5f5f7", outline: "none", fontFamily: "inherit", letterSpacing: "0.1em", textTransform: "uppercase" as any }}
                  />
                  <button
                    type="button"
                    onClick={() => void handleJoinSpace()}
                    disabled={joinCode.length !== 6 || joining}
                    style={{ background: "#fff", color: "#000", border: "none", borderRadius: 8, padding: "9px 18px", fontSize: 13, fontWeight: 510, cursor: joinCode.length === 6 && !joining ? "pointer" : "not-allowed", opacity: joinCode.length === 6 && !joining ? 1 : 0.5, fontFamily: "inherit", whiteSpace: "nowrap" as any }}
                  >
                    {joining ? "Joining…" : "Join"}
                  </button>
                </div>
                {joinError ? <p style={{ fontSize: 12, color: "#ff453a", marginTop: 6 }}>{joinError}</p> : null}
                {joinSuccess ? <p style={{ fontSize: 12, color: "#32d74b", marginTop: 6 }}>✓ {joinSuccess}</p> : null}
              </div>

              {/* Joined spaces list */}
              {(joinedShares ?? []).length > 0 ? (
                (joinedShares ?? []).map((share, idx) => {
                  const key = share.share_id ?? share.id ?? String(idx);
                  return (
                    <div key={key} style={{ padding: "10px 0", borderBottom: "1px solid rgba(255,255,255,0.06)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                      <div>
                        <div style={{ fontSize: 14, fontWeight: 500, color: "#f5f5f7" }}>{share.share_name}</div>
                        <div style={{ fontSize: 12, color: "#6e6e73", marginTop: 2 }}>{share.owner ?? "Unknown"} · {share.permission}</div>
                      </div>
                      <a
                        href={`/inventory?shared=${key}`}
                        style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 8, padding: "5px 12px", fontSize: 12, color: "#f5f5f7", textDecoration: "none", fontFamily: "inherit" }}
                      >
                        View
                      </a>
                    </div>
                  );
                })
              ) : (
                <p style={{ fontSize: 13, color: "rgba(255,255,255,0.30)", textAlign: "center" as any, padding: "24px 0" }}>No shared spaces joined yet.</p>
              )}
            </div>
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
