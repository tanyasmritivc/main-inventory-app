/** @jest-environment jsdom */
import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { CollectionsClient } from "@/components/site/collections-client";
import { RestockClient } from "@/components/site/restock-client";
import { AssistClient } from "@/components/site/assist-client";
import { HomeOverview } from "@/components/site/home-overview";
import { DocumentsClient } from "@/components/site/documents-client";
import { ItemPhotoGallery } from "@/components/site/item-photo-gallery";
import { accountRequest } from "@/lib/account-request";
import { askQuestion } from "@/lib/ask-stream";
import { useApiSession } from "@/lib/use-api-session";
import { restockKey } from "@/lib/restock-plan";
import type { InventoryItem } from "@/lib/api";
import { selectInventory } from "@/lib/inventory-selection";
jest.mock("@/lib/account-request", () => ({
  accountRequest: jest.fn(),
  accountToken: jest.fn(async () => "token-a"),
}));
jest.mock("@/lib/ask-stream", () => ({ askQuestion: jest.fn() }));

test("Stop aborts once, restores the draft and never submits it again", async () => {
  jest.mocked(askQuestion).mockImplementation(options => new Promise((_resolve, reject) => {
    options.signal.addEventListener("abort", () => reject(new DOMException("Stopped", "AbortError")), {once:true});
  }));
  render(<AssistClient />);
  const input = await screen.findByPlaceholderText("Ask about your inventory…");
  fireEvent.change(input, {target:{value:"Save my repair kit"}});
  await userEvent.click(screen.getByRole("button", {name:"Ask"}));
  await userEvent.click(await screen.findByRole("button", {name:"Stop"}));
  await screen.findByRole("button", {name:"Ask"});
  expect(askQuestion).toHaveBeenCalledTimes(1);
  expect(jest.mocked(askQuestion).mock.calls[0][0].signal.aborted).toBe(true);
  expect(input).toHaveProperty("value", "Save my repair kit");
});
jest.mock("@/lib/use-api-session", () => ({ useApiSession: jest.fn() }));
jest.mock("next/navigation", () => ({ useRouter: () => ({ push: jest.fn() }) }));
jest.mock("@/components/site/app-dialog-provider", () => ({
  useAppDialog: () => ({
    confirmAction: async () => true,
    promptValue: async () => null,
  }),
}));
const item: InventoryItem = {
  item_id: "i",
  name: "Bolt",
  category: "Hardware",
  quantity: 1,
  location: "Garage",
  created_at: "2026-10-05T12:00:00Z",
};
const doc = {
  storage_path: "a/docs/note-one.txt",
  filename: "note-one.txt",
  mime_type: "text/plain",
  created_at: "2026-10-05T12:00:00Z",
};
beforeEach(() => {
  jest.clearAllMocks();
  localStorage.clear();
  selectInventory(null);
  process.env.NEXT_PUBLIC_SUPABASE_URL = "https://store.example";
  process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example";
  jest.mocked(useApiSession).mockReturnValue({
    accountId: "a",
    token: "token-a",
    loading: false,
    error: null,
  } as never);
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => {
    if (path === "/search_items") return { items: [item] };
    if (path === "/sharing/joined") return { shares: [] };
    if (path === "/teams") return { teams: [] };
    if (path.startsWith("/documents?")) return { documents: [doc] };
    if (path === "/spaces") return [{ id: "s", name: "Garage" }];
    if (path.startsWith("/documents/open?"))
      return {
        url: "https://store.example/storage/v1/object/sign/documents/a/docs/note-one.txt?token=x",
      };
    if (path === "/conversations")
      return [{ id: "wrong-latest", title: "Other chat" }];
    if (path.endsWith("/photos"))
      return {
        photos: [
          {
            photo_id: "primary",
            image_url: "https://store.example/photo.jpg",
            is_primary: true,
          },
        ],
      };
    throw new Error("Unexpected path " + path);
  });
  global.fetch = jest.fn(async () => ({
    ok: true,
    headers: { get: () => null },
    text: async () => "Keep the fixings in drawer one.",
  })) as never;
});

