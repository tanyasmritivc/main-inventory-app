/** @jest-environment jsdom */
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { completeGmail, gmailRedirect } from "@/lib/gmail";
import { accountRequest } from "@/lib/account-request";
import { getAccessSession } from "@/lib/session";
import { PurchaseEmailClient } from "@/components/site/purchase-email-client";

jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/session", () => ({ getAccessSession: jest.fn() }));
const confirm = jest.fn();
jest.mock("@/components/site/app-dialog-provider", () => ({ useAppDialog: () => ({ confirmAction: confirm }) }));
jest.mock("@/components/site/commerce-client.module.css", () => ({}));
const inventory = "10000000-0000-0000-0000-000000000001", cid = "20000000-0000-0000-0000-000000000001";
const origin = "https://www.example.test";
const result = { connection_id: cid, expires_in: 600, authorization_url: "https://accounts.google.com/o/oauth2/v2/auth?" + new URLSearchParams({
  state: "state", redirect_uri: origin + "/connect/gmail/callback", scope: "https://www.googleapis.com/auth/gmail.readonly",
}) };
beforeEach(() => { jest.clearAllMocks(); sessionStorage.clear(); confirm.mockResolvedValue(true); });

test("Gmail redirect accepts only Google read-only authorization and same-origin return", () => {
  expect(gmailRedirect(result, "actor", inventory, origin, sessionStorage)).toContain("accounts.google.com");
  for (const authorization_url of [result.authorization_url.replace("accounts.google.com", "evil.test"), result.authorization_url.replace("gmail.readonly", "gmail.modify"), result.authorization_url + "&state=duplicate"]) {
    expect(() => gmailRedirect({ ...result, authorization_url }, "actor", inventory, origin, sessionStorage)).toThrow();
  }
  expect(() => gmailRedirect(result, "actor", inventory, "https://another.test", sessionStorage)).toThrow();
});

test("callback removes sensitive query before async work and binds the initiating account", async () => {
  gmailRedirect(result, "actor", inventory, origin, sessionStorage);
  const replaceState = jest.fn();
  const browser = { location: { search: "?code=secret&state=state", pathname: "/connect/gmail/callback" }, history: { replaceState }, sessionStorage };
  jest.mocked(getAccessSession).mockImplementation(async () => {
    expect(replaceState).toHaveBeenCalledWith(null, "", "/connect/gmail/callback");
    return { accountId: "other" } as Awaited<ReturnType<typeof getAccessSession>>;
  });
  await expect(completeGmail(browser as unknown as Window)).rejects.toThrow("account that started");
  expect(accountRequest).not.toHaveBeenCalled();
});

test("callback consumes handoff once and rejects duplicate code keys", async () => {
  gmailRedirect(result, "actor", inventory, origin, sessionStorage);
  const browser = { location: { search: "?code=secret&state=state", pathname: "/connect/gmail/callback" }, history: { replaceState: jest.fn() }, sessionStorage };
  jest.mocked(getAccessSession).mockResolvedValue({ accountId: "actor" } as Awaited<ReturnType<typeof getAccessSession>>);
  jest.mocked(accountRequest).mockResolvedValue({ connected: true });
  expect(await completeGmail(browser as unknown as Window)).toContain(inventory);
  await expect(completeGmail(browser as unknown as Window)).rejects.toThrow();
  expect(accountRequest).toHaveBeenCalledTimes(1);
  browser.location.search += "&code=second";
  await expect(completeGmail(browser as unknown as Window)).rejects.toThrow();
});

test("purchase UI distinguishes unknown amounts and physical ownership and purges only after confirmation", async () => {
  const data = { account: { status: "connected", email: "test@example.test", last_sync_at: null, last_error: null }, has_more: false,
    messages: [], purchases: [{ title: "Motor", order_id: "123", asin: null, ordered_quantity: null, statuses: ["delivered"],
      observations: [{ status: "delivered", quantity: null, evidence_quote: "Your motor arrived" }] }] };
  const request = jest.fn().mockResolvedValue(data);
  render(<PurchaseEmailClient accountId="actor" inventoryId={inventory} configured available request={request} />);
  await screen.findByText("Motor");
  expect(screen.getByText("Needs review")).toBeTruthy();
  expect(screen.getByText("Not verified in inventory")).toBeTruthy();
  confirm.mockResolvedValueOnce(false);
  fireEvent.click(screen.getByRole("button", { name: "Delete Gmail purchase records" }));
  await waitFor(() => expect(confirm).toHaveBeenCalled());
  expect(request.mock.calls.some((args) => args[1]?.method === "DELETE")).toBe(false);
});

test("disabled Gmail setup does not offer a pretend working connection", () => {
  render(<PurchaseEmailClient accountId="actor" inventoryId={inventory} configured={false} available={false} request={jest.fn()} />);
  expect(screen.getByRole("button", { name: "Connect Gmail" }).hasAttribute("disabled")).toBe(true);
  expect(screen.getByText(/Google grants read-only mailbox access/)).toBeTruthy();
});
