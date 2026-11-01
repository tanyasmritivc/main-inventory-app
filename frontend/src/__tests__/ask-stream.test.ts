import { readAskEvents } from "@/lib/ask-stream";
import { parseAskContext, trustedAskPhotoUrl } from "@/lib/ask-answer";

test("Stop cancels a pending body read even when transport does not reject on abort", async () => {
  const cancel = jest.fn();
  const body = new ReadableStream<Uint8Array>({ cancel });
  const control = new AbortController();
  const event = jest.fn();
  const result = readAskEvents(body, event, control.signal);
  control.abort();
  await expect(result).rejects.toMatchObject({name: "AbortError"});
  expect(cancel).toHaveBeenCalledTimes(1);
  expect(event).not.toHaveBeenCalled();
});

test("an already stopped stream cannot deliver a queued completion", async () => {
  const control = new AbortController(); control.abort();
  const event = jest.fn();
  await expect(readAskEvents(stream('data: {"type":"done","assistant_message":"late"}\n\n'), event, control.signal)).rejects.toMatchObject({name:"AbortError"});
  expect(event).not.toHaveBeenCalled();
});
function stream(text: string, chunkSize = 3) {
  const bytes = new TextEncoder().encode(text);
  return new ReadableStream<Uint8Array>({
    start(c) {
      for (let i = 0; i < bytes.length; i += chunkSize)
        c.enqueue(bytes.slice(i, i + chunkSize));
      c.close();
    },
  });
}
test("parses split UTF-8, CRLF, comments, and confirmed answer context", async () => {
  const events: unknown[] = [];
  await readAskEvents(
    stream(
      ': keepalive\r\n\r\ndata: {"type":"delta","content":"π bearing"}\r\n\r\ndata: {"type":"done","conversation_id":"real","answer_context":{"sources":[]}}\r\n\r\ndata: [DONE]\r\n\r\n',
      1,
    ),
    (e) => events.push(e),
  );
  expect(events).toHaveLength(2);
  expect(events[0]).toMatchObject({ content: "π bearing" });
  expect(events[1]).toMatchObject({ conversation_id: "real" });
});
test("accepts a done-only answer at EOF", async () => {
  const handler = jest.fn();
  await readAskEvents(
    stream('data: {"type":"done","assistant_message":"Nothing found"}'),
    handler,
  );
  expect(handler).toHaveBeenCalledWith(
    expect.objectContaining({ assistant_message: "Nothing found" }),
  );
});
test.each([
  'data: {"type":"delta","content":"partial"}\n\n',
  "data: [DONE]\n\n",
  "data: broken\n\n",
])("rejects an unconfirmed or broken stream", async (body) => {
  await expect(readAskEvents(stream(body), () => {})).rejects.toThrow(
    "interrupted",
  );
});
test("surfaces history-save errors even after answer text arrived", async () => {
  await expect(
    readAskEvents(
      stream(
        'data: {"type":"delta","delta":"answer"}\n\ndata: {"type":"error","code":"history_save_failed"}\n\ndata: [DONE]\n\n',
      ),
      () => {},
    ),
  ).rejects.toThrow("could not be completed");
});
test("source cards exclude internal trace and status derives from checked counts", () => {
  const parsed = parseAskContext({
    sources: [
      { kind: "inventory", label: "Inventory", detail: "2 checked" },
      { kind: "chain_of_thought", label: "private" },
    ],
    rows: [
      {
        id: "i",
        name: "Bolt",
        available_quantity: 0,
        required_quantity: 5,
        status: "have",
      },
      { name: "bad", available_quantity: -1 },
    ],
    tool_trace: ["secret"],
  });
  expect(parsed?.sources).toEqual([
    { kind: "inventory", label: "Inventory", detail: "2 checked" },
  ]);
  expect(parsed?.rows).toHaveLength(1);
  expect(parsed?.rows[0].status).toBe("missing");
});
test("saved photo URLs must belong to this account and the configured storage origin", () => {
  const url =
    "https://store.example/storage/v1/object/sign/item-images/owner/ask-" +
    "a".repeat(32) +
    ".jpg?token=signed";
  expect(trustedAskPhotoUrl(url, "owner", ["https://store.example"])).toBe(url);
  expect(
    trustedAskPhotoUrl(url, "other", ["https://store.example"]),
  ).toBeUndefined();
  expect(
    trustedAskPhotoUrl(url.replace("store.example", "evil.example"), "owner", [
      "https://store.example",
    ]),
  ).toBeUndefined();
});

test("unknown counts remain unknown and photo match evidence is allowlisted", () => {
  const context = parseAskContext({ rows: [
    { name: "Drill", available_quantity: null, location: "Garage", match_basis: "possible name match", updated_at: "today" },
    { name: "Bolt", available_quantity: 0, match_basis: "invented visual match" },
  ] });
  expect(context?.rows[0].availableQuantity).toBeNull();
  expect(context?.rows[0].matchBasis).toBe("possible name match");
  expect(context?.rows[1].matchBasis).toBeUndefined();
  expect(JSON.stringify(context)).not.toContain("today");
});

test('late errors and duplicate done cannot replace verified completion',async()=>{
 const received:unknown[]=[];
 await readAskEvents(stream('data: {"type":"done","message_id":"saved","assistant_message":"Answer"}\n\ndata: [DONE]\n\ndata: {"type":"error","error":"late"}\n\n'),event=>received.push(event));
 expect(received).toHaveLength(1);
});
