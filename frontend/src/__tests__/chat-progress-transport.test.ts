import { askQuestion } from '@/lib/ask-stream';
jest.mock('@/lib/account-request', () => ({ accountToken: async () => 'synthetic-token' }));
jest.mock('@/lib/api', () => ({ apiBase: () => 'https://api.example.invalid', ApiError: class extends Error {} }));

test('actual status/model/delta updates notify liveness without creating answer text; late events are ignored', async () => {
  const body = new ReadableStream<Uint8Array>({ start(c) {
    for (const event of [
      {type:'status',message:'Thinking...'},
      {type:'activity',source:'model'},
      {type:'activity',source:'unknown'},
      {type:'delta',delta:'Hello'},
      {type:'done',assistant_message:'Hello',conversation_id:'test'},
      {type:'activity',source:'model'},
    ]) c.enqueue(new TextEncoder().encode(`data: ${JSON.stringify(event)}\n\n`));
    c.close();
  } });
  const fetchMock = jest.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(body));
  const onActivity=jest.fn(),onDelta=jest.fn(),onStatus=jest.fn(),onDone=jest.fn();
  try {
    await askQuestion({accountId:'test',worldId:'personal',message:'Hi',signal:new AbortController().signal,onActivity,onDelta,onStatus,onDone});
    expect(onActivity).toHaveBeenCalledTimes(3);
    expect(onDelta).toHaveBeenCalledTimes(1);
    expect(onDelta).toHaveBeenCalledWith('Hello');
    expect(onStatus).toHaveBeenCalledWith('Thinking...');
    expect(onDone).toHaveBeenCalledTimes(1);
  } finally { fetchMock.mockRestore(); }
});
