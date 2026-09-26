/** @jest-environment jsdom */

import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";
import { joinShare, joinTeam } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

const replace = jest.fn();

jest.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
jest.mock("@/lib/api", () => ({
  ApiError: class ApiError extends Error {},
  joinShare: jest.fn(),
  joinTeam: jest.fn(),
  getJoinedShares: jest.fn(),
  getMyShares: jest.fn(),
}));

beforeEach(() => {
  jest.clearAllMocks();
});

test("keeps a Space invitation through sign-in", () => {
  jest.mocked(useApiSession).mockReturnValue({ token: null, loading: false } as ReturnType<typeof useApiSession>);
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  expect(screen.getByRole("link", { name: "Sign in to join" }).getAttribute("href"))
    .toBe("/signin?redirect=%2Fjoin%2FABC123");
});

test("accepts a Space link in the browser and opens the joined Space", async () => {
  jest.mocked(useApiSession).mockReturnValue({ token: "test-token", loading: false } as ReturnType<typeof useApiSession>);
  jest.mocked(joinShare).mockResolvedValue({ share_id: "space-123", share_name: "Parts", permission: "view" });
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  await userEvent.click(screen.getByRole("button", { name: "Join space" }));
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/sharing/space-123"));
  expect(joinShare).toHaveBeenCalledWith({ token: "test-token", share_code: "ABC123" });
});

test("accepts a Team link without sending the user to the App Store", async () => {
  jest.mocked(useApiSession).mockReturnValue({ token: "test-token", loading: false } as ReturnType<typeof useApiSession>);
  jest.mocked(joinTeam).mockResolvedValue({ membership: { team_id: "team-123", user_id: "user-123", role: "member" } });
  render(<JoinInvitationClient kind="team" code="TEAM12" />);
  await userEvent.click(screen.getByRole("button", { name: "Join team" }));
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/teams"));
  expect(joinTeam).toHaveBeenCalledWith({ token: "test-token", code: "TEAM12" });
});

describe("iOS App Store fallback", () => {
  const originalUserAgent = navigator.userAgent;
  const setUserAgent = (value: string) =>
    Object.defineProperty(window.navigator, "userAgent", { value, configurable: true });
  const iPhone = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1";
  const appStore = "https://apps.apple.com/us/app/findez-ai/id6760401697";

  beforeEach(() => {
    window.localStorage.clear();
    jest.mocked(useApiSession).mockReturnValue({ token: null, loading: false } as ReturnType<typeof useApiSession>);
  });
  afterEach(() => setUserAgent(originalUserAgent));

  test("sends an iPhone without the app to the App Store once per invitation", async () => {
    setUserAgent(iPhone);
    const navigate = jest.fn();
    const { unmount } = render(<JoinInvitationClient kind="space" code="ABC123" navigate={navigate} />);
    await waitFor(() => expect(navigate).toHaveBeenCalledWith(appStore));
    expect(screen.getByRole("link", { name: "Get FindEZ on the App Store" }).getAttribute("href")).toBe(appStore);
    expect(screen.getByRole("link", { name: "Already have FindEZ? Open in app" }).getAttribute("href"))
      .toBe("findez://space-invite?code=ABC123");
    expect(screen.getByRole("link", { name: "Sign in to join" })).toBeTruthy();
    unmount();

    const second = jest.fn();
    render(<JoinInvitationClient kind="space" code="ABC123" navigate={second} />);
    await screen.findByRole("link", { name: "Get FindEZ on the App Store" });
    expect(second).not.toHaveBeenCalled();
  });

  test("uses the Team custom-scheme fallback on iOS", async () => {
    setUserAgent(iPhone);
    render(<JoinInvitationClient kind="team" code="TEAM12" navigate={jest.fn()} />);
    expect((await screen.findByRole("link", { name: "Already have FindEZ? Open in app" })).getAttribute("href"))
      .toBe("findez://team-invite?code=TEAM12");
  });

  test("never redirects an invalid invitation", async () => {
    setUserAgent(iPhone);
    const navigate = jest.fn();
    render(<JoinInvitationClient kind="space" code="" navigate={navigate} />);
    expect(await screen.findByRole("alert")).toBeTruthy();
    expect(navigate).not.toHaveBeenCalled();
  });

  test("keeps the desktop browser flow without an App Store redirect", async () => {
    setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36");
    const navigate = jest.fn();
    render(<JoinInvitationClient kind="space" code="ABC123" navigate={navigate} />);
    expect(screen.getByRole("link", { name: "Sign in to join" })).toBeTruthy();
    expect(screen.queryByRole("link", { name: "Get FindEZ on the App Store" })).toBeNull();
    expect(navigate).not.toHaveBeenCalled();
  });
});
