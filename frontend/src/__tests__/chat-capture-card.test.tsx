/** @jest-environment jsdom */
import { render, screen, fireEvent } from "@testing-library/react";
import { ChatCaptureCard } from "@/components/site/chat-capture-card";
import { accountRequest } from "@/lib/account-request";
import { ApiError } from "@/lib/api";
import type { ChatCapture } from "@/lib/chat-sources";
jest.mock("@/lib/account-request", () => ({ accountRequest: jest.fn() }));
const draft: ChatCapture = {
  id: "11111111-1111-4111-8111-111111111111",
  revision: 1,
  status: "draft",
  inventory_id: "i",
  space_id: "s",
  items: [
    {
      index: 0,
      selected: true,
      item: { name: "Bolt", category: "Parts", quantity: 2 },
    },
  ],
};
beforeEach(() => {
  jest.clearAllMocks();
  jest
    .mocked(accountRequest)
    .mockImplementation(async (_id, path) =>
      path.endsWith("/spaces")
        ? ({
            inventories: [
              {
                inventory_id: "i",
                name: "Tools",
                can_edit: true,
                spaces: [{ id: "s", name: "Shelf" }],
              },
            ],
          } as never)
        : ({
            capture: {
              ...draft,
              status: "saved",
              receipt: { saved_count: 1, review_count: 0, failures: [] },
            },
          } as never),
    );
});
test("draft does not write until explicit save and uses durable capture plus revision", async () => {
  render(
    <ChatCaptureCard
      capture={draft}
      accountId="a"
      worldId="w"
      conversationId="c"
    />,
  );
  await screen.findByRole("option", { name: "Shelf" });
  expect(accountRequest).toHaveBeenCalledTimes(1);
  fireEvent.click(screen.getByRole("button", { name: "Confirm and save" }));
  await screen.findByText(/1 saved/);
  expect(accountRequest).toHaveBeenLastCalledWith(
    "a",
    expect.stringContaining(`/captures/${draft.id}/save`),
    { method: "POST", body: { revision: 1, allow_duplicates: false } },
  );
});
test("duplicate detection requires explicit separate-item consent", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_id, path) => {
    if (path.endsWith("/save"))
      throw new ApiError("Possible matches already exist", 409, {
        code: "capture_duplicates",
      });
    return { inventories: [] } as never;
  });
  render(
    <ChatCaptureCard
      capture={draft}
      accountId="a"
      worldId="w"
      conversationId="c"
    />,
  );
  fireEvent.click(screen.getByRole("button", { name: "Confirm and save" }));
  await screen.findByRole("alert");
  expect(
    screen.getByRole("button", { name: "Confirm and save" }),
  ).toHaveProperty("disabled", true);
  fireEvent.click(screen.getByLabelText(/Save these as separate items/));
  expect(
    screen.getByRole("button", { name: "Confirm and save" }),
  ).toHaveProperty("disabled", false);
});
test("unconfirmed saves require refresh and suppress repeated clicks", async () => {
  jest.mocked(accountRequest).mockImplementation(async (_id, path) => {
    if (path.endsWith("/save"))
      return { capture: { ...draft, status: "saved" } } as never;
    return { inventories: [] } as never;
  });
  render(
    <ChatCaptureCard
      capture={draft}
      accountId="a"
      worldId="w"
      conversationId="c"
    />,
  );
  const save = screen.getByRole("button", { name: "Confirm and save" });
  fireEvent.click(save);
  fireEvent.click(save);
  await screen.findByRole("alert");
  expect(save).toHaveProperty("disabled", true);
  expect(
    jest
      .mocked(accountRequest)
      .mock.calls.filter(([, path]) => path.endsWith("/save")),
  ).toHaveLength(1);
  expect(screen.queryByText(/Saved to/)).toBeNull();
});
