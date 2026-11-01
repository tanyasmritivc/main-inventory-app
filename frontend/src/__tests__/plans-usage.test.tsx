/** @jest-environment jsdom */
import { act, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { PlansUsageClient } from "@/components/site/plans-usage-client";
import { accountRequest } from "@/lib/account-request";
import { currentAccess, usageCount, usagePeriod } from "@/lib/plan-usage";
import type { LimitsResponse } from "@/lib/api";

let actor: string | null = "usage-a";
jest.mock("@/lib/use-api-session", () => ({ useApiSession: () => ({ accountId: actor, loading: false }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const snapshot = (): LimitsResponse => ({ tier: "free", pilot_mode: true, limits_enabled: false,
  items: {used: 126, max: null}, spaces: {used: 8, max: null},
  chats: {used: 0, max: null, resets_at: "2026-11-01T00:00:00Z"},
  scans: {used: 0, max: null, daily_used: 0, daily_max: null, resets_at: "2026-11-01T00:00:00Z"},
});
beforeEach(() => { actor = "usage-a"; jest.clearAllMocks(); jest.mocked(accountRequest).mockResolvedValue(snapshot()); });
test("pilot uses actual saved counts, never displays bypassed AI counters as zero or a quota", async () => {
  render(<PlansUsageClient/>);
  await screen.findByText("Free early access");
  expect(within(screen.getByRole("region", {name:"Saved item records"})).getByText("126")).toBeTruthy();
  expect(screen.getAllByText("Not metered")).toHaveLength(2);
  expect(screen.queryByRole("progressbar")).toBeNull();
  expect(screen.getByText(/No plan quotas or automatic charges/)).toBeTruthy();
  expect(accountRequest).toHaveBeenCalledWith("usage-a", "/me/limits", {signal:expect.any(AbortSignal)});
  expect(screen.getByText("10 people included")).toBeTruthy();
  await userEvent.click(screen.getByRole("button",{name:"Yearly"}));
  expect(screen.getByText("$99")).toBeTruthy(); expect(screen.getByText("$299")).toBeTruthy();
  expect(screen.queryByRole("link",{name:/checkout|buy/i})).toBeNull();
});
test("current nonpilot allowances are server supplied and legacy access is not renamed Plus", async () => {
  const data = snapshot(); data.pilot_mode=false;data.tier="pro";data.chats={used:12,max:1000,resets_at:"2026-11-01T00:00:00Z"};
  jest.mocked(accountRequest).mockResolvedValue(data);
  render(<PlansUsageClient/>);await screen.findByText("Pro · legacy access");
  const meter=screen.getByRole("progressbar",{name:"AI messages allowance used"});
  expect(meter.getAttribute("max")).toBe("1000");expect(meter.getAttribute("value")).toBe("12");
  expect(within(screen.getByRole("region",{name:"AI messages"})).getByText(/Resets Nov 1 \(UTC\)/)).toBeTruthy();
});
test("failed usage does not invent a Free entitlement or expose raw errors and can retry", async () => {
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error("postgres private error"));
  render(<PlansUsageClient/>);await screen.findByRole("alert");
  expect(screen.queryByText("Free early access")).toBeNull();expect(screen.queryByText(/postgres/)).toBeNull();
  await userEvent.click(screen.getByRole("button",{name:"Try again"}));await screen.findByText("126");
});
test("refresh replaces a stale snapshot and disables duplicate refreshes", async () => {
  render(<PlansUsageClient/>);await screen.findByText("126");
  const newer=snapshot();newer.items.used=127;jest.mocked(accountRequest).mockResolvedValue(newer);
  await userEvent.click(screen.getByRole("button",{name:"Refresh usage"}));await screen.findByText("127");expect(screen.queryByText("126")).toBeNull();
});
test("account switches abort and discard a late response; logout clears private usage", async () => {
  let resolve!:(data:LimitsResponse)=>void;
  jest.mocked(accountRequest).mockImplementationOnce(()=>new Promise(r=>{resolve=r;}));
  const view=render(<PlansUsageClient/>);
  const signal=jest.mocked(accountRequest).mock.calls[0][2]?.signal;
  actor="usage-b";const other=snapshot();other.items.used=22;jest.mocked(accountRequest).mockResolvedValue(other);
  view.rerender(<PlansUsageClient/>);await screen.findByText("22");
  await act(async()=>resolve(snapshot()));expect(screen.queryByText("126")).toBeNull();expect(signal?.aborted).toBe(true);
  actor=null;view.rerender(<PlansUsageClient/>);expect(screen.queryByText("22")).toBeNull();
});
test("malformed response has an explicit error instead of a fake zero", async () => {
  jest.mocked(accountRequest).mockResolvedValue({});render(<PlansUsageClient/>);await screen.findByRole("alert");expect(screen.queryByText("Free early access")).toBeNull();
});
test("unknown counters render unavailable, not NaN, negatives or zero", async () => {
  const data=snapshot();data.items.used=NaN;data.spaces.used=-1;jest.mocked(accountRequest).mockResolvedValue(data);
  render(<PlansUsageClient/>);await screen.findByText("Free early access");expect(screen.getAllByText("Count unavailable")).toHaveLength(2);expect(screen.queryByText("NaN")).toBeNull();
});
test("formatting rejects nonnumeric counters and invalid dates; dates follow server UTC", () => {
  for(const value of [null,undefined,"4",-2,Infinity,1.5]) expect(usageCount(value)).toBeNull();
  expect(usageCount(0)).toBe(0);expect(usagePeriod("bad")).toBeNull();expect(usagePeriod("2026-11-01T00:00:00Z")).toBe("Nov 1");
  expect(currentAccess({...snapshot(),pilot_mode:false,tier:"team_member"})).toBe("Team access");
});
