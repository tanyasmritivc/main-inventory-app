"use client";
import { useRef, useState } from "react";
import { Copy, Check, ThumbsUp, ThumbsDown, RotateCcw, Pencil, X } from "lucide-react";
import { accountRequest } from "@/lib/account-request";
import styles from "./message-actions.module.css";
export type ResponseRating = { id: string; message_id: string; rating: 1 | -1; reason: string | null; comment: string | null; revision: number; updated_at: string };
const reasons: Record<string, string> = {
 wrong_inventory: "Wrong inventory information", misunderstood: "Misunderstood my request",
 action_failed: "Failed to perform or save the action", incomplete: "Missing or incomplete results",
 forgot_context: "Forgot my preferences or context", unsafe_action: "Incorrect or unsafe action",
 clarity: "Poor explanation or excessive verbosity", other: "Other",
};
export function MessageActions({ content, role, timestamp, messageId, accountId, rating, onRating, onRetry, onEdit, disabled = false }: {
 content: string; role: "user" | "assistant"; timestamp: string; messageId?: string;
 accountId?: string; rating?: ResponseRating; onRating?: (rating: ResponseRating) => void;
 onRetry?: () => void; onEdit?: () => void; disabled?: boolean;
}) {
 const [busy, setBusy] = useState(false), [details, setDetails] = useState(false), [error, setError] = useState("");
 const [reason, setReason] = useState(rating?.reason || ""), [comment, setComment] = useState(rating?.comment || "");
 const [copied, setCopied] = useState(false);
 const lock = useRef(false);
 async function rate(value: 1 | -1, withDetails = false) {
  if (!accountId || !messageId || lock.current || disabled) return;
  lock.current = true; setBusy(true); setError("");
  try {
   const saved = await accountRequest<ResponseRating>(accountId, `/response-feedback/${encodeURIComponent(messageId)}`, {
    method: "PUT", body: { rating: value, reason: value === -1 && withDetails ? reason || null : null,
     comment: withDetails ? comment.trim() || null : null, expected_revision: rating?.revision || 0 },
   });
   if (saved.message_id !== messageId || saved.rating !== value || !Number.isInteger(saved.revision)) throw new Error();
   onRating?.(saved); setDetails(value === -1 && !withDetails);
  } catch { setError("Feedback wasn't saved. Please try again."); }
  finally { lock.current = false; setBusy(false); }
 }
 async function copy() {
  try { await navigator.clipboard.writeText(content); setCopied(true); }
  catch { setError("Couldn't copy this message."); }
 }
 const date = new Date(timestamp), validDate = !Number.isNaN(date.valueOf());
 return <>
  <div className={styles.row} aria-label={`${role === "assistant" ? "Response" : "Prompt"} actions`}>
   <button type="button" aria-label={copied ? "Copied" : "Copy message"} title="Copy" onClick={() => void copy()}>{copied ? <Check size={16}/> : <Copy size={16}/>}</button>
   {role === "assistant" && messageId && accountId && <>
    <button type="button" aria-label="Good response" title="Good response" aria-pressed={rating?.rating === 1} disabled={busy || disabled} onClick={() => void rate(1)}><ThumbsUp size={16}/></button>
    <button type="button" aria-label="Bad response" title="Bad response" aria-pressed={rating?.rating === -1} disabled={busy || disabled} onClick={() => rating?.rating === -1 ? setDetails(!details) : void rate(-1)}><ThumbsDown size={16}/></button>
   </>}
   {onRetry && <button type="button" aria-label={role === "assistant" ? "Retry response" : "Retry prompt"} title="Retry" disabled={disabled} onClick={onRetry}><RotateCcw size={16}/></button>}
   {role === "user" && onEdit && <button type="button" aria-label="Edit prompt" title="Edit prompt" disabled={disabled} onClick={onEdit}><Pencil size={16}/></button>}
   {validDate && <time dateTime={date.toISOString()} title={date.toLocaleString()}>{date.toLocaleTimeString([], {hour:"numeric",minute:"2-digit"})}</time>}
  </div>
  {details && <div className={styles.details} role="group" aria-label="Optional feedback details">
   <div style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}><span>What went wrong? <small>(optional)</small></span><button type="button" aria-label="Close feedback details" onClick={() => setDetails(false)}><X size={14}/></button></div>
   <select aria-label="Feedback reason" value={reason} onChange={e => setReason(e.target.value)}><option value="">Choose a reason</option>{Object.entries(reasons).map(([key,label]) => <option key={key} value={key}>{label}</option>)}</select>
   <textarea aria-label="Optional feedback comment" placeholder="Anything else? Don't include sensitive details." maxLength={1000} value={comment} onChange={e => setComment(e.target.value)}/>
   <button className="workspace-button" type="button" disabled={busy || disabled} onClick={() => void rate(-1, true)}>{busy ? "Saving..." : "Save details"}</button>
  </div>}
  {error && <p className={styles.notice} role="alert">{error}</p>}
 </>;
}
