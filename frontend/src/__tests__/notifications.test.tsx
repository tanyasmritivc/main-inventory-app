/** @jest-environment jsdom */
import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ActivityFeedClient } from "@/components/site/activity-feed-client";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { publishNotificationSnapshot, subscribeNotifications } from "@/lib/notification-state";

jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
const entry = { activity_id: "one", team_name: "Workshop", display_text: "Alex added bolts", summary: "Added bolts", activity_type: "Inventory", created_at: "2026-10-11T12:00:00Z", is_read: false };
const inbox = { notifications: [entry], unread_count: 1 };
beforeEach(() => {
  jest.resetAllMocks();
  jest.mocked(useApiSession).mockReturnValue({ accountId: "a", loading: false, error: null } as never);
  jest.mocked(accountRequest).mockResolvedValue(inbox);
});

test("marking read rechecks the server and retains a new unread update arriving during the write", async () => {
  const user = userEvent.setup();
  let read = false;
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => {
    if (path === "/notifications/read") { read = true; return { marked_read: 1 }; }
    return read ? { notifications: [{ ...entry, is_read: true }, { ...entry, activity_id: "new", display_text: "Sam joined", is_read: false }], unread_count: 1 } : inbox;
  });
  render(<ActivityFeedClient mode="notifications" />);
  await user.click(await screen.findByRole("button", { name: "Mark all read" }));
  await screen.findByText("Sam joined");
  expect(screen.getAllByLabelText("Unread")).toHaveLength(1);
  expect(screen.getByRole("button", { name: "Mark all read" })).toBeTruthy();
  expect(accountRequest).toHaveBeenCalledWith("a", "/notifications/read", { method: "POST" });
});
test("a failed read write keeps unread indicators and exposes a retryable error", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => {
    if (path === "/notifications/read") throw new Error("Unavailable");
    return inbox;
  });
  render(<ActivityFeedClient mode="notifications" />);
  await userEvent.click(await screen.findByRole("button", { name: "Mark all read" }));
  await screen.findByRole("alert");
  expect(screen.getByLabelText("Unread")).toBeTruthy();
  expect(screen.getByRole("button", { name: "Mark all read" })).toHaveProperty("disabled", false);
});
test("focus refresh keeps the previous feed visible and never disguises failed reads as an empty inbox", async () => {
  render(<ActivityFeedClient mode="notifications" />);
  await screen.findByText("Alex added bolts");
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("Unavailable"));
  await act(async () => window.dispatchEvent(new Event("focus")));
  await screen.findByRole("alert");
  expect(screen.getByText("Alex added bolts")).toBeTruthy();
  expect(screen.queryByText("No team updates yet")).toBeNull();
});
test("read invalidation in another tab refreshes only its account and fresh data removes unread markers", async () => {
  render(<ActivityFeedClient mode="notifications" />);
  await screen.findByText("Alex added bolts");
  const calls = jest.mocked(accountRequest).mock.calls.length;
  await act(async () => publishNotificationSnapshot("other", null));
  expect(accountRequest).toHaveBeenCalledTimes(calls);
  jest.mocked(accountRequest).mockResolvedValue({ notifications: [{ ...entry, is_read: true }], unread_count: 0 });
  await act(async () => publishNotificationSnapshot("a", null));
  await waitFor(() => expect(screen.queryByLabelText("Unread")).toBeNull());
});
test("an account switch hides the previous inbox before a delayed response resolves", async () => {
  const view = render(<ActivityFeedClient mode="notifications" />);
  await screen.findByText("Alex added bolts");
  jest.mocked(useApiSession).mockReturnValue({ accountId: "b", loading: false, error: null } as never);
  jest.mocked(accountRequest).mockImplementation(() => new Promise(() => {}));
  view.rerender(<ActivityFeedClient mode="notifications" />);
  expect(screen.queryByText("Alex added bolts")).toBeNull();
});
test("malformed response data shows an error instead of inventing zero notifications", async () => {
  jest.mocked(accountRequest).mockResolvedValue({});
  render(<ActivityFeedClient mode="notifications" />);
  await screen.findByRole("alert");
  expect(screen.queryByText("No team updates yet")).toBeNull();
});
test("browser broadcast does not invalidate the same document a second time", () => {
  const original = global.BroadcastChannel;
  const channels: MockChannel[] = [];
  class MockChannel {
    onmessage: ((event: { data: unknown }) => void) | null = null;
    constructor() { channels.push(this); }
    close() { channels.splice(channels.indexOf(this), 1); }
    postMessage(data: unknown) {
      for (const receiver of channels) if (receiver !== this) receiver.onmessage?.({ data });
    }
  }
  global.BroadcastChannel = MockChannel as never;
  const listener = jest.fn();
  const unsubscribe = subscribeNotifications(listener);
  try {
    publishNotificationSnapshot("a", null);
    expect(listener).toHaveBeenCalledTimes(1);
  } finally {
    unsubscribe();
    global.BroadcastChannel = original;
  }
});
