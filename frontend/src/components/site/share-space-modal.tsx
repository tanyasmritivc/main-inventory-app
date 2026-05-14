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
      setMyShares(my.shares);
    } catch {
      setMyShares([]);
    }
    try {
      const joined = await getJoinedShares({ token });
      setJoinedShares(joined.shares);
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

  const activeShares = myShares.filter((share) => share.share_name === spaceName);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Share {spaceName}</DialogTitle>
        </DialogHeader>
        <div className="space-y-6">
      <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-3">
        <div className="flex flex-wrap gap-2">
          {[
            { key: "link", label: "Share Link / Code" },
            { key: "email", label: "Email Invite" },
            { key: "joined", label: "Joined Spaces" },
          ].map((tab) => (
            <button
              key={tab.key}
              type="button"
              onClick={() => setActiveTab(tab.key as "link" | "email" | "joined")}
              className={`rounded-full px-4 py-2 text-sm transition-all ${
                activeTab === tab.key
                  ? "bg-white text-black"
                  : "bg-white/[0.03] text-white/65 hover:bg-white/[0.08]"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {activeTab === "link" ? (
        <div className="space-y-4">
          <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5">
            <div className="mb-4 flex items-center justify-between gap-4">
              <div>
                <p className="text-sm text-white/55">Permission</p>
                <p className="text-sm text-white/45">Choose whether collaborators can view or edit.</p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              <Button variant={permission === "view" ? "default" : "ghost"} onClick={() => setPermission("view")}>
                👁 View only
              </Button>
              <Button variant={permission === "edit" ? "default" : "ghost"} onClick={() => setPermission("edit")}>✏️ Can edit</Button>
            </div>
            <div className="mt-4">
              <Button onClick={handleCreateShare} disabled={loading}>
                Generate Share Code
              </Button>
            </div>
            {error ? <p className="text-sm text-destructive mt-3">{error}</p> : null}
          </div>

          {createdCode ? (
            <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5 text-center">
              <div className="mx-auto mb-4 inline-flex items-center justify-center rounded-[12px] border border-white/[0.08] px-4 py-3 text-[28px] font-mono tracking-[0.3em] text-white">
                {createdCode}
              </div>
              <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
                <Button onClick={() => copyText(createdCode)} variant="outline">
                  Copy Code
                </Button>
                <Button variant="outline" onClick={() => copyText(shareLink)}>
                  <Link2 size={16} /> Copy Link
                </Button>
              </div>
              <div className="mt-4 text-sm text-white/55">Or share this link:</div>
              <div className="mt-2 flex items-center gap-2">
                <Input value={shareLink} readOnly className="bg-white/[0.06] text-white" />
                <Button variant="outline" onClick={() => copyText(shareLink)}>
                  Copy
                </Button>
              </div>
            </div>
          ) : null}

          <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5">
            <div className="mb-3 text-sm font-medium uppercase tracking-[1.4px] text-white/30">Active shares</div>
            {activeShares.length > 0 ? (
              <div className="space-y-3">
                {activeShares.map((share) => (
                  <div key={share.id} className="flex flex-col gap-3 rounded-[14px] border border-white/[0.08] bg-white/[0.03] p-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <div className="text-sm font-medium text-white">{share.code}</div>
                      <div className="text-sm text-white/55">Permission: {share.permission}</div>
                      <div className="text-sm text-white/55">Members: {share.member_count}</div>
                    </div>
                    <Button variant="destructive" size="sm" onClick={() => void handleRevoke(share.id)} disabled={loading}>
                      Revoke
                    </Button>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-sm text-white/55">No active shares for this space yet.</p>
            )}
          </div>
        </div>
      ) : activeTab === "email" ? (
        <div className="rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-5 space-y-4">
          <p className="text-sm text-white/55">Email invites coming soon. Share the code above instead.</p>
          <Input placeholder="teammate@email.com" disabled />
          <Button variant="outline" disabled>
            Send Invite
          </Button>
          <p className="text-sm text-white/45">We're adding email invites soon.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {joinedShares.length > 0 ? (
            joinedShares.map((share) => (
              <div key={share.id} className="rounded-[16px] border border-white/[0.08] bg-white/[0.03] p-4 sm:flex sm:items-center sm:justify-between">
                <div>
                  <div className="text-sm font-semibold text-white">{share.share_name}</div>
                  <div className="text-sm text-white/55">Owner: {share.owner ?? "Unknown"}</div>
                  <div className="text-sm text-white/55">Permission: {share.permission}</div>
                </div>
                <Button variant="outline" size="sm" asChild>
                  <a href={`/inventory?shared=${share.id}`}>View</a>
                </Button>
              </div>
            ))
          ) : (
            <p className="text-sm text-white/55">No shared spaces joined yet.</p>
          )}
        </div>
      )}
    </div>
      </DialogContent>
    </Dialog>
  );
}
