/** @jest-environment jsdom */
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { JoinInvitationClient } from "@/components/site/join-invitation-client";
import { joinShare, joinTeam, previewInvitation } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";

const replace = jest.fn(), updateUser = jest.fn(), getSession = jest.fn();
jest.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
jest.mock("@/lib/api", () => ({ joinShare: jest.fn(), joinTeam: jest.fn(), previewInvitation: jest.fn() }));
const auth = { updateUser, getSession };
function session(token: string | null = "test-token") {
  jest.mocked(useApiSession).mockReturnValue({ token, loading: false, supabase: { auth } } as unknown as ReturnType<typeof useApiSession>);
}
beforeEach(() => {
  jest.clearAllMocks(); session();
  getSession.mockResolvedValue({ data: { session: { access_token: "test-token", user: { id: "recipient" } } }, error: null });
  updateUser.mockResolvedValue({ error: null });
  jest.mocked(previewInvitation).mockResolvedValue({ kind: "space", name: "Garage", target_id: "space-123", permission: "view", already_joined: false });
});

test("preserves Space and Team invitations through signup/sign-in without auto-joining", () => {
  session(null);
  const { unmount } = render(<JoinInvitationClient kind="space" code="ABC123" />);
  expect(screen.getByRole("link", { name: "Sign in to join" }).getAttribute("href")).toBe("/signin?redirect=%2Fjoin%2FABC123");
  expect(screen.getByRole("link", { name: "Create account & get the app" }).getAttribute("href")).toBe("/signup?redirect=%2Fjoin%2FABC123%3Fdownload%3D1");
  unmount(); render(<JoinInvitationClient kind="team" code="TEAM23" />);
  expect(screen.getByRole("link", { name: "Sign in to join" }).getAttribute("href")).toBe("/signin?redirect=%2Fjoin%2Fteam%2FTEAM23");
  expect(joinShare).not.toHaveBeenCalled(); expect(joinTeam).not.toHaveBeenCalled();
});

test("loads a read-only preview and joins only after explicit consent", async () => {
  jest.mocked(joinShare).mockResolvedValue({ share_id: "space-123", share_name: "Garage", permission: "view" });
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  await screen.findByRole("heading", { name: "Garage" });
  expect(joinShare).not.toHaveBeenCalled();
  await userEvent.click(screen.getByRole("button", { name: "Join space" }));
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/sharing/space-123"));
});

test("Team acceptance uses the Team endpoint", async () => {
  jest.mocked(joinTeam).mockResolvedValue({ membership: { team_id: "team-123", user_id: "recipient", role: "member" } });
  render(<JoinInvitationClient kind="team" code="TEAM23" />);
  await screen.findByRole("button", { name: "Join team" });
  await userEvent.click(screen.getByRole("button", { name: "Join team" }));
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/teams"));
  expect(joinTeam).toHaveBeenCalledWith({ token: "test-token", code: "TEAM23", bindToToken: true });
});

test("account switch before acceptance prevents the membership request", async () => {
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  await screen.findByRole("button", { name: "Join space" });
  getSession.mockResolvedValue({ data: { session: { access_token: "other-token", user: { id: "other" } } }, error: null });
  await userEvent.click(screen.getByRole("button", { name: "Join space" }));
  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(joinShare).not.toHaveBeenCalled();
  expect(replace).not.toHaveBeenCalled();
});

test("account switch while accepting cannot navigate the next account into the space", async () => {
  jest.mocked(joinShare).mockResolvedValue({ share_id: "space-123", share_name: "Garage", permission: "view" });
  getSession.mockResolvedValueOnce({ data: { session: { access_token: "test-token", user: { id: "recipient" } } }, error: null })
    .mockResolvedValueOnce({ data: { session: { access_token: "other-token", user: { id: "other" } } }, error: null });
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  await screen.findByRole("button", { name: "Join space" });
  await userEvent.click(screen.getByRole("button", { name: "Join space" }));
  await waitFor(() => expect(getSession).toHaveBeenCalledTimes(2));
  expect(joinShare).toHaveBeenCalledWith({ token: "test-token", share_code: "ABC123", bindToToken: true });
  expect(replace).not.toHaveBeenCalled();
});

test("download saves an account handoff, never membership, before leaving", async () => {
  const navigate = jest.fn();
  render(<JoinInvitationClient kind="space" code="ABC123" navigate={navigate} />);
  await screen.findByRole("heading", { name: "Garage" });
  await userEvent.click(screen.getByRole("button", { name: "Save invitation & download" }));
  await waitFor(() => expect(navigate).toHaveBeenCalledWith("https://apps.apple.com/us/app/findez-ai/id6760401697"));
  expect(updateUser).toHaveBeenCalledWith({ data: { findez_pending_invitation: { v: 1, kind: "space", code: "ABC123", created_at: expect.any(Number) } } });
  expect(joinShare).not.toHaveBeenCalled();
});

test("failed account save prevents losing the invitation through download", async () => {
  updateUser.mockResolvedValue({ error: new Error("SECRET db failure") });
  const navigate = jest.fn(); render(<JoinInvitationClient kind="team" code="TEAM23" navigate={navigate} />);
  await screen.findByRole("heading", { name: "Garage" });
  await userEvent.click(screen.getByRole("button", { name: "Save invitation & download" }));
  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(navigate).not.toHaveBeenCalled(); expect(joinTeam).not.toHaveBeenCalled();
});

test("account switch during save cannot continue to download", async () => {
  getSession.mockResolvedValueOnce({ data: { session: { access_token: "test-token", user: { id: "recipient" } } }, error: null }).mockResolvedValueOnce({ data: { session: { access_token: "other-token", user: { id: "other" } } }, error: null });
  const navigate = jest.fn(); render(<JoinInvitationClient kind="space" code="ABC123" navigate={navigate} />);
  await screen.findByRole("heading", { name: "Garage" }); await userEvent.click(screen.getByRole("button", { name: "Save invitation & download" }));
  expect(await screen.findByRole("alert")).toBeTruthy(); expect(navigate).not.toHaveBeenCalled();
});

test("revoked links have no active accept/download action", async () => {
  jest.mocked(previewInvitation).mockRejectedValue(new Error("Unavailable"));
  render(<JoinInvitationClient kind="space" code="ABC123" />);
  await screen.findByRole("alert"); expect(screen.queryByRole("button", { name: "Join space" })).toBeNull();
  expect((screen.getByRole("button", { name: "Save invitation & download" }) as HTMLButtonElement).disabled).toBe(true);
  expect(joinShare).not.toHaveBeenCalled();
});

test("iPhone fallback does not redirect away before saving the invitation", async () => {
  const ua = navigator.userAgent;
  Object.defineProperty(navigator, "userAgent", { value: "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)", configurable: true });
  session(null); const navigate = jest.fn(); render(<JoinInvitationClient kind="space" code="ABC123" navigate={navigate} />);
  expect((await screen.findByRole("link", { name: "Open in FindEZ" })).getAttribute("href")).toBe("findez://space-invite?code=ABC123");
  expect(navigate).not.toHaveBeenCalled();
  Object.defineProperty(navigator, "userAgent", { value: ua, configurable: true });
});

test("invalid link offers no opening or account mutation", async () => {
  render(<JoinInvitationClient kind="space" code="" />);
  expect(await screen.findByRole("alert")).toBeTruthy();
  expect(previewInvitation).not.toHaveBeenCalled(); expect(updateUser).not.toHaveBeenCalled();
});
