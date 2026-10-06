"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { ImagePlus, MessageSquarePlus, Send, Trash2, X } from "lucide-react";
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
};
export function AssistClient({ initialQuery = "" }: { initialQuery?: string }) {
  const { accountId } = useApiSession();
  return (
    <AssistClientWorkspace
      key={accountId || "signed-out"}
      initialQuery={initialQuery}
    />
  );
}
function AssistClientWorkspace({
  initialQuery = "",
}: {
  initialQuery?: string;
}) {
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
  const [input, setInput] = useState(initialQuery),
    [photo, setPhoto] = useState<File>(),
    [preview, setPreview] = useState<string>(),
    [sending, setSending] = useState(false),
    [opening, setOpening] = useState(false),
    [error, setError] = useState(""),
    [status, setStatus] = useState("");
  const photoInput = useRef<HTMLInputElement>(null);
  const loadHistory = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      generation = epoch.current;
    const list = await accountRequest<ConversationSummary[]>(
      account,
      "/conversations",
    );
    if (owner.current === account && epoch.current === generation)
      setConversations(list);
  }, [accountId]);
  useEffect(() => {
    epoch.current++;
    request.current++;
    controller.current?.abort();
    setConversations([]);
    setMessages([]);
    setConversationId(null);
    setPhoto(undefined);
    setSending(false);
    setOpening(false);
    setError("");
    if (!accountId) return;
    try {
      setInput(
        initialQuery ||
          localStorage.getItem(`findez-ask-draft:${accountId}`) ||
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
  }, [accountId, initialQuery, loadHistory]);
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
        localStorage.setItem(`findez-ask-draft:${accountId}`, value);
      } catch {
        /* The visible draft remains available for retry. */
      }
    }
  }
  async function openConversation(id: string) {
    if (!accountId || sending) return;
    const account = accountId,
      generation = epoch.current,
      ticket = ++request.current;
    setOpening(true);
    setError("");
    try {
      const result = await accountRequest<{
        messages: (ConversationMessage & { answer_context?: unknown })[];
      }>(account, `/conversations/${encodeURIComponent(id)}`);
      if (
        owner.current === account &&
        epoch.current === generation &&
        ticket === request.current
      ) {
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
    request.current++;
    setOpening(false);
    setConversationId(null);
    setMessages([]);
    setError("");
    setPhoto(undefined);
    draft("");
  }
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
        `/conversations/${encodeURIComponent(id)}`,
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
  function attach(file?: File) {
    if (!file) return;
    if (
      !file.type.startsWith("image/") ||
      !file.size ||
      file.size > 10 * 1024 * 1024
    ) {
      setError("Choose a photo smaller than 10 MB.");
      return;
    }
    setPhoto(file);
    setError("");
  }
  async function send(e: React.FormEvent) {
    e.preventDefault();
    if (!accountId || sending || opening || (!input.trim() && !photo)) return;
    const account = accountId,
      generation = epoch.current,
      text = input.trim() || "What is in this photo, and do I already own it?",
      now = new Date().toISOString(),
      userId = crypto.randomUUID(),
      assistantId = crypto.randomUUID();
    const control = new AbortController();
    controller.current = control;
    const current = () =>
      owner.current === account && epoch.current === generation;
    setSending(true);
    setError("");
    setStatus(photo ? "Reading your photo…" : "Checking your inventory…");
    setMessages((m) => [
      ...m,
      { id: userId, role: "user", content: text, created_at: now },
      { id: assistantId, role: "assistant", content: "", created_at: now },
    ]);
    let final:
      | {
          conversationId?: string;
          content?: string;
          context?: AskAnswerContext;
        }
      | undefined;
    const timer = window.setTimeout(() => control.abort(), 180_000);
    try {
      await askQuestion({
        accountId: account,
        message: text,
        photo,
        conversationId,
        signal: control.signal,
        onDelta: (delta) => {
          if (current())
            setMessages((m) =>
              m.map((msg) =>
                msg.id === assistantId
                  ? { ...msg, content: msg.content + delta }
                  : msg,
              ),
            );
        },
        onStatus: (value) => {
          if (current()) setStatus(value);
        },
        onDone: (value) => {
          final = value;
        },
      });
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
                content: final?.content ?? msg.content,
                context: final?.context,
              }
            : msg,
        ),
      );
      setConversationId(final.conversationId);
      setPhoto(undefined);
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
        setMessages((m) =>
          m.map((msg) =>
            msg.id === assistantId ? { ...msg, failed: true } : msg,
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
      window.clearTimeout(timer);
      if (current()) {
        setSending(false);
        setStatus("");
      }
      if (controller.current === control) controller.current = null;
    }
  }
  return (
    <section>
      <header className="workspace-heading">
        <div>
          <h1>Ask FindEZ</h1>
          <p>
            Ask about what you own, where it lives, and what your projects need.
          </p>
        </div>
        <button
          className="workspace-button"
          onClick={newChat}
          disabled={sending}
        >
          <MessageSquarePlus size={15} />
          New conversation
        </button>
      </header>
      <div className="workspace-split">
        <aside className="workspace-history" aria-label="Conversation history">
          <div className="workspace-section-heading">
            <h2>History</h2>
            <button
              className="workspace-button"
              disabled={sending}
              onClick={() =>
                void loadHistory().catch(() =>
                  setError("Could not refresh history."),
                )
              }
            >
              Refresh
            </button>
          </div>
          {conversations.map((c) => (
            <div className="workspace-actions" key={c.id}>
              <button
                className="workspace-button"
                style={{ flex: 1, justifyContent: "flex-start" }}
                aria-current={c.id === conversationId ? "true" : undefined}
                disabled={sending}
                onClick={() => void openConversation(c.id)}
              >
                {c.title || "New conversation"}
              </button>
              <button
                className="workspace-button"
                style={{ width: "auto" }}
                disabled={sending}
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
        <div>
          {opening ? (
            <p role="status">Opening conversation…</p>
          ) : (
            messages.map((m) => {
              const photoUrl = trustedAskPhotoUrl(
                m.context?.photoUrl,
                accountId,
                [process.env.NEXT_PUBLIC_SUPABASE_URL || ""],
              );
              return (
                <article className="ask-message" key={m.id}>
                  <strong>{m.role === "assistant" ? "FindEZ" : "You"}</strong>
                  {photoUrl && (
                    <img src={photoUrl} alt="Photo used for this question" />
                  )}
                  <div className="ask-body">
                    {m.content ||
                      (sending ? status : "The answer did not finish.")}
                  </div>
                  {m.failed && (
                    <p className="workspace-muted">
                      This answer was interrupted. Check history before relying
                      on it.
                    </p>
                  )}
                  {!m.failed && !!m.context?.sources.length && (
                    <div className="ask-sources" aria-label="Sources checked">
                      {m.context.sources.map((s, i) => (
                        <span className="ask-source" key={i} title={s.detail}>
                          {s.label}
                          {s.detail && (
                            <small style={{ display: "block" }}>
                              {s.detail}
                            </small>
                          )}
                        </span>
                      ))}
                    </div>
                  )}
                  {!m.failed && !!m.context?.rows.length && (
                    <div className="workspace-table-wrap">
                      <table className="workspace-table">
                        <thead>
                          <tr>
                            <th>Item</th>
                            <th>Available</th>
                            <th>Needed</th>
                            <th>Where / status</th>
                          </tr>
                        </thead>
                        <tbody>
                          {m.context.rows.map((r, i) => (
                            <tr key={`${r.id}-${i}`}>
                              <td>{r.name}</td>
                              <td>{r.availableQuantity}</td>
                              <td>{r.requiredQuantity ?? ""}</td>
                              <td>
                                {r.status ? (
                                  <span
                                    className={`workspace-badge ${r.status}`}
                                  >
                                    {r.status}
                                  </span>
                                ) : (
                                  r.location
                                )}
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
                </article>
              );
            })
          )}
          {!messages.length && (
            <div className="workspace-card">
              <h2>What would you like to find?</h2>
              <p className="workspace-muted">
                Use words or attach a photo. Photo questions check what you
                already own.
              </p>
              <div className="workspace-chips">
                {[
                  "Where is my soldering iron?",
                  "What is missing from my project kit?",
                  "What changed recently?",
                ].map((q) => (
                  <button key={q} onClick={() => draft(q)}>
                    {q}
                  </button>
                ))}
              </div>
            </div>
          )}
          {(error || sessionError) && (
            <div className="workspace-error" role="alert">
              {error || sessionError}
            </div>
          )}
          <form className="ask-composer" onSubmit={(e) => void send(e)}>
            {preview && (
              <div className="ask-photo-preview">
                <img src={preview} alt="Attached photo" />
                <span className="workspace-muted">{photo?.name}</span>
                <button
                  className="workspace-button"
                  type="button"
                  disabled={sending}
                  aria-label="Remove attached photo"
                  onClick={() => setPhoto(undefined)}
                >
                  <X size={14} />
                </button>
              </div>
            )}
            <textarea
              className="workspace-input"
              aria-label="Your question"
              placeholder="Ask about your inventory…"
              maxLength={4000}
              value={input}
              disabled={sending}
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
            <div className="workspace-actions">
              <button
                type="button"
                className="workspace-button"
                disabled={sending}
                onClick={() => photoInput.current?.click()}
              >
                <ImagePlus size={16} />
                Attach photo
              </button>
              {sending ? (
                <button
                  type="button"
                  className="workspace-button"
                  onClick={() => controller.current?.abort()}
                >
                  Stop
                </button>
              ) : (
                <button
                  className="workspace-button primary"
                  disabled={!accountId || opening || (!input.trim() && !photo)}
                >
                  <Send size={15} />
                  Ask
                </button>
              )}
            </div>
            {sending && (
              <p role="status" className="workspace-muted">
                {status}
              </p>
            )}
            <p className="workspace-muted">
              Answers may be inaccurate. Check the source records before making
              changes.
            </p>
          </form>
        </div>
      </div>
    </section>
  );
}
