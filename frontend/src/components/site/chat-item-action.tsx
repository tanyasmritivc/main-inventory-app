"use client";
import { useEffect, useRef, useState } from "react";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { type ChatItemAction, decideChatItemAction } from "@/lib/chat-item-actions";
import { activeInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";

export function ChatItemActionCard({ action: initial, accountId, worldId, onReply }: {
  action: ChatItemAction; accountId: string; worldId?: string;
  onReply: (reply: { id: string; content: string }) => void;
}) {
  const [action, setAction] = useState(initial), [busy, setBusy] = useState(false), [error, setError] = useState("");
  const control = useRef<AbortController | null>(null);
  const mounted = useRef(true);
  const { confirmAction } = useAppDialog();
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; control.current?.abort(); }; }, []);
  async function decide(decision: "confirm" | "cancel") {
    if (busy) return;
    setBusy(true); setError("");
    try {
    if (decision === "confirm" && action.operation === "delete" && action.status === "pending") {
      const confirmed = await confirmAction({ title: `Delete ${action.items.length} ${action.items.length === 1 ? "item" : "items"}?`,
        message: "Only the listed item records will be deleted. Their related history and photos may be removed. Spaces, inventories and organizations are kept.",
        confirmLabel: "Delete items", danger: true });
      if (!confirmed || !mounted.current) { if (mounted.current) setBusy(false); return; }
    }
    const request = new AbortController();
    control.current = request; setBusy(true); setError("");
      const result = await decideChatItemAction(accountId, action, decision, request.signal, worldId);
      if (!mounted.current) return;
      setAction(result.action);
      if (result.action.status === "confirmed" && result.content && result.replyId) onReply({ id: result.replyId, content: result.content });
      if (result.answerError) setError(result.answerError);
    } catch (reason) {
      if (mounted.current) setError(userFacingError(reason, "The action could not be confirmed. Retry this same card safely."));
    } finally { if (mounted.current) setBusy(false); }
  }
  const pending = action.status === "pending";
  return <section className="ask-action-card" aria-label={`${action.operation === "add" ? "Add" : action.operation === "delete" ? "Delete" : "Update"} items review`}>
    <strong>{pending ? action.operation === "add" ? "Review new items" : action.operation === "delete" ? "Review items to delete" : "Review item changes" : action.status === "confirmed" ? "Change confirmed" : "Cancelled"}</strong>
    <ul>{action.items.map((item, i) => <li key={i}><span>{item.name}</span><small>{item.quantity === null ? "Quantity unknown" : `Qty ${item.quantity}`} · {item.location}</small>{item.details?.map((detail,n)=><small key={n}>{detail}</small>)}</li>)}</ul>
    {pending && <div className="ask-action-buttons">
      <button className="workspace-button" disabled={busy} onClick={() => void decide("cancel")}>Cancel</button>
      <button className="workspace-button is-primary" disabled={busy || (!worldId && activeInventory()?.can_edit !== true)} onClick={() => void decide("confirm")}>{busy ? "Confirming…" : action.operation === "add" ? "Confirm additions" : action.operation === "delete" ? "Review deletion" : "Confirm changes"}</button>
    </div>}
    {error && <p role="alert">{error}{action.status === "confirmed" && <button className="workspace-button" disabled={busy} onClick={() => void decide("confirm")}>Reload AI reply</button>}</p>}
  </section>;
}
