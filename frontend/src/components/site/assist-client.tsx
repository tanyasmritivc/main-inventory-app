"use client";
import { MessageActions, type ResponseRating } from "./message-actions";
import { ChatProgress } from "./chat-progress";
import { ShinyText } from "./shiny-text";
import { ChatPlusMenu, type ChatChoice } from "./chat-plus-menu";
import { ChatContextPicker } from "./chat-context-picker";
import { ChatCaptureCard } from "./chat-capture-card";
import { BarcodeScanner } from "./zxing-scanner";
import {
  addChatSource,
  parseCapture,
  type ChatSource,
} from "@/lib/chat-sources";
import sourceStyles from "./chat-sources.module.css";
import { WorldActionCard, WorldResourceLinks } from "./world-chat-cards";
import { privateImageSrc } from "@/lib/private-image";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  ImagePlus,
  MessageSquarePlus,
  RefreshCw,
  Send,
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
    if (contextual && followReply.current && thread.current) {
      thread.current.scrollTop = thread.current.scrollHeight;
    }
  }, [contextual, messages]);
  const [ratings, setRatings] = useState<Record<string, ResponseRating>>({});
  const composer = useRef<HTMLTextAreaElement>(null);
  const sendLock = useRef(false);
  const [input, setInput] = useState(initialQuery),
    [photo, setPhoto] = useState<File>(),
    [preview, setPreview] = useState<string>(),
    [sending, setSending] = useState(false),
    [pendingMessageId, setPendingMessageId] = useState<string | null>(null),
    [opening, setOpening] = useState(false),
    [error, setError] = useState(""),
    [status, setStatus] = useState("");
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
        kind === "spreadsheet" ? "\\.(csv|xlsx)$" : "\\.(pdf|txt|md)$",
        "i",
      ).test(file.name)
    ) {
      setError(
        kind === "spreadsheet"
          ? "Choose a CSV or Excel (.xlsx) file."
          : "Choose a photo, PDF, TXT or Markdown file. Use Import inventory for spreadsheets.",
      );
      return;
    }
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
          setConversationId(result.conversation_id);
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
    void loadHistory().catch(() => {
      if (owner.current === accountId)
        setError("Could not load conversation history. Try again.");
    });
    return () => {
      controller.current?.abort();
      epoch.current++;
    };
  }, [accountId, initialQuery, loadHistory, worldId, draftScope]);
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
  async function openConversation(id: string) {
    if (!accountId || sending) return;
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
        setConversationId(id);
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
    setConversationId(null);
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
    if (
      !accountId ||
      sending ||
      !(await confirmAction({
        title: "Delete conversation?",
        message: "This removes the conversation from your history.",
        confirmLabel: "Delete",
        danger: true,
      }))
    )
      return;
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
    if (!file) return;
    if (
      !file.type.startsWith("image/") ||
      !file.size ||
      file.size > 10 * 1024 * 1024
    ) {
      setError("Choose a photo smaller than 10 MB.");
      return;
    }
    setAutoExtract(extract);
    setPhoto(file);
    setError("");
  }
  async function send(e?: React.FormEvent, retryPrompt?: Message, retryAnswer?: Message) {
    e?.preventDefault();
    if (!accountId || unavailable || sendLock.current || (!(retryPrompt?.content || input).trim() && !photo)) return;
    sendLock.current = true;
    const account = accountId,
      generation = epoch.current,
      text =
        retryPrompt?.content || input.trim() ||
        (autoExtract
          ? "Auto extract the items in this photo. Keep a draft for review before saving."
          : "What is in this photo?"),
      now = new Date().toISOString(),
      userId = crypto.randomUUID(),
      assistantId = crypto.randomUUID();
    const requestSources = retryPrompt?.retrySources || sources;
    const requestPhoto = retryPrompt?.retryPhoto || (retryPrompt ? undefined : photo);
    const signature = JSON.stringify({ sources: requestSources, autoExtract });
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
    draft("");
    setPendingMessageId(assistantId);
    setError("");
    setStatus(photo ? "Reading your photo…" : "Checking your inventory…");
    const placeholder: Message = { id: assistantId, role: "assistant", content: "", created_at: now, live: true };
    setMessages(m => retryAnswer
      ? m.map(row => row.id === retryAnswer.id ? placeholder : row)
      : [...m, ...(!retryPrompt ? [{ id: userId, role: "user" as const, content: text, created_at: now,
          requestId: retry.current!.id, retrySources: requestSources, retryPhoto: requestPhoto }] : []), placeholder]);
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
    const timer = window.setTimeout(() => control.abort(), 180_000);
    try {
      await askQuestion({
        accountId: account,
        worldId,
        requestId: retry.current.id,
        sources: requestSources,
        autoExtract,
        retryOf: retryAnswer?.persistedId || (retryAnswer && !retryAnswer.live ? retryAnswer.id : undefined),
        onCapture: (id, context) => {
          if (current() && !control.signal.aborted) {
            receivedCapture = true;
            setConversationId(id);
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
          if (current() && !control.signal.aborted) setStatus(value);
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
      setConversationId(final.conversationId);
      setPhoto(undefined);
      setSources([]);
      setAutoExtract(false);
      draft("");
      try {
        await loadHistory();
      } catch {
        setError(
          "Your answer was saved, but history could not refresh. Try refreshing history.",
        );
      }
    } catch (reason) {
      if (current()) {
        draft(text);
        if (receivedCapture) {
          setPhoto(undefined);
          setAutoExtract(false);
          retry.current = undefined;
        }
        setMessages((m) =>
          m.map((msg) =>
            msg.id === assistantId
              ? { ...msg, content: "", failed: true }
              : msg,
          ),
        );
        setError(
          control.signal.aborted
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
  return (
    <section className="ask-workspace">
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
            <button className="workspace-button" disabled={unavailable}>
              History
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
          className="workspace-button"
          onClick={newChat}
          disabled={unavailable}
        >
          <MessageSquarePlus size={15} />
          New conversation
        </button>
      </header>
      <div
        className={`ask-chat${!messages.length && !opening ? " is-empty" : ""}`}
      >
        <h1 className={messages.length || opening ? "sr-only" : "ask-title"}>
          {messages.length || opening ? title : <ShinyText text={title} speed={4} heading />}
        </h1>
        <div className="ask-thread" ref={thread} onScroll={contextual ? () => {
          const node = thread.current;
          if (node) followReply.current = node.scrollHeight - node.scrollTop - node.clientHeight < 80;
        } : undefined}>
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
                  className={`ask-message${m.role === "user" ? " is-user" : ""}`}
                  key={m.id}
                >
                  <strong>{m.role === "assistant" ? "FindEZ" : "You"}</strong>
                  {photoUrl && (
                    <img
                      src={privateImageSrc(photoUrl, accountId)}
                      alt="Photo used for this question"
                    />
                  )}
                  {m.content ? (
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
                    m.id === pendingMessageId ? (
                      <ChatProgress key={m.id} message={status} startedAt={progressStartedAt} lastActivityAt={lastActivityAt} />
                    ) : <p className="ask-pending">The answer did not finish.</p>
                  )}
                  {accountId &&
                    worldId &&
                    conversationId &&
                    m.context?.capture &&
                    messages.findLastIndex(
                      (msg) =>
                        msg.context?.capture?.id === m.context?.capture?.id,
                    ) === messageIndex && (
                      <ChatCaptureCard
                        key={m.context.capture.id}
                        capture={m.context.capture}
                        onChanged={(capture) => setMessages((rows) => rows.map((row) => row.context?.capture?.id === capture.id ? { ...row, context: { ...row.context, capture } } : row))}
                        accountId={accountId}
                        worldId={worldId}
                        conversationId={conversationId}
                      />
                    )}
                  {m.failed && (
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
        {!messages.length && !opening && (
          <div className="ask-empty">
            <p className="workspace-muted">
              {worldId
                ? "Find items, organize Spaces, and check stock across your organization."
                : "Find an item, check stock, or attach a photo."}
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
              onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); void send(); } }}
              className="workspace-input"
              aria-label="Your question"
              placeholder="Ask about your inventory…"
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
                  accept=".csv,.xlsx"
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
                  className="workspace-button"
                  onClick={(event) => {
                    // Cancel the click's default action before React can replace
                    // this control with the submit button during cancellation.
                    event.preventDefault();
                    event.stopPropagation();
                    controller.current?.abort();
                  }}
                >
                  Stop
                </button>
              ) : (
                <button
                  key="send"
                  type="submit"
                  className="workspace-button primary"
                  disabled={
                    !accountId || unavailable || (!input.trim() && !photo)
                  }
                >
                  <Send size={15} />
                  Ask
                </button>
              )}
            </div>
          </div>
          <p className="workspace-muted ask-disclaimer">
            Check AI answers before making changes.
          </p>
        </form>
      </div>
    </section>
  );
}
