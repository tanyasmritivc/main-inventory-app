/** @jest-environment jsdom */
import { act, renderHook, waitFor } from "@testing-library/react";
import { useUpgradePermission } from "@/lib/use-upgrade-permission";
import { accountRequest } from "@/lib/account-request";
import { getAccessSession } from "@/lib/session";
import { isPilotPublic } from "@/lib/pilot";

let authChanged: () => void;
const unsubscribe = jest.fn();
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/session", () => ({ getAccessSession: jest.fn() }));
jest.mock("@/lib/pilot", () => ({ isPilotPublic: jest.fn() }));
jest.mock("@/lib/supabase/browser", () => ({ createSupabaseBrowserClient: () => ({ auth: {
  onAuthStateChange: (callback: () => void) => { authChanged = callback; return { data: { subscription: { unsubscribe } } }; },
} }) }));

beforeEach(() => {
  jest.clearAllMocks();
  jest.mocked(isPilotPublic).mockReturnValue(false);
  jest.mocked(getAccessSession).mockResolvedValue({ accountId: "tester", token: "synthetic" });
});

test.each([true, false])("pre-launch hides prompts despite stale client errors (public flag %s)", async publicPilot => {
  jest.mocked(isPilotPublic).mockReturnValue(publicPilot);
  jest.mocked(accountRequest).mockResolvedValue({ pilot_mode: true, limits_enabled: false, pilot_ends_at: "2000-01-01" });
  const { result } = renderHook(() => useUpgradePermission(true));
  await act(async () => {});
  expect(result.current).toBe(false);
  if (publicPilot) expect(accountRequest).not.toHaveBeenCalled();
});

test.each([{}, { pilot_mode: false }, { pilot_mode: true, limits_enabled: true }])("unknown or inconsistent status does not authorize a prompt: %p", async status => {
  jest.mocked(accountRequest).mockResolvedValue(status);
  const { result } = renderHook(() => useUpgradePermission(true));
  await act(async () => {});
  expect(result.current).toBe(false);
});

test("only a fresh explicit non-pilot response permits a prompt; closing revokes it", async () => {
  jest.mocked(accountRequest).mockResolvedValue({ pilot_mode: false, limits_enabled: true });
  const { result, rerender } = renderHook(({ open }) => useUpgradePermission(open), { initialProps: { open: true } });
  await waitFor(() => expect(result.current).toBe(true));
  rerender({ open: false });
  expect(result.current).toBe(false);
  expect(unsubscribe).toHaveBeenCalled();
});

test("offline status never opens a prompt", async () => {
  jest.mocked(accountRequest).mockRejectedValue(new Error("offline"));
  const { result } = renderHook(() => useUpgradePermission(true));
  await act(async () => {});
  expect(result.current).toBe(false);
});

test("account change discards a late quota response", async () => {
  let finish!: (status: unknown) => void;
  jest.mocked(accountRequest).mockImplementationOnce(() => new Promise(resolve => { finish = resolve; }));
  const { result } = renderHook(() => useUpgradePermission(true));
  await waitFor(() => expect(accountRequest).toHaveBeenCalled());
  jest.mocked(getAccessSession).mockResolvedValue(null);
  await act(async () => { authChanged(); });
  await act(async () => { finish({ pilot_mode: false, limits_enabled: true }); });
  expect(result.current).toBe(false);
});
