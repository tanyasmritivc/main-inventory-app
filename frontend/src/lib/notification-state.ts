export type NotificationSnapshot = { accountId: string; unread: number | null };
const eventName = "findez-notifications-changed";
const channelName = "findez-notifications";
const sourceId = Math.random().toString(36).slice(2);

function snapshot(value: unknown): NotificationSnapshot | null {
  if (!value || typeof value !== "object") return null;
  const data = value as Record<string, unknown>;
  if (typeof data.accountId !== "string" || !data.accountId) return null;
  if (data.unread !== null && (!Number.isSafeInteger(data.unread) || Number(data.unread) < 0)) return null;
  return { accountId: data.accountId, unread: data.unread as number | null };
}

export function publishNotificationSnapshot(accountId: string, unread: number | null) {
  const value = snapshot({ accountId, unread });
  if (!value) return;
  window.dispatchEvent(new CustomEvent(eventName, { detail: value }));
  // Other tabs re-read rather than accepting a potentially older count.
  if (unread === null && typeof BroadcastChannel !== "undefined") {
    try {
      const channel = new BroadcastChannel(channelName);
      channel.postMessage({ ...value, sourceId });
      channel.close();
    } catch { /* Same-tab updates still work when browser storage is restricted. */ }
  }
}

export function subscribeNotifications(listener: (value: NotificationSnapshot) => void) {
  const receive = (value: unknown) => {
    const valid = snapshot(value);
    if (valid) listener(valid);
  };
  const onEvent = (event: Event) => receive((event as CustomEvent).detail);
  window.addEventListener(eventName, onEvent);
  let channel: BroadcastChannel | null = null;
  try { if (typeof BroadcastChannel !== "undefined") channel = new BroadcastChannel(channelName); } catch { /* Use the same-tab event. */ }
  if (channel) channel.onmessage = (event) => {
    if (event.data?.sourceId !== sourceId) receive(event.data);
  };
  return () => {
    window.removeEventListener(eventName, onEvent);
    channel?.close();
  };
}
