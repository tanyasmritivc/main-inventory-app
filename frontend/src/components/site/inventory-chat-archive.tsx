"use client";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { accountRequest } from "@/lib/account-request";
import { type ConversationSummary, type ConversationMessage } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";
import { AskMarkdown } from "./ask-markdown";
import { parseAskContext, trustedAskPhotoUrl } from "@/lib/ask-answer";
import { privateImageSrc } from "@/lib/private-image";
import { useAppDialog } from "./app-dialog-provider";

// Historical inventory threads stay readable. New requests always use world chat.
export function InventoryChatArchive({
  accountId,
  inventoryId,
  name,
}: {
  accountId: string;
  inventoryId: string;
  name: string;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <button className="workspace-button">Earlier chats</button>
      </DialogTrigger>
      <DialogContent className="workspace-dialog" aria-describedby={undefined}>
        <DialogTitle>Earlier chats · {name}</DialogTitle>
        {open && (
          <Archive
            key={`${accountId}:${inventoryId}`}
            accountId={accountId}
            inventoryId={inventoryId}
          />
        )}
      </DialogContent>
    </Dialog>
  );
}
function Archive({
  accountId,
  inventoryId,
}: {
  accountId: string;
  inventoryId: string;
}) {
  const [conversations, setConversations] = useState<ConversationSummary[]>([]),
    [messages, setMessages] = useState<
      (ConversationMessage & { answer_context?: unknown })[]
    >([]),
    [selected, setSelected] = useState<string>(),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [revision, setRevision] = useState(0);
  const alive = useRef(true),
    ticket = useRef(0),
    { confirmAction } = useAppDialog();
  const path = `/inventories/${encodeURIComponent(inventoryId)}/conversations`;
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  useEffect(() => {
    let active = true;
    setBusy(true);
    accountRequest<ConversationSummary[]>(accountId, path)
      .then((value) => {
        if (active) {
          setConversations(value);
          setError("");
        }
      })
      .catch((e) => {
        if (active)
          setError(userFacingError(e, "Earlier chats could not be loaded."));
      })
      .finally(() => {
        if (active) setBusy(false);
      });
    return () => {
      active = false;
    };
  }, [accountId, path, revision]);
  async function read(id: string) {
    const current = ++ticket.current;
    setBusy(true);
    setError("");
    setMessages([]);
    setSelected(id);
    try {
      const data = await accountRequest<{
        messages: (ConversationMessage & { answer_context?: unknown })[];
      }>(accountId, `${path}/${encodeURIComponent(id)}`);
      if (alive.current && current === ticket.current)
        setMessages(data.messages);
    } catch (e) {
      if (alive.current && current === ticket.current)
        setError(userFacingError(e, "This chat could not be opened."));
    } finally {
      if (alive.current && current === ticket.current) setBusy(false);
    }
  }
  async function remove() {
    if (!selected || busy) return;
    const id = selected;
    setBusy(true);
    try {
      if (
        !(await confirmAction({
          title: "Delete conversation?",
          message: "This removes this earlier conversation from your history.",
          confirmLabel: "Delete",
          danger: true,
        })) ||
        !alive.current
      )
        return;
      await accountRequest(accountId, `${path}/${encodeURIComponent(id)}`, {
        method: "DELETE",
      });
      if (alive.current) {
        setSelected(undefined);
        setMessages([]);
        setRevision((v) => v + 1);
      }
    } catch (e) {
      if (alive.current)
        setError(userFacingError(e, "This chat could not be deleted."));
    } finally {
      if (alive.current) setBusy(false);
    }
  }
  return (
    <div
      className="app-frame"
      style={{ maxHeight: "65dvh", overflowY: "auto", padding: 16 }}
    >
      <p className="workspace-muted">
        Earlier inventory conversations are kept here. Start new conversations
        from your organization’s New chat.
      </p>
      {selected ? (
        <>
          <div className="workspace-actions">
            <button
              className="workspace-button"
              disabled={busy}
              onClick={() => {
                          setSelected(undefined);
                setMessages([]);
              }}
            >
              Back to history
            </button>
            <button
              className="workspace-button"
              disabled={busy}
              onClick={() => void remove()}
            >
              Delete conversation
            </button>
          </div>
          {messages.map((m) => {
            const context = parseAskContext(m.answer_context),
              photo = trustedAskPhotoUrl(
                context?.photoUrl,
                accountId,
                [process.env.NEXT_PUBLIC_SUPABASE_URL || ""],
                inventoryId,
              );
            return (
              <article className="ask-message" key={m.id}>
                <strong>{m.role === "user" ? "You" : "FindEZ"}</strong>
                {photo && (
                  <Image
                    unoptimized
                    width={360}
                    height={240}
                    style={{ objectFit: "contain", maxWidth: "100%" }}
                    src={privateImageSrc(photo, accountId)}
                    alt="Photo from earlier conversation"
                  />
                )}
                <AskMarkdown>{m.content}</AskMarkdown>
              </article>
            );
          })}
        </>
      ) : (
        conversations.map((c) => (
          <button
            className="ask-history-title"
            style={{
              display: "block",
              width: "100%",
              padding: "12px 0",
              textAlign: "left",
            }}
            key={c.id}
            disabled={busy}
            onClick={() => void read(c.id)}
          >
            {c.title || "Conversation"}
          </button>
        ))
      )}
      {busy && <p role="status">Loading…</p>}
      {!busy && !selected && !conversations.length && !error && (
        <p>No earlier chats in this inventory.</p>
      )}
      {error && (
        <p role="alert">
          {error}{" "}
          <button
            className="workspace-button"
            onClick={() =>
              selected ? void read(selected) : setRevision((v) => v + 1)
            }
          >
            Retry
          </button>
        </p>
      )}
    </div>
  );
}
