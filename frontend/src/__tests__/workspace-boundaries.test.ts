import { readFileSync } from "node:fs";
import { accountRequest } from "@/lib/account-request";
import { apiRequest } from "@/lib/api";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  documentKind,
  ownedNotePath,
  trustedDocumentUrl,
} from "@/lib/documents";
import { photoPath } from "@/lib/item-photos";
jest.mock("@/lib/api", () => ({ apiRequest: jest.fn() }));
jest.mock("@/lib/supabase/browser", () => ({
  createSupabaseBrowserClient: jest.fn(),
}));
beforeEach(() => jest.clearAllMocks());
test("requests bind their credential to the initiating account", async () => {
  const getSession = jest.fn().mockResolvedValue({
    data: { session: { user: { id: "a" }, access_token: "a-token" } },
  });
  jest
    .mocked(createSupabaseBrowserClient)
    .mockReturnValue({ auth: { getSession } } as never);
  jest.mocked(apiRequest).mockResolvedValue({ ok: true });
  await accountRequest("a", "/write", {
    method: "PATCH",
    body: { quantity: 7 },
  });
  expect(apiRequest).toHaveBeenCalledWith(
    "/write",
    expect.objectContaining({ token: "a-token", bindToToken: true }),
  );
});
test("account switches block writes and reject delayed results", async () => {
  const getSession = jest
    .fn()
    .mockResolvedValueOnce({
      data: { session: { user: { id: "a" }, access_token: "a-token" } },
    })
    .mockResolvedValue({
      data: { session: { user: { id: "b" }, access_token: "b-token" } },
    });
  jest
    .mocked(createSupabaseBrowserClient)
    .mockReturnValue({ auth: { getSession } } as never);
  await expect(accountRequest("a", "/write")).rejects.toThrow(
    "account changed",
  );
  expect(apiRequest).toHaveBeenCalledTimes(1);
  await expect(accountRequest("a", "/write")).rejects.toThrow(
    "account changed",
  );
  expect(apiRequest).toHaveBeenCalledTimes(1);
});
test("gallery routing preserves personal, Shared Space and Team authorization", () => {
  expect(photoPath("i", { kind: "personal" })).toBe("/items/i/photos");
  expect(photoPath("i", { kind: "shared", shareId: "s" })).toBe(
    "/sharing/s/items/i/photos",
  );
  expect(photoPath("i", { kind: "team", teamId: "t", spaceId: "s" })).toBe(
    "/teams/t/spaces/s/items/i/photos",
  );
});
test("document text and uploads distinguish notes from inventory import files", () => {
  expect(
    documentKind({
      storage_path: "a/note",
      filename: "Workshop.txt",
      mime_type: "text/plain",
    }),
  ).toBe("notes");
  expect(
    documentKind({
      storage_path: "a/csv",
      filename: "Stock.csv",
      mime_type: "text/csv",
    }),
  ).toBe("files");
  expect(ownedNotePath("b/docs/n.txt", "a")).toBe(false);
  expect(ownedNotePath("a/docs/../n.txt", "a")).toBe(false);
});
test("document URLs cannot escape owned storage or change origin", () => {
  const url =
    "https://store.example/storage/v1/object/sign/documents/a/docs/n.txt?token=temporary";
  expect(trustedDocumentUrl(url, "a", ["https://store.example"])).toBe(url);
  for (const value of [
    url.replace("/a/", "/b/"),
    url.replace("store.example", "evil.example"),
    url.replace("/docs/n.txt", "/docs/%2Fescape.txt"),
  ])
    expect(
      trustedDocumentUrl(value, "a", ["https://store.example"]),
    ).toBeUndefined();
});
test("new visual rules stay scoped to the app or interior-only overlays", () => {
  const css = readFileSync("src/app/workspace.css", "utf8").replace(
    /\/\*[\s\S]*?\*\//g,
    "",
  );
  const rules = [...css.matchAll(/([^{}]+)\{/g)]
    .map((m) => m[1].trim())
    .filter((s) => !s.startsWith("@"));
  for (const selectors of rules)
    for (const selector of selectors.split(/,(?![^()]*\))/))
      expect(selector.trim()).toMatch(
        /(?:app-frame|workspace-dialog|command-panel|interior-loading)/,
      );
});
