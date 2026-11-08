"use client";
import { WorldSpreadsheetImport } from "./world-spreadsheet-import";
import { QuickStart, useHomePlaceholder } from "./web-refresh-ui";
import { MessageActions, type ResponseRating } from "./message-actions";
import { ChatProgress } from "./chat-progress";
import { ChatPlusMenu, type ChatChoice } from "./chat-plus-menu";
import { ChatContextPicker } from "./chat-context-picker";
import { ChatCaptureCard, CaptureScan } from "./chat-capture-card";
import { BarcodeScanner } from "./zxing-scanner";
import {
  addChatSource,
  parseCapture,
  type ChatSource,
} from "@/lib/chat-sources";
import sourceStyles from "./chat-sources.module.css";
import captureStyles from "./chat-capture.module.css";
import Image from "next/image";
import { FindEZMark } from "./findez-brand";
import { WorldActionCard, WorldResourceLinks } from "./world-chat-cards";
import { privateImageSrc } from "@/lib/private-image";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  History,
  ImagePlus,
  MessageSquarePlus,
  RefreshCw,
  Send,
  Square,
  Trash2,
  X,
} from "lucide-react";
import { activeInventory } from "@/lib/inventory-selection";
import { ChatItemActionCard } from "@/components/site/chat-item-action";
import { AskMarkdown } from "@/components/site/ask-markdown";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { type ConversationMessage, type ConversationSummary } from "@/lib/api";
import { conversationResumeKey } from "@/lib/app-resume";
import { accountRequest } from "@/lib/account-request";
import {
  parseAskContext,
  trustedAskPhotoUrl,
  type AskAnswerContext,
} from "@/lib/ask-answer";
import { askQuestion } from "@/lib/ask-stream";
import { useApiSession } from "@/lib/use-api-session";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { userFacingError } from "@/lib/user-facing-error";
type Message = ConversationMessage & {
  context?: AskAnswerContext;
  localPhoto?: string;
  scanPhoto?: string;
  scanFile?: File;
  scanSteps?: string[];
  scanStopped?: boolean;
  captureClosed?: boolean;
  failed?: boolean;
  live?: boolean;
  revision?: number;
  persistedId?: string;
  requestId?: string;
  retrySources?: ChatSource[];
  retryPhoto?: File;
};
type AssistProps = { initialQuery?: string; worldId?: string; title?: string; contextual?: boolean };
export function AssistClient({
  initialQuery = "",
  worldId,
  title,
  contextual = false,
}: AssistProps) {
  const { accountId } = useApiSession();
  return (
    <AssistClientWorkspace
      key={`${accountId || "signed-out"}:${worldId || activeInventory()?.inventory_id || "inventory"}`}
      worldId={worldId}
      title={title}
      contextual={contextual}
      initialQuery={initialQuery}
    />
  );
}
function AssistClientWorkspace({
  initialQuery = "",
  worldId,
  title = "Ask FindEZ",
  contextual = false,
}: AssistProps) {
  const inventoryId = worldId ? undefined : activeInventory()?.inventory_id;
  const draftScope = worldId ? `:world:${worldId}` : inventoryId ? `:inventory:${inventoryId}` : "";
  const prefix = worldId ? `/worlds/${encodeURIComponent(worldId)}` : "";
  const retry = useRef<
    | {
        text: string;
        photo?: File;
        conversationId: string | null;
        signature: string;
        id: string;
      }
    | undefined
  >(undefined);
  const { accountId, error: sessionError } = useApiSession(),
    { confirmAction } = useAppDialog();
  const owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const epoch = useRef(0),
    controller = useRef<AbortController | null>(null),
    request = useRef(0);
  const [conversations, setConversations] = useState<ConversationSummary[]>([]),
    [conversationId, setConversationId] = useState<string | null>(null),
    [messages, setMessages] = useState<Message[]>([]);
  const thread = useRef<HTMLDivElement>(null);
  const followReply = useRef(true);
  useEffect(() => {
    if (followReply.current && thread.current) {
      thread.current.scrollTop = thread.current.scrollHeight;
    }
  }, [messages]);
  const [ratings, setRatings] = useState<Record<string, ResponseRating>>({});
  const composer = useRef<HTMLTextAreaElement>(null);
  const sendLock = useRef(false);
  const photoUrls = useRef<string[]>([]);
  const dragDepth = useRef(0);
  const [draggingPhoto, setDraggingPhoto] = useState(false);
  useEffect(() => { const urls = photoUrls.current; return () => { urls.forEach(url => URL.revokeObjectURL(url)); }; }, []);
  const [spreadsheetFile, setSpreadsheetFile] = useState<File>();
  const [input, setInput] = useState(initialQuery),
    [photo, setPhoto] = useState<File>(),
    [preview, setPreview] = useState<string>(),
    [sending, setSending] = useState(false),
    [pendingMessageId, setPendingMessageId] = useState<string | null>(null),
    [opening, setOpening] = useState(false),
    [error, setError] = useState(""),
    [status, setStatus] = useState("");
  const homeEmpty = Boolean(worldId && !contextual && !messages.length && !opening);
  const { placeholder, stopPlaceholder } = useHomePlaceholder(homeEmpty, input);
  const [progressStartedAt, setProgressStartedAt] = useState(0);
  const [lastActivityAt, setLastActivityAt] = useState<number | null>(null);
  useEffect(() => {
    setRatings({});
    if (!accountId || !conversationId) return;
    const control = new AbortController();
    void accountRequest<{ratings: ResponseRating[]}>(accountId, `/response-feedback?conversation_id=${encodeURIComponent(conversationId)}`, {signal: control.signal})
      .then(result => { if (!control.signal.aborted) setRatings(previous => { const next = {...previous}; for (const r of (Array.isArray(result.ratings) ? result.ratings : [])) if (r.revision >= (next[r.message_id]?.revision || 0)) next[r.message_id] = r; return next; }); })
      .catch(() => { /* Ratings remain unselected until a confirmed receipt. */ });
    return () => control.abort();
  }, [accountId, conversationId]);
  const photoInput = useRef<HTMLInputElement>(null),
    cameraInput = useRef<HTMLInputElement>(null),
    fileInput = useRef<HTMLInputElement>(null),
    extractInput = useRef<HTMLInputElement>(null),
    spreadsheetInput = useRef<HTMLInputElement>(null);
  const [sources, setSources] = useState<ChatSource[]>([]),
    [autoExtract, setAutoExtract] = useState(false),
    [sourceBusy, setSourceBusy] = useState(false),
    [contextKind, setContextKind] = useState<
      "space" | "item" | "project" | "document"
    >(),
    [barcodeOpen, setBarcodeOpen] = useState(false),
    [barcode, setBarcode] = useState(""),
    [cameraOpen, setCameraOpen] = useState(false);
  const sourceLock = useRef(false);
  const unavailable = sending || opening || sourceBusy;
  function chooseSource(choice: ChatChoice) {
    if (unavailable) return;
    if (choice === "auto_extract") extractInput.current?.click();
    else if (choice === "library") photoInput.current?.click();
    else if (choice === "camera") cameraInput.current?.click();
    else if (choice === "file") fileInput.current?.click();
    else if (choice === "spreadsheet") spreadsheetInput.current?.click();
    else if (choice === "barcode") {
      setBarcode("");
      setCameraOpen(false);
      setBarcodeOpen(true);
    } else setContextKind(choice);
  }
  function addSource(source: ChatSource) {
    try {
      const next = addChatSource(sources, source);
      setSources(next);
      setContextKind(undefined);
      setError("");
    } catch (e) {
      setError(userFacingError(e, "Could not attach this source."));
    }
  }
  async function uploadSource(
    file?: File,
    kind: "file" | "spreadsheet" = "file",
    code?: string,
  ) {
    if (
      !accountId ||
      !worldId ||
      unavailable ||
      sourceLock.current ||
      (!file && !code)
    )
      return;
    if (file && (!file.size || file.size > 10 * 1024 * 1024)) {
      setError("Choose a nonempty file smaller than 10 MB.");
      return;
    }
    if (file && kind === "file" && file.type.startsWith("image/")) {
      attach(file);
      return;
    }
    if (
      file &&
      !new RegExp(
        kind === "spreadsheet" ? "\\.(csv|xlsx|json)$" : "\\.(pdf|txt|md)$",
        "i",
      ).test(file.name)
    ) {
      setError(
        kind === "spreadsheet"
          ? "Choose a CSV, JSON, or Excel (.xlsx) file."
          : "Choose a photo, PDF, TXT or Markdown file. Use Import inventory for spreadsheets.",
      );
      return;
    }
    if (kind === "spreadsheet" && file) { setSpreadsheetFile(file); return; }
    const account = accountId,
      generation = epoch.current;
    const current = () =>
      owner.current === account && epoch.current === generation;
    sourceLock.current = true;
    setSourceBusy(true);
    setError("");
    setCameraOpen(false);
    try {
      const body = new FormData();
      if (file) body.append("file", file);
      if (conversationId) body.append("conversation_id", conversationId);
      if (kind === "file" && !code) {
        const result = await accountRequest<ChatSource>(
          account,
          `${prefix}/chat-files`,
          { method: "POST", body },
        );
        if (
          result.kind !== "file" ||
          typeof result.text !== "string" ||
          !result.text ||
          result.text.length > 24000 ||
          typeof result.name !== "string"
        )
          throw new Error("The file could not be verified.");
        if (current()) setSources(addChatSource(sources, result));
      } else {
        const result = await accountRequest<{
          conversation_id: string;
          capture: unknown;
        }>(account, `${prefix}/captures/${code ? "barcode" : "spreadsheet"}`, {
          method: "POST",
          body: code
            ? { barcode: code, conversation_id: conversationId }
            : body,
        });
        const capture = parseCapture(result.capture);
        if (!capture || !result.conversation_id)
          throw new Error(
            "The draft could not be verified. Check history before trying again.",
          );
        if (current()) {
          selectConversation(result.conversation_id);
          setBarcodeOpen(false);
          setMessages((m) => [
            ...m,
            {
              id: capture.id,
              role: "assistant",
              content: code
                ? "Review the barcode result before saving."
                : "Review the imported items before saving.",
              created_at: new Date().toISOString(),
              context: { capture, sources: [], rows: [], rowsTruncated: false },
            },
          ]);
          void loadHistory().catch(() => {
            if (current())
              setError("The draft is saved, but history could not refresh.");
          });
        }
      }
    } catch (e) {
      if (current())
        setError(
          userFacingError(
            e,
            "This attachment could not be processed. Check history before retrying an import.",
          ),
        );
    } finally {
      sourceLock.current = false;
      if (current()) setSourceBusy(false);
    }
  }
  const selectConversation = useCallback((id: string | null) => {
    setConversationId(id);
    if (!accountId || contextual) return;
    try {
      const key = conversationResumeKey(accountId, draftScope);
      if (id) localStorage.setItem(key, id);
      else localStorage.removeItem(key);
    } catch { /* The current conversation still works without storage. */ }
  }, [accountId, draftScope, contextual]);
  const restoreConversation = useCallback(async (id: string) => {
    if (!accountId) return;
    setHistoryOpen(false);
    const account = accountId,
      generation = epoch.current,
      ticket = ++request.current;
    setOpening(true);
    setError("");
    try {
      const result = await accountRequest<{
        messages: (ConversationMessage & { answer_context?: unknown })[];
      }>(account, `${prefix}/conversations/${encodeURIComponent(id)}`);
      if (
        owner.current === account &&
        epoch.current === generation &&
        ticket === request.current
      ) {
        setSources([]);
        setPhoto(undefined);
        setAutoExtract(false);
        followReply.current = true;
        selectConversation(id);
        setMessages(
          result.messages.map((m) => ({
            ...m,
            context: parseAskContext(m.answer_context),
          })),
        );
      }
    } catch (e) {
      if (owner.current === account && ticket === request.current)
        setError(userFacingError(e, "Could not open this conversation."));
    } finally {
      if (owner.current === account && ticket === request.current)
        setOpening(false);
    }
  }, [accountId, prefix, selectConversation]);

  function openConversation(id: string) {
    if (!sending) void restoreConversation(id);
  }
  const [historyOpen, setHistoryOpen] = useState(false);
  const loadHistory = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      generation = epoch.current;
    const list = await accountRequest<ConversationSummary[]>(
      account,
      `${prefix}/conversations`,
    );
    if (owner.current === account && epoch.current === generation)
      setConversations(list);
    return list;
  }, [accountId, prefix]);
  useEffect(() => {
    epoch.current++;
    request.current++;
    controller.current?.abort();
    setConversations([]);
    setMessages([]);
    setConversationId(null);
    setPhoto(undefined);
    setSending(false);
    setPendingMessageId(null);
    setOpening(false);
    setError("");
    if (!accountId) return;
    try {
      setInput(
        initialQuery ||
          localStorage.getItem(
            `findez-ask-draft:${accountId}${draftScope}`,
          ) ||
          "",
      );
    } catch {
      setInput(initialQuery);
    }
    const generation = epoch.current;
    void loadHistory().then((list) => {
      if (owner.current !== accountId || epoch.current !== generation || initialQuery || contextual) return;
      let remembered: string | null = null;
      try { remembered = localStorage.getItem(conversationResumeKey(accountId, draftScope)); } catch {}
      if (remembered && list?.some(row => row.id === remembered)) void restoreConversation(remembered);
      else if (remembered) selectConversation(null);
    }).catch(() => {
      if (owner.current === accountId)
        setError("Could not load conversation history. Try again.");
    });
    return () => {
      controller.current?.abort();
      epoch.current++;
    };
  }, [accountId, initialQuery, loadHistory, worldId, draftScope, contextual, restoreConversation, selectConversation]);
  useEffect(() => {
    if (!photo) {
      setPreview(undefined);
      return;
    }
    const url = URL.createObjectURL(photo);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [photo]);
  function draft(value: string) {
    setInput(value);
    if (accountId) {
      try {
        localStorage.setItem(
          `findez-ask-draft:${accountId}${draftScope}`,
          value,
        );
      } catch {
        /* The visible draft remains available for retry. */
      }
    }
  }
  function newChat() {
    // A draft upload may already be committed. Keep it in its originating chat
    // until its receipt returns, including when New chat comes from the sidebar.
    if (sourceLock.current) return;
    controller.current?.abort();
    epoch.current++;
    retry.current = undefined;
    setSending(false);
    setPendingMessageId(null);
    setStatus("");
    request.current++;
    setOpening(false);
    followReply.current = true;
    selectConversation(null);
    setMessages([]);
    setError("");
    setPhoto(undefined);
    setSources([]);
    setAutoExtract(false);
    setContextKind(undefined);
    setBarcodeOpen(false);
    setCameraOpen(false);
    draft("");
  }
  useEffect(() => {
    if (!worldId) return;
    const fresh = () => newChat();
    window.addEventListener("findez-new-world-chat", fresh);
    return () => window.removeEventListener("findez-new-world-chat", fresh);
  });
  async function removeConversation(id: string) {
    if (!accountId || sending) return;
    // Release the history modal's pointer/focus trap before opening the app
    // confirmation. Otherwise the confirmation is visible but cannot be used.
    setHistoryOpen(false);
    if (!(await confirmAction({title: "Delete conversation?",
      message: "This removes the conversation from your history.", confirmLabel: "Delete", danger: true}))) {
      setHistoryOpen(true); return;
    }
    const account = accountId;
    try {
      await accountRequest(
        account,
        `${prefix}/conversations/${encodeURIComponent(id)}`,
        { method: "DELETE" },
      );
      if (owner.current !== account) return;
      if (conversationId === id) newChat();
      await loadHistory();
    } catch (e) {
      if (owner.current === account)
        setError(userFacingError(e, "Could not delete this conversation."));
    }
  }
  function attach(file?: File, extract = false) {
    if (!file || unavailable || sendLock.current) return;
    if (
      !file.type.startsWith("image/") ||
      !file.size ||
      file.size > 10 * 1024 * 1024
    ) {
      setError("Choose a photo smaller than 10 MB.");
      return;
    }
    setError("");
    if (worldId) {
      void send(undefined, undefined, undefined, file);
    } else {
      setAutoExtract(extract);
      setPhoto(file);
    }
  }
  async function send(e?: React.FormEvent, retryPrompt?: Message, retryAnswer?: Message, scanFile?: File) {
    e?.preventDefault();
    if (!accountId || unavailable || sendLock.current || (!(retryPrompt?.content || input).trim() && !photo && !scanFile)) return;
    sendLock.current = true;
    followReply.current = true;
    const extracting = !!scanFile || autoExtract;
    const account = accountId,
      generation = epoch.current,
      text =
        (scanFile ? "" : retryPrompt?.content || input.trim()) ||
        (extracting
          ? "Auto extract the items in this photo. Keep a draft for review before saving."
          : "What is in this photo?"),
      now = new Date().toISOString(),
      userId = crypto.randomUUID(),
      assistantId = crypto.randomUUID();
    const requestSources = retryPrompt?.retrySources || sources;
    const requestPhoto = scanFile || retryPrompt?.retryPhoto || (retryPrompt ? undefined : photo);
    const scanPhoto = scanFile ? URL.createObjectURL(scanFile) : undefined;
    if (scanPhoto) photoUrls.current.push(scanPhoto);
    const signature = JSON.stringify({ sources: requestSources, autoExtract: extracting });
    if (
      !retry.current ||
      retry.current.signature !== signature ||
      retry.current.text !== text ||
      retry.current.photo !== requestPhoto ||
      retry.current.conversationId !== conversationId
    )
      retry.current = {
        text,
        photo: requestPhoto,
        conversationId,
        signature,
        id: retryPrompt?.requestId || crypto.randomUUID(),
      };
    const control = new AbortController();
    controller.current = control;
    const current = () =>
      owner.current === account && epoch.current === generation;
    setSending(true);
    setProgressStartedAt(Date.now());
    setLastActivityAt(null);
    if (!scanFile) draft("");
    setPendingMessageId(assistantId);
    setError("");
    setStatus(requestPhoto ? "Reading your photo..." : "Checking your inventory…");
    const placeholder: Message = { id: assistantId, role: "assistant", content: "", created_at: now, live: true, scanPhoto, scanFile, scanSteps: scanFile ? ["Reading your photo..."] : undefined };
    setMessages(m => retryAnswer
      ? m.map(row => row.id === retryAnswer.id ? placeholder : row)
      : [...m, ...(!retryPrompt ? [{ id: userId, role: "user" as const, content: text, created_at: now,
          requestId: retry.current!.id, retrySources: requestSources, retryPhoto: requestPhoto, localPhoto: scanPhoto }] : []), placeholder]);
    let final:
      | {
          conversationId?: string;
          messageId?: string;
          createdAt?: string;
          content?: string;
          context?: AskAnswerContext;
        }
      | undefined;
    let receivedCapture = false;
    let provisional = "";
    // Auto Extract owns its longer inference deadline in askQuestion.
    const timer = extracting && worldId ? undefined : window.setTimeout(() => control.abort(), 180_000);
    try {
      await askQuestion({
        accountId: account,
        worldId,
        requestId: retry.current.id,
        sources: requestSources,
        autoExtract: extracting,
        retryOf: retryAnswer?.persistedId || (retryAnswer && !retryAnswer.live ? retryAnswer.id : undefined),
        onCapture: (id, context) => {
          if (current() && !control.signal.aborted) {
            receivedCapture = true;
            selectConversation(id);
            setMessages((m) =>
              m.map((msg) =>
                msg.id === assistantId ? { ...msg, context } : msg,
              ),
            );
          }
        },
        message: text,
        photo: retryAnswer?.persistedId || (retryAnswer && !retryAnswer.live) ? undefined : requestPhoto,
        conversationId,
        signal: control.signal,
        onDelta: (delta) => {
          if (!current() || control.signal.aborted) return;
          provisional += delta;
          const content = provisional;
          setMessages(rows => rows.map(row => row.id === assistantId ? { ...row, content } : row));
        },
        onReset: () => {
          if (!current() || control.signal.aborted) return;
          provisional = "";
          setMessages(rows => rows.map(row => row.id === assistantId ? { ...row, content: "", revision: (row.revision ?? 0) + 1 } : row));
        },
        onActivity: () => { if (current() && !control.signal.aborted) setLastActivityAt(Date.now()); },
        onStatus: (value) => {
          if (current() && !control.signal.aborted) {
            setStatus(value);
            if (scanFile) setMessages(rows => rows.map(row => row.id === assistantId
              ? { ...row, scanSteps: [...(row.scanSteps || []).filter(step => step !== value), value] } : row));
          }
        },
        onDone: (value) => {
          if (!control.signal.aborted) final = value;
        },
      });
      control.signal.throwIfAborted();
      if (!current()) return;
      if (!final?.conversationId)
        throw new Error(
          "Your answer was not confirmed in history. Open history before retrying.",
        );
      setMessages((m) =>
        m.map((msg) =>
          msg.id === assistantId
            ? {
                ...msg,
                persistedId: final?.messageId,
                created_at: final?.createdAt || new Date().toISOString(),
                content: final?.content ?? provisional,
                context: final?.context || msg.context,
              }
            : msg,
        ),
      );
      retry.current = undefined;
      selectConversation(final.conversationId);
      setPhoto(undefined);
      if (!scanFile) setSources([]);
      setAutoExtract(false);
      if (!scanFile) draft("");
      try {
        await loadHistory();
      } catch {
        setError(
          "Your answer was saved, but history could not refresh. Try refreshing history.",
        );
      }
    } catch (reason) {
      if (current()) {
        if (!scanFile) draft(text);
        if (receivedCapture) {
          setPhoto(undefined);
          setAutoExtract(false);
          retry.current = undefined;
        }
        setMessages((m) =>
          m.map((msg) =>
            msg.id === assistantId
              ? { ...msg, failed: true, scanStopped: !!scanFile && control.signal.aborted }
              : msg,
          ),
        );
        setError(
          scanFile && control.signal.aborted
            ? "Scan stopped. Nothing was saved."
            : control.signal.aborted
            ? "Your question stopped before confirmation. Your draft is available to retry. Check history for any saved answer."
            : userFacingError(
                reason,
                "Your question could not be completed. Your draft is available to retry.",
              ),
        );
      }
    } finally {
      sendLock.current = false;
      window.clearTimeout(timer);
      if (current()) {
        setSending(false);
        setPendingMessageId(null);
        setStatus("");
      }
      if (controller.current === control) controller.current = null;
    }
  }
  const latestScan = messages.findLast(row => row.scanPhoto && !row.captureClosed);
  const activeScanKey = latestScan ? `${latestScan.id}:${latestScan.context?.capture?.id || ""}:${latestScan.context?.capture?.status || ""}` : null;
  useEffect(() => {
    if (!followReply.current) return;
    const frame = requestAnimationFrame(() => {
      thread.current?.querySelector('[data-scan-active] section')?.scrollIntoView?.({block: "nearest"});
    });
    return () => cancelAnimationFrame(frame);
  }, [activeScanKey]);
  return (
    <section className="ask-workspace" data-contextual={contextual || undefined}
      onDragEnter={event => { if (worldId && event.dataTransfer.types.includes("Files")) { event.preventDefault(); dragDepth.current++; setDraggingPhoto(true); } }}
      onDragOver={event => { if (worldId && event.dataTransfer.types.includes("Files")) { event.preventDefault(); event.dataTransfer.dropEffect = unavailable ? "none" : "copy"; } }}
      onDragLeave={event => { if (worldId && event.dataTransfer.types.includes("Files")) { dragDepth.current = Math.max(0, dragDepth.current - 1); if (!dragDepth.current) setDraggingPhoto(false); } }}
      onDrop={event => { if (!worldId) return; event.preventDefault(); dragDepth.current = 0; setDraggingPhoto(false); attach(Array.from(event.dataTransfer.files).find(file => file.type.startsWith("image/"))); }}>
      {draggingPhoto && <div className={captureStyles.drop} role="status"><div><ImagePlus size={28} /><b>Drop a photo to scan</b><small>FindEZ will find the items for you to review.</small></div></div>}
      {spreadsheetFile && accountId && worldId && <WorldSpreadsheetImport file={spreadsheetFile} accountId={accountId} worldId={worldId} onClose={() => setSpreadsheetFile(undefined)}/>}
      {contextKind && accountId && worldId && (
        <ChatContextPicker
          key={`${worldId}:${contextKind}`}
          accountId={accountId}
          worldId={worldId}
          kind={contextKind}
          onSelect={addSource}
          onClose={() => setContextKind(undefined)}
        />
      )}
      <Dialog
        open={barcodeOpen}
        onOpenChange={(open) => {
          if (!sourceBusy) {
            setBarcodeOpen(open);
            setCameraOpen(false);
          }
        }}
      >
        <DialogContent className={sourceStyles.dialog}>
          <DialogTitle>Scan barcode</DialogTitle>
          <DialogDescription>
            Scan with your camera or enter the code. Review the result before
            saving.
          </DialogDescription>
          {cameraOpen ? (
            <BarcodeScanner
              onDetected={(code) => {
                setBarcode(code);
                setCameraOpen(false);
              }}
            />
          ) : (
            <button
              className="workspace-button"
              disabled={sourceBusy}
              onClick={() => setCameraOpen(true)}
            >
              Open camera
            </button>
          )}
          <form
            className={sourceStyles.stack}
            onSubmit={(e) => {
              e.preventDefault();
              void uploadSource(undefined, "spreadsheet", barcode.trim());
            }}
          >
            <label>
              Barcode
              <input
                value={barcode}
                maxLength={100}
                onChange={(e) => setBarcode(e.target.value)}
                disabled={sourceBusy}
              />
            </label>
            <button
              className="workspace-button primary"
              disabled={sourceBusy || !barcode.trim()}
            >
              {sourceBusy ? "Looking up..." : "Look up barcode"}
            </button>
          </form>
          {error && <p role="alert">{error}</p>}
        </DialogContent>
      </Dialog>
      <header className="ask-toolbar">
        <Dialog open={historyOpen} onOpenChange={setHistoryOpen}>
          <DialogTrigger asChild>
            <button className="workspace-button ask-toolbar-icon" aria-label="History" title="History" disabled={unavailable}>
              <History size={18} aria-hidden="true" />
            </button>
          </DialogTrigger>
          <DialogContent
            className="workspace-dialog ask-history-dialog"
            aria-describedby={undefined}
          >
            <div className="app-frame ask-history-surface">
              <aside
                className="workspace-history"
                aria-label="Conversation history"
              >
                <div className="workspace-section-heading">
                  <DialogTitle>History</DialogTitle>
                  <button
                    className="workspace-button"
                    aria-label="Refresh history"
                    title="Refresh history"
                    disabled={unavailable}
                    onClick={() =>
                      void loadHistory().catch(() =>
                        setError("Could not refresh history."),
                      )
                    }
                  >
                    <RefreshCw size={14} />
                  </button>
                </div>
                {conversations.map((c) => (
                  <div className="ask-history-row" key={c.id}>
                    <button
                      className="ask-history-title"
                      title={c.title || "New conversation"}
                      aria-current={
                        c.id === conversationId ? "true" : undefined
                      }
                      disabled={unavailable}
                      onClick={() => void openConversation(c.id)}
                    >
                      {c.title || "New conversation"}
                    </button>
                    <button
                      className="ask-history-delete"
                      disabled={unavailable}
                      aria-label={`Delete ${c.title || "conversation"}`}
                      onClick={() => void removeConversation(c.id)}
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                ))}
                {!conversations.length && (
                  <p className="workspace-muted">
                    Your saved conversations appear here.
                  </p>
                )}
              </aside>
            </div>
          </DialogContent>
        </Dialog>
        <button
          className="workspace-button ask-toolbar-icon"
          aria-label="New conversation"
          title="New conversation"
          onClick={newChat}
          disabled={unavailable}
        >
          <MessageSquarePlus size={18} aria-hidden="true" />
        </button>
      </header>
      <div
        className={`ask-chat${!messages.length && !opening ? " is-empty" : ""}`}
      >
        <h1 className={messages.length || opening ? "sr-only" : `ask-title${worldId ? " ask-world-title" : ""}`}>
          {messages.length || opening ? title : <span className="shiny-text">{title}</span>}
        </h1>
        <div className="ask-thread" role="region" aria-label="Conversation" tabIndex={0} ref={thread} onScroll={() => {
          const node = thread.current;
          if (node) followReply.current = node.scrollHeight - node.scrollTop - node.clientHeight < 80;
        }}>
          {opening ? (
            <p role="status">Opening conversation…</p>
          ) : (
            messages.map((m, messageIndex) => {
              const photoUrl = trustedAskPhotoUrl(
                m.context?.photoUrl,
                accountId,
                [process.env.NEXT_PUBLIC_SUPABASE_URL || ""],
                activeInventory()?.inventory_id,
              );
              return (
                <article
                  className={`ask-message${m.role === "user" ? " is-user" : ""}${m.scanPhoto ? ` ${captureStyles.reply}` : ""}`}
                  key={m.id}
                  data-scan-active={m.id === latestScan?.id || undefined}
                >
                  {m.scanPhoto ? <span className={captureStyles.mark}><FindEZMark width={28} height={28} /></span> : <strong>{m.role === "assistant" ? "FindEZ" : "You"}</strong>}
                  {m.localPhoto && <figure className={captureStyles.userPhoto}><Image unoptimized src={m.localPhoto} alt="Photo to extract" width={150} height={200} /><figcaption>{m.retryPhoto?.name}</figcaption></figure>}
                  {photoUrl && (
                    <img
                      src={privateImageSrc(photoUrl, accountId)}
                      alt="Photo used for this question"
                    />
                  )}
                  {!m.localPhoto && (m.content ? (
                    m.role === "assistant" ? (
                      <AskMarkdown
                        key={`${m.id}-${m.revision ?? 0}`}
                        animate={!!m.live && !m.failed}
                      >
                        {m.content}
                      </AskMarkdown>
                    ) : (
                      <div className="ask-body">{m.content}</div>
                    )
                  ) : (
                    m.id === pendingMessageId && !m.scanPhoto ? (
                      <ChatProgress key={m.id} message={status} startedAt={progressStartedAt} lastActivityAt={lastActivityAt} />
                    ) : !m.scanPhoto ? <p className="ask-pending">The answer did not finish.</p> : null
                  ))}
                  {m.scanPhoto && !m.context?.capture && !m.captureClosed && <CaptureScan
                    photo={m.scanPhoto} steps={m.scanSteps || []} stopped={!!m.scanStopped} failed={!!m.failed}
                    onClose={() => { if (m.id === pendingMessageId) controller.current?.abort(); setMessages(rows => rows.map(row => row.id === m.id ? {...row, captureClosed: true} : row)); }}
                    onRetry={() => { if (!unavailable && m.scanFile) { setMessages(rows => rows.map(row => row.id === m.id ? {...row, captureClosed: true} : row)); void send(undefined, undefined, undefined, m.scanFile); } }}
                  />}
                  {accountId &&
                    worldId &&
                    conversationId &&
                    m.context?.capture && !m.captureClosed &&
                    messages.findLastIndex(
                      (msg) =>
                        msg.context?.capture?.id === m.context?.capture?.id,
                    ) === messageIndex && (
                      <ChatCaptureCard
                        key={m.context.capture.id}
                        capture={m.context.capture}
                        photo={m.scanPhoto}
                        onClose={() => { if (m.id === pendingMessageId) controller.current?.abort(); setMessages(rows => rows.map(row => row.id === m.id ? {...row, captureClosed: true} : row)); }}
                        onChanged={(capture) => setMessages((rows) => rows.map((row) => row.context?.capture?.id === capture.id ? { ...row, context: { ...row.context, capture } } : row))}
                        accountId={accountId}
                        worldId={worldId}
                        conversationId={conversationId}
                      />
                    )}
                  {m.failed && !m.scanPhoto && (
                    <p className="workspace-muted">
                      This answer was interrupted. Check history before relying
                      on it.
                    </p>
                  )}
                  {!m.failed &&
                    accountId &&
                    m.context?.pendingActions?.map((action) => (
                      <ChatItemActionCard
                        key={`${action.id}-${action.status}`}
                        action={action}
                        accountId={accountId}
                        worldId={worldId}
                        onReply={(reply) => {
                          if (owner.current !== accountId) return;
                          setMessages((messages) =>
                            messages.some((message) => message.id === reply.id)
                              ? messages
                              : [
                                  ...messages,
                                  {
                                    id: reply.id,
                                    role: "assistant",
                                    content: reply.content,
                                    created_at: new Date().toISOString(),
                                    live: true,
                                  },
                                ],
                          );
                          void loadHistory().catch(() =>
                            setError(
                              "Your change is confirmed, but history could not refresh.",
                            ),
                          );
                        }}
                      />
                    ))}
                  {!m.failed &&
                    accountId &&
                    worldId &&
                    m.context?.worldActions?.map((action) => (
                      <WorldActionCard
                        key={action.id}
                        action={action}
                        accountId={accountId}
                        worldId={worldId}
                        onCaptureChanged={(capture) => setMessages((rows) => rows.map((row) => row.context?.capture?.id === capture.id ? { ...row, context: { ...row.context, capture } } : row))}
                      />
                    ))}
                  {!m.failed && accountId && worldId && !(m.context?.capture && m.context.capture.status !== "saved") && (
                    <WorldResourceLinks
                      links={m.context?.resourceLinks || []}
                      accountId={accountId}
                      worldId={worldId}
                    />
                  )}
                  {!m.failed &&
                    m.context &&
                    (!!m.context.sources.length || !!m.context.rows.length) && (
                      <details className="ask-evidence">
                        <summary>Sources</summary>
                        <ul
                          className="ask-sources"
                          aria-label="Sources checked"
                        >
                          {m.context.sources.map((s, i) => (
                            <li key={i}>
                              <strong>{s.label}</strong>
                              {s.detail && <span>{s.detail}</span>}
                            </li>
                          ))}
                        </ul>
                        {!!m.context.rows.length && (
                          <div className="workspace-table-wrap">
                            <table className="workspace-table">
                              <thead>
                                <tr>
                                  <th>Item</th>
                                  <th>
                                    {m.context.rows.some(
                                      (r) => r.requiredQuantity !== undefined,
                                    )
                                      ? "Available"
                                      : "Recorded quantity"}
                                  </th>
                                  {m.context.rows.some(
                                    (r) => r.requiredQuantity !== undefined,
                                  ) && <th>Needed</th>}
                                  <th>Recorded location</th>
                                </tr>
                              </thead>
                              <tbody>
                                {m.context.rows.map((r, i) => (
                                  <tr key={`${r.id}-${i}`}>
                                    <td>
                                      {r.name}
                                      {r.matchBasis && (
                                        <small
                                          className="workspace-muted"
                                          style={{ display: "block" }}
                                        >
                                          {r.matchBasis}
                                        </small>
                                      )}
                                    </td>
                                    <td>{r.availableQuantity ?? "Unknown"}</td>
                                    {m.context?.rows.some(
                                      (row) =>
                                        row.requiredQuantity !== undefined,
                                    ) && <td>{r.requiredQuantity ?? ""}</td>}
                                    <td>
                                      {!r.location ||
                                      r.location.toLowerCase() === "unsorted"
                                        ? "Not set"
                                        : r.location}
                                      {r.status ? (
                                        <span
                                          className={`workspace-badge ${r.status}`}
                                        >
                                          {r.status}
                                        </span>
                                      ) : null}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                            {m.context.rowsTruncated && (
                              <p className="workspace-muted">
                                Showing the first 100 checked records.
                              </p>
                            )}
                          </div>
                        )}
                      </details>
                    )}
                  {m.id !== pendingMessageId && m.content && !m.failed && <MessageActions
                    content={m.content} role={m.role} timestamp={m.created_at} accountId={accountId || undefined}
                    messageId={m.role === "assistant" ? m.persistedId || (!m.live ? m.id : undefined) : undefined}
                    rating={ratings[m.persistedId || m.id]}
                    onRating={saved => setRatings(previous => ({...previous, [saved.message_id]: saved}))}
                    disabled={unavailable}
                    retryDisabled={sending}
                    onRetry={worldId || m.failed ? () => {
                      const prompt = m.role === "user" ? m : messages.slice(0, messageIndex).findLast(row => row.role === "user");
                      const answer = m.role === "assistant" ? m : messages.slice(messageIndex + 1).find(row => row.role === "assistant");
                      if (prompt) void send(undefined, prompt, answer);
                    } : undefined}
                  />}
                </article>
              );
            })
          )}
        </div>
        {!worldId && !messages.length && !opening && (
          <div className="ask-empty">
            <p className="workspace-muted">
              Find an item, check stock, or attach a photo.
            </p>
          </div>
        )}
        {(error || sessionError) && (
          <div className="workspace-error" role="alert">
            {error || sessionError}
          </div>
        )}
        <form className="ask-composer" onSubmit={(e) => void send(e)}>
          <div className="ask-composer-box">
            {sourceBusy && <p role="status">Preparing your attachment...</p>}
            {!!sources.length && (
              <div className={sourceStyles.chips}>
                {sources.map((source, i) => (
                  <div className={sourceStyles.chip} key={i}>
                    <span title={source.name}>
                      {source.name}
                      {source.kind === "file" && source.truncated
                        ? " (excerpt)"
                        : ""}
                    </span>
                    <button
                      type="button"
                      disabled={unavailable}
                      aria-label={`Remove ${source.name}`}
                      onClick={() =>
                        setSources((v) => v.filter((_, n) => n !== i))
                      }
                    >
                      <X size={13} />
                    </button>
                  </div>
                ))}
              </div>
            )}
            {autoExtract && photo && (
              <p className={sourceStyles.muted}>
                Auto Extract: creates an item draft for your review.
              </p>
            )}
            {preview && (
              <div className="ask-photo-preview">
                <img
                  src={privateImageSrc(preview, accountId)}
                  alt="Attached photo"
                />
                <span className="workspace-muted">{photo?.name}</span>
                <button
                  className="workspace-button"
                  type="button"
                  disabled={unavailable}
                  aria-label="Remove attached photo"
                  onClick={() => setPhoto(undefined)}
                >
                  <X size={14} />
                </button>
              </div>
            )}
            <textarea
              ref={composer}
              onPaste={event => { if (!worldId) return; const file = Array.from(event.clipboardData.items).find(item => item.type.startsWith("image/"))?.getAsFile(); if (file) { event.preventDefault(); attach(file); } }}
              onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); void send(); } }}
              className="workspace-input"
              aria-label="Your question"
              placeholder={homeEmpty ? placeholder : "Ask about your inventory…"}
              onFocus={stopPlaceholder}
              maxLength={4000}
              value={input}
              disabled={unavailable}
              onChange={(e) => draft(e.target.value)}
            />
            <input
              ref={photoInput}
              type="file"
              accept="image/*"
              hidden
              onChange={(e) => {
                attach(e.target.files?.[0]);
                e.target.value = "";
              }}
            />
            {worldId && (
              <>
                <input
                  ref={cameraInput}
                  type="file"
                  accept="image/*"
                  capture="environment"
                  hidden
                  onChange={(e) => {
                    attach(e.target.files?.[0]);
                    e.target.value = "";
                  }}
                />
                <input
                  ref={extractInput}
                  type="file"
                  accept="image/*"
                  hidden
                  onChange={(e) => {
                    attach(e.target.files?.[0], true);
                    e.target.value = "";
                  }}
                />
                <input
                  ref={fileInput}
                  type="file"
                  accept="image/*,.pdf,.txt,.md"
                  hidden
                  onChange={(e) => {
                    void uploadSource(e.target.files?.[0]);
                    e.target.value = "";
                  }}
                />
                <input
                  ref={spreadsheetInput}
                  type="file"
                  accept=".csv,.xlsx,.json"
                  hidden
                  onChange={(e) => {
                    void uploadSource(e.target.files?.[0], "spreadsheet");
                    e.target.value = "";
                  }}
                />
              </>
            )}
            <div className="workspace-actions">
              {worldId ? (
                <ChatPlusMenu disabled={unavailable} onSelect={chooseSource} />
              ) : (
                <button
                  type="button"
                  className="workspace-button"
                  disabled={unavailable}
                  onClick={() => photoInput.current?.click()}
                >
                  <ImagePlus size={16} />
                  Attach photo
                </button>
              )}
              {sending ? (
                <button
                  key="stop"
                  type="button"
                  className="workspace-button ask-action-icon"
                  aria-label="Stop"
                  title="Stop response"
                  onClick={(event) => {
                    // Cancel the click's default action before React can replace
                    // this control with the submit button during cancellation.
                    event.preventDefault();
                    event.stopPropagation();
                    controller.current?.abort();
                  }}
                >
                  <Square size={15} fill="currentColor" aria-hidden="true" />
                </button>
              ) : (
                <button
                  key="send"
                  type="submit"
                  className="workspace-button primary ask-action-icon"
                  aria-label="Ask"
                  title="Send message"
                  disabled={
                    !accountId || unavailable || (!input.trim() && !photo)
                  }
                >
                  <Send size={17} aria-hidden="true" />
                </button>
              )}
            </div>
          </div>
          <p className="workspace-muted ask-disclaimer">
            Check AI answers before making changes.
          </p>
        </form>
        {homeEmpty && <QuickStart disabled={unavailable || !accountId}
          onPhoto={() => chooseSource("auto_extract")}
          onImport={() => chooseSource("spreadsheet")}
          onFind={() => { stopPlaceholder(); draft("Where are the "); composer.current?.focus(); }}
          onLow={() => { stopPlaceholder(); draft("What is running low?"); requestAnimationFrame(() => composer.current?.form?.requestSubmit()); }} />}
      </div>
    </section>
  );
}
