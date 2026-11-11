// All homepage animation clients, including CAD, share one browser frame request.
const callbacks = new Map<number, FrameRequestCallback>();
let nextId = 0;
let frame = 0;
function flush(time: number) {
  frame = 0;
  const pending = [...callbacks.entries()];
  callbacks.clear();
  pending.forEach(([, callback]) => callback(time));
}
export function requestHomeFrame(callback: FrameRequestCallback) {
  const id = ++nextId;
  callbacks.set(id, callback);
  if (!frame) frame = window.requestAnimationFrame(flush);
  return id;
}
export function cancelHomeFrame(id: number) {
  callbacks.delete(id);
  if (!callbacks.size && frame) { window.cancelAnimationFrame(frame); frame = 0; }
}