test("ordering leaves stock untouched, arrival confirms the actual total, and minimum survives", async () => {
  localStorage.setItem(restockKey("a"), JSON.stringify({ i: { minimum: 1 } }));
  const user = userEvent.setup();
  render(<RestockClient />);
  await screen.findByRole("link", { name: "Bolt" });
  await user.click(screen.getByRole("button", { name: "Mark ordered" }));
  await waitFor(() =>
    expect(JSON.parse(localStorage.getItem(restockKey("a"))!).i.ordered).toBe(
      true,
    ),
  );
  expect(
    jest
      .mocked(accountRequest)
      .mock.calls.some(([, p, o]) => o?.method === "PATCH"),
  ).toBe(false);
  await user.click(screen.getByRole("button", { name: /On order 1/ }));
  await user.click(screen.getByRole("button", { name: "Record arrival" }));
  const dialog = screen.getByRole("dialog");
  fireEvent.change(within(dialog).getByLabelText("Actual total now in stock"), {
    target: { value: "8" },
  });
  jest
    .mocked(accountRequest)
    .mockImplementationOnce(async () => ({ item: { ...item, quantity: 8 } }));
  await user.click(within(dialog).getByRole("button", { name: "Confirm" }));
  await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());
  expect(jest.mocked(accountRequest).mock.calls).toContainEqual([
    "a",
    "/update_item",
    { method: "PATCH", body: { item_id: "i", quantity: 8 } },
  ]);
  expect(JSON.parse(localStorage.getItem(restockKey("a"))!).i).toEqual({
    minimum: 1,
  });
});
test("no threshold means no automatic purchase suggestion for a quantity of one", async () => {
  render(<RestockClient />);
  await screen.findByText("Your purchase list is clear");
  expect(screen.queryByRole("link", { name: "Bolt" })).toBeNull();
});
test("account changes remove old purchase and inventory content before the next request resolves", async () => {
  localStorage.setItem(
    restockKey("a"),
    JSON.stringify({ i: { buy_quantity: 2 } }),
  );
  const view = render(<RestockClient />);
  await screen.findByRole("link", { name: "Bolt" });
  jest.mocked(useApiSession).mockReturnValue({
    accountId: "b",
    token: "token-b",
    loading: false,
    error: null,
  } as never);
  jest.mocked(accountRequest).mockImplementation(() => new Promise(() => {}));
  view.rerender(<RestockClient />);
  expect(screen.queryByRole("link", { name: "Bolt" })).toBeNull();
  expect(screen.queryByText("Buy 2")).toBeNull();
});
test("a confirmed Ask conversation ID is used instead of the newest history entry", async () => {
  const user = userEvent.setup();
  jest.mocked(askQuestion).mockImplementation(async (options) => {
    options.onDelta("You have one bolt.");
    options.onDone({
      conversationId: "confirmed-id",
      content: "You have one bolt.",
      context: {
        sources: [
          {
            kind: "inventory",
            label: "Inventory",
            detail: "One record checked",
          },
        ],
        rows: [],
        rowsTruncated: false,
      },
    });
  });
  render(<AssistClient initialQuery="Where is the bolt?" />);
  await user.click(screen.getByRole("button", { name: "Ask" }));
  await screen.findByText("One record checked");
  await waitFor(() =>
    expect(
      screen.getByLabelText("Your question").getAttribute("disabled"),
    ).toBeNull(),
  );
  fireEvent.change(screen.getByLabelText("Your question"), {
    target: { value: "And how many?" },
  });
  await user.click(screen.getByRole("button", { name: "Ask" }));
  expect(jest.mocked(askQuestion).mock.calls[1][0].conversationId).toBe(
    "confirmed-id",
  );
});
test("an interrupted answer preserves the question draft and marks partial output", async () => {
  const user = userEvent.setup();
  jest.mocked(askQuestion).mockImplementation(async (options) => {
    options.onDelta("Partial");
    throw new Error("network failed");
  });
  render(<AssistClient initialQuery="Where is the bolt?" />);
  await user.click(screen.getByRole("button", { name: "Ask" }));
  await screen.findByText(/answer was interrupted/);
  expect(
    (screen.getByLabelText("Your question") as HTMLTextAreaElement).value,
  ).toBe("Where is the bolt?");
  expect(screen.queryByLabelText("Sources checked")).toBeNull();
});
test("retrying a question leaves an older empty failed reply separate from the pending status", async () => {
  const user = userEvent.setup();
  jest.mocked(askQuestion)
    .mockRejectedValueOnce(new Error("network failed"))
    .mockImplementationOnce(() => new Promise(() => {}));
  render(<AssistClient initialQuery="Where is the bolt?" />);
  await user.click(screen.getByRole("button", { name: "Ask" }));
  await screen.findByText("The answer did not finish.");
  await user.click(screen.getByRole("button", { name: "Ask" }));
  expect(screen.getByText("The answer did not finish.")).toBeTruthy();
  expect(screen.getByRole("status").textContent).toBe("Checking your inventory…");
  expect(screen.getByRole("status").closest("details")).not.toBeNull();
});
test.each([0, 3])("Home shows attention only for actual pending work (%i captures)", async (pending) => {
  const original = jest.mocked(accountRequest).getMockImplementation()!;
  jest.mocked(accountRequest).mockImplementation(async (account, path, options) => {
    if (path === "/review-items?limit=1") return { pending_count: pending };
    if (path === "/checkouts/active") return { checkouts: [] };
    if (path === "/profile/me") return { display_name: "QA" };
    return original(account, path, options);
  });
  render(<HomeOverview />);
  await screen.findByText("Hello, QA.");
  expect(screen.queryByRole("heading", { name: "Needs your attention" }) !== null).toBe(pending > 0);
  expect(screen.queryByText("to buy")).toBeNull();
  expect(screen.queryByText("on order")).toBeNull();
  expect(screen.queryByText("overdue lent items")).toBeNull();
  expect(screen.queryByRole("button", { name: "Where is my soldering iron?" })).toBeNull();
  expect(screen.getByText("1 item across 1 Space.")).toBeTruthy();
});
test.each([true, false])("empty Home provides only permitted creation actions (editor=%s)", async (canEdit) => {
  selectInventory({ inventory_id: "fixture", can_edit: canEdit } as never);
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => {
    if (path === "/search_items") return { items: [] };
    if (path === "/spaces") return [];
    if (path === "/review-items?limit=1") return { pending_count: 0 };
    if (path === "/checkouts/active") return { checkouts: [] };
    if (path === "/profile/me") return { display_name: "QA" };
    throw new Error("Unexpected path");
  });
  render(<HomeOverview />);
  await screen.findByText("Hello, QA.");
  expect(screen.getByRole("region", { name: "Recently added" })).toBeTruthy();
  expect(screen.getByRole("region", { name: "Your Spaces" })).toBeTruthy();
  expect(screen.queryByRole("link", { name: "Capture your first items" }) !== null).toBe(canEdit);
  expect(screen.queryByRole("link", { name: "Create a Space" }) !== null).toBe(canEdit);
  expect(screen.queryByRole("link", { name: "Capture" }) !== null).toBe(canEdit);
  expect(screen.getByRole("heading", { name: "No Spaces yet" })).toBeTruthy();
  selectInventory(null);
});
test("failed inventory loading does not show a false empty inventory", async () => {
  const original = jest.mocked(accountRequest).getMockImplementation()!;
  jest.mocked(accountRequest).mockImplementation(async (account, path, options) => {
    if (path === "/search_items") throw new Error("unavailable");
    return original(account, path, options);
  });
  render(<HomeOverview />);
  await screen.findByText(/Could not load inventory/);
  expect(screen.queryByRole("heading", { name: "Start with a photo" })).toBeNull();
  expect(screen.queryByRole("heading", { name: "No items yet" })).toBeNull();
  expect(screen.getByRole("button", { name: "Try again" })).toBeTruthy();
});
test("a failed note upload keeps the unsaved text available", async () => {
  const user = userEvent.setup();
  render(<DocumentsClient />);
  await screen.findByText("note-one.txt");
  await user.click(screen.getByRole("button", { name: "New note" }));
  fireEvent.change(screen.getByLabelText("Title"), {
    target: { value: "Workshop" },
  });
  fireEvent.change(screen.getByLabelText("Note"), {
    target: { value: "Save these instructions." },
  });
  jest.mocked(accountRequest).mockImplementationOnce(async () => {
    throw new Error("upload failed");
  });
  await user.click(screen.getByRole("button", { name: "Save note" }));
  await waitFor(() =>
    expect(screen.getAllByRole("alert").length).toBeGreaterThan(0),
  );
  expect((screen.getByLabelText("Note") as HTMLTextAreaElement).value).toBe(
    "Save these instructions.",
  );
  expect(screen.getByRole("dialog")).toBeTruthy();
});
test("note search includes the loaded note content", async () => {
  render(<DocumentsClient />);
  await waitFor(() => expect(global.fetch).toHaveBeenCalled());
  await waitFor(() =>
    expect(screen.queryByText("Loading documents…")).toBeNull(),
  );
  fireEvent.change(
    screen.getByLabelText("Search documents and note contents"),
    { target: { value: "fixings" } },
  );
  await screen.findByText("note-one.txt");
  fireEvent.change(
    screen.getByLabelText("Search documents and note contents"),
    { target: { value: "no match anywhere" } },
  );
  await screen.findByText("No matching documents or notes");
});
test("a shared viewer can inspect the gallery but has no photo mutation controls", async () => {
  render(
    <ItemPhotoGallery
      itemId="i"
      context={{ kind: "shared", shareId: "s" }}
      canEdit={false}
    />,
  );
  await screen.findByRole("button", { name: "Open item photo 1, primary" });
  expect(accountRequest).toHaveBeenCalledWith("a", "/sharing/s/items/i/photos");
  expect(screen.queryByRole("button", { name: "Add photo" })).toBeNull();
  expect(screen.queryByRole("button", { name: "Delete photo" })).toBeNull();
});

