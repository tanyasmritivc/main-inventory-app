import { sourcePayload, type ChatSource } from "./chat-sources";
import {
  activeInventory,
  assertInventory,
  inventoryApiPath,
} from "@/lib/inventory-selection";
import { apiBase, ApiError } from "@/lib/api";
import { accountToken } from "@/lib/account-request";
import { parseAskContext, type AskAnswerContext } from "@/lib/ask-answer";

export type AskStreamEvent = {
  type?: string;
  content?: string;
  delta?: string;
  assistant_message?: string;
  conversation_id?: string;
  message_id?: string;
  created_at?: string;
  answer_context?: unknown;
  message?: string;
  error?: string;
  code?: string;
};

export async function readAskEvents(
  body: ReadableStream<Uint8Array>,
  onEvent: (event: AskStreamEvent) => void,
) {
  const reader = body.getReader(),
    decoder = new TextDecoder();
  let buffer = "",
    ended = false;
  function consume(block: string) {
    const data = block
      .split(/\r?\n/)
      .filter((line) => line.startsWith("data:"))
      .map((line) => line.slice(5).replace(/^ /, ""))
      .join("\n");
    if (ended || !data || data === "[DONE]") return;
    let event: AskStreamEvent;
    try {
      event = JSON.parse(data);
    } catch {
      throw new Error("The answer stream was interrupted. Please try again.");
    }
    if (event.error || event.type === "error") {
      throw new Error(
        event.code === "photo_timeout"
          ? "Photo analysis took too long. Try a clearer photo."
          : event.error ||
            event.message ||
            "Your question could not be completed. Please try again.",
      );
    }
    if (event.type === "done") ended = true;
    onEvent(event);
  }
  try {
    while (true) {
      const { value, done } = await reader.read();
      buffer += decoder.decode(value, { stream: !done });
      const blocks = buffer.split(/\r?\n\r?\n/);
      buffer = blocks.pop() ?? "";
      for (const block of blocks) consume(block);
      if (done || ended) break;
    }
    if (buffer.trim()) consume(buffer);
    if (!ended)
      throw new Error("The answer stream was interrupted. Please try again.");
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

export async function askQuestion({
  accountId,
  message,
  photo,
  conversationId,
  worldId,
  requestId,
  retryOf,
  sources = [],
  autoExtract = false,
  onCapture,
  signal,
  onDelta,
  onStatus,
  onReset,
  onDone,
}: {
  accountId: string;
  worldId?: string;
  requestId?: string;
  retryOf?: string;
  sources?: ChatSource[];
  autoExtract?: boolean;
  onCapture?: (conversationId: string, context: AskAnswerContext) => void;
  message: string;
  photo?: File;
  conversationId?: string | null;
  signal: AbortSignal;
  onDelta: (text: string) => void;
  onStatus: (text: string) => void;
  onReset?: () => void;
  onDone: (result: {
    conversationId?: string;
    messageId?: string;
    createdAt?: string;
    content?: string;
    context?: AskAnswerContext;
  }) => void;
}) {
  if (
    photo &&
    (!photo.size ||
      photo.size > 10 * 1024 * 1024 ||
      !photo.type.startsWith("image/"))
  )
    throw new Error("Choose a photo smaller than 10 MB.");
  const selected = activeInventory();
  if (selected && selected.accountId !== accountId)
    throw new Error("Your account changed. Reopen this page.");
  const token = await accountToken(accountId);
  assertInventory(selected);
  const form = new FormData();
  const capabilities = worldId
    ? {
        supports_item_management: true,
        supports_task_actions: true,
        supports_capture: true,
        request_id: requestId,
        retry_of: retryOf,
      }
    : {};
  if (photo) {
    form.append("file", photo);
    if (worldId) {
      form.append("sources", JSON.stringify(sources.map(sourcePayload)));
      if (autoExtract) form.append("auto_extract", "true");
    }
    form.append("message", message);
    form.append("supports_item_actions", "true");
    for (const [key, value] of Object.entries(capabilities))
      if (value !== undefined) form.append(key, String(value));
    if (conversationId) form.append("conversation_id", conversationId);
  }
  const response = await fetch(
    `${apiBase()}${worldId ? `/worlds/${encodeURIComponent(worldId)}${photo ? "/ai_photo_question" : "/ai_command"}` : inventoryApiPath(photo ? "/ai_photo_question" : "/ai_command?stream=true", selected)}`,
    {
      method: "POST",
      signal,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "text/event-stream",
        ...(!photo ? { "Content-Type": "application/json" } : {}),
      },
      body: photo
        ? form
        : JSON.stringify({
            message,
            conversation_id: conversationId || null,
            supports_item_actions: true,
            ...capabilities,
            ...(worldId ? { sources: sources.map(sourcePayload) } : {}),
          }),
    },
  );
  if (!response.ok || !response.body)
    throw new ApiError(
      response.status === 403
        ? "Your account limit was reached or you do not have permission."
        : response.status === 413
          ? "Choose a photo smaller than 10 MB."
          : "Your question could not be completed. Please try again.",
      response.status,
      null,
    );
  await readAskEvents(response.body, (event) => {
    assertInventory(selected);
    if (event.type === "capture" && event.conversation_id) {
      const context = parseAskContext(event.answer_context);
      if (context) onCapture?.(event.conversation_id, context);
    }
    if (event.type === "reset") onReset?.();
    if (event.content || event.delta)
      onDelta(event.content || event.delta || "");
    if (event.type === "status" && event.message) onStatus(event.message);
    if (event.type === "done")
      onDone({
        conversationId: event.conversation_id,
        messageId: event.message_id,
        createdAt: event.created_at,
        content: event.assistant_message,
        context: parseAskContext(event.answer_context),
      });
  });
  await accountToken(accountId);
  assertInventory(selected);
}
