import { apiBase, ApiError } from "@/lib/api";
import { accountToken } from "@/lib/account-request";
import { parseAskContext, type AskAnswerContext } from "@/lib/ask-answer";

export type AskStreamEvent = {
  type?: string;
  content?: string;
  delta?: string;
  assistant_message?: string;
  conversation_id?: string;
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
    if (!data || data === "[DONE]") return;
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
      if (done) break;
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
  signal,
  onDelta,
  onStatus,
  onDone,
}: {
  accountId: string;
  message: string;
  photo?: File;
  conversationId?: string | null;
  signal: AbortSignal;
  onDelta: (text: string) => void;
  onStatus: (text: string) => void;
  onDone: (result: {
    conversationId?: string;
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
  const token = await accountToken(accountId);
  const form = new FormData();
  if (photo) {
    form.append("file", photo);
    form.append("message", message);
    if (conversationId) form.append("conversation_id", conversationId);
  }
  const response = await fetch(
    `${apiBase()}${photo ? "/ai_photo_question" : "/ai_command?stream=true"}`,
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
        : JSON.stringify({ message, conversation_id: conversationId || null }),
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
    if (event.content || event.delta)
      onDelta(event.content || event.delta || "");
    if (event.type === "status" && event.message) onStatus(event.message);
    if (event.type === "done")
      onDone({
        conversationId: event.conversation_id,
        content: event.assistant_message,
        context: parseAskContext(event.answer_context),
      });
  });
  await accountToken(accountId);
}