test("account changes immediately clear item photos while the next account is loading", async () => {
  const view = render(<ItemPhotoGallery itemId="i" canEdit />);
  await screen.findByRole("button", { name: "Open item photo 1, primary" });
  jest
    .mocked(useApiSession)
    .mockReturnValue({
      accountId: "b",
      token: "token-b",
      error: null,
    } as never);
  jest.mocked(accountRequest).mockImplementation(() => new Promise(() => {}));
  view.rerender(<ItemPhotoGallery itemId="i" canEdit />);
  expect(
    screen.queryByRole("button", { name: "Open item photo 1, primary" }),
  ).toBeNull();
  expect(screen.getByRole("status").textContent).toBe("Loading photos…");
});
test("Before I buy clears another account's results and retains a failed search draft", async () => {
  const user = userEvent.setup();
  const view = render(<CollectionsClient />);
  const input = screen.getByLabelText("What are you thinking of buying?");
  fireEvent.change(input, { target: { value: "Bolt" } });
  await user.click(screen.getByRole("button", { name: "Check" }));
  await screen.findByRole("link", { name: /Bolt Garage/ });
  expect(screen.getByText("1 exact · 0 related")).toBeTruthy();
  jest
    .mocked(useApiSession)
    .mockReturnValue({
      accountId: "b",
      token: "token-b",
      error: null,
    } as never);
  view.rerender(<CollectionsClient />);
  expect(screen.queryByRole("link", { name: /Bolt Garage/ })).toBeNull();
  fireEvent.change(screen.getByLabelText("What are you thinking of buying?"), {
    target: { value: "My hub" },
  });
  jest.mocked(accountRequest).mockRejectedValue(new Error("Failed to fetch"));
  await user.click(screen.getByRole("button", { name: "Check" }));
  await screen.findByRole("alert");
  expect(
    (
      screen.getByLabelText(
        "What are you thinking of buying?",
      ) as HTMLInputElement
    ).value,
  ).toBe("My hub");
});

test('Enter sends and clears the composer immediately; Shift Enter and composition do not send', async()=>{
  let done!:(value: {conversationId:string;content:string;messageId:string})=>void;
  let finish!:()=>void;
  jest.mocked(askQuestion).mockImplementation(options=>{done=options.onDone;return new Promise(resolve=>{finish=resolve;});});
  render(<AssistClient initialQuery="Count my mugs"/>);
  const input=screen.getByLabelText('Your question') as HTMLTextAreaElement;
  fireEvent.keyDown(input,{key:'Enter',shiftKey:true});expect(askQuestion).not.toHaveBeenCalled();
  fireEvent.keyDown(input,{key:'Enter',isComposing:true});expect(askQuestion).not.toHaveBeenCalled();
  fireEvent.keyDown(input,{key:'Enter'});await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(1));expect(input.value).toBe('');
  done({conversationId:'chat',content:'Three mugs.',messageId:'saved-answer'});finish();
  await screen.findByLabelText('Good response');
  expect(document.querySelectorAll('time')).toHaveLength(2);
  expect(screen.queryByLabelText('Edit prompt')).toBeNull();expect(input.value).toBe('');
});
