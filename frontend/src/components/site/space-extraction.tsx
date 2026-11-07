"use client";
import { useEffect, useRef, useState } from "react";
import { askQuestion } from "@/lib/ask-stream";
import { accountRequest } from "@/lib/account-request";
import { parseCapture, type ChatCapture } from "@/lib/chat-sources";
import { activeInventory, assertInventory } from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { CaptureScan, ChatCaptureCard } from "./chat-capture-card";

export function SpaceExtraction({file, accountId, worldId, inventoryId, spaceId, spaceName, onClose, onSaved}: {
  file: File; accountId: string; worldId: string; inventoryId: string; spaceId: string; spaceName: string;
  onClose: () => void; onSaved: () => void;
}) {
  const [photo, setPhoto] = useState("");
  const [steps, setSteps] = useState<string[]>([]);
  const [draft, setDraft] = useState<ChatCapture>();
  const [conversation, setConversation] = useState<string>();
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  const requestId = useRef(crypto.randomUUID());
  const selection = useRef(activeInventory());
  useEffect(() => {const url = URL.createObjectURL(file); setPhoto(url); return () => URL.revokeObjectURL(url);}, [file]);
  useEffect(() => {
    const abort = new AbortController();
    let capture: ChatCapture | undefined, id: string | undefined;
    const accept = (conversationId: string | undefined, value: ChatCapture | undefined) => {if (conversationId && value) {id = conversationId; capture = value;}};
    setError(""); setSteps(["Reading your photo..."]);
    void (async () => {
      try {
        assertInventory(selection.current);
        await askQuestion({accountId, worldId, requestId: requestId.current, photo: file, autoExtract: true,
          message: "Auto extract the items in this photo. Keep a draft for review before saving.", signal: abort.signal,
          onDelta: () => {}, onStatus: step => {if (!abort.signal.aborted) setSteps(s => [...s.filter(x => x !== step), step]);},
          onCapture: (cid, context) => accept(cid, context.capture),
          onDone: result => accept(result.conversationId, result.context?.capture),
        });
        abort.signal.throwIfAborted(); assertInventory(selection.current);
        if (!capture || !id) throw new Error("No extraction draft was returned. Try again.");
        const r = await accountRequest<{capture: unknown}>(accountId,
          `/worlds/${encodeURIComponent(worldId)}/conversations/${id}/captures/${capture.id}`, {
            method: "PATCH", body: {revision: capture.revision, changes: {inventory_id: inventoryId, space_id: spaceId}}, signal: abort.signal,
          });
        const verified = parseCapture(r.capture);
        if (!verified || verified.inventory_id !== inventoryId || verified.space_id !== spaceId)
          throw new Error("The Space destination could not be confirmed. Nothing was saved.");
        if (!abort.signal.aborted) {setDraft(verified); setConversation(id);}
      } catch (e) {if (!abort.signal.aborted) setError(userFacingError(e, "Could not finish this scan."));}
    })();
    return () => abort.abort();
  }, [accountId, worldId, inventoryId, spaceId, file, attempt]);
  return <Dialog open onOpenChange={open => {if (!open) onClose();}}><DialogContent style={{maxWidth: 880, maxHeight: "90dvh", overflowY: "auto"}}>
    <DialogTitle>Auto extract · {spaceName}</DialogTitle>
    {error && <p role="alert">{error}</p>}
    {draft && conversation ? <ChatCaptureCard capture={draft} accountId={accountId} worldId={worldId} conversationId={conversation}
      photo={photo} fixedDestination={{inventoryId, spaceId}} onChanged={value => {setDraft(value); if (value.receipt?.saved_count) onSaved();}}/>
      : photo && <CaptureScan photo={photo} steps={steps} stopped={false} failed={!!error} onClose={onClose} onRetry={() => setAttempt(a => a + 1)}/>}
  </DialogContent></Dialog>;
}
