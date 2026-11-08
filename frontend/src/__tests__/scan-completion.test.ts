import { File as NodeFile } from 'node:buffer';
import { askQuestion, readAskEvents, SCAN_IDLE_TIMEOUT_MS, SCAN_TIMEOUT_MS } from '@/lib/ask-stream';
jest.mock('@/lib/account-request', () => ({ accountToken: async () => 'fixture-session' }));
jest.mock('@/lib/inventory-selection', () => ({ activeInventory: () => undefined, assertInventory: () => {}, inventoryApiPath: (p: string) => p }));

const encode = (event: object) => new TextEncoder().encode(`data: ${JSON.stringify(event)}\n\n`);
const done = { type: 'done', conversation_id: 'fixture-chat', answer_context: { chat_capture: {
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', revision: 1, status: 'draft',
  items: [{ index: 0, selected: true, item: { name: 'Cable', category: 'Other', quantity: 1 } }],
} } };
const originalFetch = global.fetch;
let controller: ReadableStreamDefaultController<Uint8Array>;
let cancel: jest.Mock;
beforeEach(() => {
  jest.useFakeTimers();
  cancel = jest.fn();
  global.fetch = jest.fn(async () => ({ ok: true, body: new ReadableStream<Uint8Array>({
    start(c) { controller = c; }, cancel,
  }) })) as jest.Mock;
});
afterEach(() => { jest.useRealTimers(); global.fetch = originalFetch; });
function start() {
  const abort = new AbortController(), onDone = jest.fn(), onCapture = jest.fn();
  const promise = askQuestion({ accountId: 'fixture', worldId: 'personal', requestId: 'fixture-request',
    message: 'Extract', photo: new NodeFile(['image'], 'parts.jpg', { type: 'image/jpeg' }) as unknown as File,
    autoExtract: true, signal: abort.signal, onDelta: jest.fn(), onStatus: jest.fn(), onDone, onCapture });
  return { promise, abort, onDone, onCapture };
}

test('a healthy crowded scan survives three minutes and ends on its durable draft without waiting for EOF', async () => {
  const run = start();
  await jest.advanceTimersByTimeAsync(0);
  for (let second = 0; second < 240; second += 10) {
    controller.enqueue(new TextEncoder().encode(': scan keepalive\n\n'));
    await jest.advanceTimersByTimeAsync(10_000);
  }
  expect(run.onDone).not.toHaveBeenCalled();
  controller.enqueue(encode({ ...done, type: 'capture' }));
  controller.enqueue(encode(done));
  await run.promise;
  expect(run.onDone).toHaveBeenCalledTimes(1);
  expect(run.onCapture).toHaveBeenCalledTimes(1);
  expect(run.onDone.mock.calls[0][0].context.capture.items).toHaveLength(1);
  expect(cancel).toHaveBeenCalledTimes(1);
  expect(global.fetch).toHaveBeenCalledTimes(1);
  expect(jest.getTimerCount()).toBe(0);
});

test('a silent scan connection fails visibly without posting another scan', async () => {
  const run = start();
  const assertion = expect(run.promise).rejects.toThrow('stopped responding');
  await jest.advanceTimersByTimeAsync(SCAN_IDLE_TIMEOUT_MS + 1);
  await assertion;
  expect(run.onDone).not.toHaveBeenCalled();
  expect(cancel).toHaveBeenCalledTimes(1);
  expect(global.fetch).toHaveBeenCalledTimes(1);
  expect(jest.getTimerCount()).toBe(0);
});

test('endless keepalives cannot leave a scan loading forever', async () => {
  const run = start();
  const assertion = expect(run.promise).rejects.toThrow('took too long');
  await jest.advanceTimersByTimeAsync(0);
  for (let elapsed = 0; elapsed < SCAN_TIMEOUT_MS; elapsed += 10_000) {
    controller.enqueue(new TextEncoder().encode(': scan keepalive\n\n'));
    await jest.advanceTimersByTimeAsync(10_000);
  }
  await assertion;
  expect(run.onDone).not.toHaveBeenCalled();
  expect(global.fetch).toHaveBeenCalledTimes(1);
  expect(jest.getTimerCount()).toBe(0);
});

test('Stop cancels the pending read and removes every scan timer', async () => {
  const run = start();
  const assertion = expect(run.promise).rejects.toMatchObject({ name: 'AbortError' });
  await jest.advanceTimersByTimeAsync(0);
  run.abort.abort();
  await assertion;
  expect(run.onDone).not.toHaveBeenCalled();
  expect(global.fetch).toHaveBeenCalledTimes(1);
  expect(jest.getTimerCount()).toBe(0);
});

test.each(['early EOF', 'server error', 'broken JSON'])(
  '%s cannot become an empty successful draft', async kind => {
    const run = start();
    const assertion = expect(run.promise).rejects.toThrow();
    await jest.advanceTimersByTimeAsync(0);
    if (kind === 'server error') controller.enqueue(encode({ type: 'error', code: 'photo_timeout' }));
    else if (kind === 'broken JSON') controller.enqueue(new TextEncoder().encode('data: broken\n\n'));
    controller.close();
    await assertion;
    expect(run.onDone).not.toHaveBeenCalled();
    expect(global.fetch).toHaveBeenCalledTimes(1);
    expect(jest.getTimerCount()).toBe(0);
  },
);

test('ordinary chat has no scan-specific timeout or preview flag', async () => {
  const abort = new AbortController();
  const run = askQuestion({ accountId: 'fixture', worldId: 'personal', message: 'Where is my drill?',
    signal: abort.signal, onDelta: jest.fn(), onStatus: jest.fn(), onDone: jest.fn() });
  await jest.advanceTimersByTimeAsync(SCAN_TIMEOUT_MS + 1);
  expect(jest.getTimerCount()).toBe(0);
  expect(JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body)).not.toHaveProperty('preview_only');
  controller.enqueue(encode({ type: 'done', conversation_id: 'chat', assistant_message: 'Garage' }));
  await run;
});

test('fragmented UTF-8 and CRLF preserve scan completion', async () => {
  const bytes = new TextEncoder().encode(`: ping\r\n\r\ndata: ${JSON.stringify({ type: 'status', message: 'Checking 🔧' })}\r\n\r\ndata: ${JSON.stringify(done)}\r\n\r\n`);
  const events: unknown[] = [];
  await readAskEvents(new ReadableStream({ start(c) { for (const byte of bytes) c.enqueue(Uint8Array.of(byte)); c.close(); } }), e => events.push(e), undefined, SCAN_IDLE_TIMEOUT_MS);
  expect(events).toEqual([{ type: 'status', message: 'Checking 🔧' }, done]);
  expect(jest.getTimerCount()).toBe(0);
});
