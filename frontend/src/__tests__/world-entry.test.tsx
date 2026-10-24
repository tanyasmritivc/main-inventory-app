/** @jest-environment jsdom */
import { render, screen, waitFor } from "@testing-library/react";
import { WorldEntry } from "@/components/site/world-entry";
import { chooseWorld, worldPreferenceKey } from "@/lib/world-entry";
import { accountRequest } from "@/lib/account-request";
const replace = jest.fn();
let actor = "a";
jest.mock("next/navigation", () => ({ useRouter: () => ({ replace }) }));
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
jest.mock("@/lib/use-api-session", () => ({
  useApiSession: () => ({ accountId: actor }),
}));
beforeEach(() => {
  actor = "a";
  jest.clearAllMocks();
  localStorage.clear();
});
test("last world is retained only if still authorized; ambiguous first entry uses Personal", () => {
  const organizations = [
    { organization_id: "one" },
    { organization_id: "two" },
  ];
  expect(chooseWorld(organizations, "two")).toBe("two");
  expect(chooseWorld(organizations, "revoked")).toBe("personal");
  expect(chooseWorld(organizations, null)).toBe("personal");
  expect(chooseWorld(organizations.slice(0, 1), null)).toBe("one");
  expect(chooseWorld(organizations.slice(0, 1), "personal")).toBe("personal");
  expect(chooseWorld([], null)).toBe("personal");
});
test("entry validates membership and preserves prompt without showing directory", async () => {
  localStorage.setItem(worldPreferenceKey("a"), "two");
  jest
    .mocked(accountRequest)
    .mockResolvedValue({
      organizations: [{ organization_id: "one" }, { organization_id: "two" }],
    });
  render(<WorldEntry query="Find my drill" />);
  await waitFor(() =>
    expect(replace).toHaveBeenCalledWith("/worlds/two?q=Find+my+drill"),
  );
  expect(screen.queryByText("Organizations")).toBeNull();
});
test("failed membership request stays retryable rather than using cached access", async () => {
  localStorage.setItem(worldPreferenceKey("a"), "one");
  jest.mocked(accountRequest).mockRejectedValue(new Error("Offline"));
  render(<WorldEntry />);
  await screen.findByRole("alert");
  expect(replace).not.toHaveBeenCalled();
  expect(screen.getByRole("button", { name: "Try again" })).toBeTruthy();
});
test("account change ignores the previous account response", async () => {
  let resolve!: (x: unknown) => void;
  jest
    .mocked(accountRequest)
    .mockImplementationOnce(
      () =>
        new Promise((r) => {
          resolve = r;
        }) as never,
    )
    .mockResolvedValue({ organizations: [] });
  const view = render(<WorldEntry />);
  actor = "b";
  view.rerender(<WorldEntry />);
  await waitFor(() => expect(replace).toHaveBeenCalledWith("/worlds/personal"));
  resolve({ organizations: [{ organization_id: "private-a" }] });
  await Promise.resolve();
  expect(replace).not.toHaveBeenCalledWith("/worlds/private-a");
});
