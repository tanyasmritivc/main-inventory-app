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
