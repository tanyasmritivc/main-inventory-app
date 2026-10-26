/** @jest-environment jsdom */
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ChatPlusMenu } from "@/components/site/chat-plus-menu";
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
test.each([
  ["Attach", "Photo library", "library"],
  ["Attach", "Take photo", "camera"],
  ["Attach", "Choose files", "file"],
  ["Inventory tools", "Import inventory", "spreadsheet"],
  ["Inventory tools", "Scan barcode", "barcode"],
  ["Add context", "Spaces", "space"],
  ["Add context", "Items", "item"],
  ["Add context", "Projects", "project"],
  ["Add context", "Documents and notes", "document"],
])("%s opens the mobile-equivalent %s action", async (group, label, choice) => {
  const select = jest.fn();
  render(<ChatPlusMenu disabled={false} onSelect={select} />);
  await userEvent.click(screen.getByRole("button", { name: "Add to chat" }));
  await userEvent.hover(screen.getByRole("menuitem", { name: group }));
  await userEvent.click(await screen.findByRole("menuitem", { name: label }));
  expect(select).toHaveBeenCalledWith(choice);
  expect(screen.queryByRole("menu")).toBeNull();
});
test("Auto Extract is explicit; connections reuse available assistant setup", async () => {
  const select = jest.fn();
  render(<ChatPlusMenu disabled={false} onSelect={select} />);
  await userEvent.click(screen.getByRole("button", { name: "Add to chat" }));
  await userEvent.click(screen.getByRole("menuitem", { name: "Auto Extract" }));
  expect(select).toHaveBeenCalledWith("auto_extract");
  await userEvent.click(screen.getByRole("button", { name: "Add to chat" }));
  await userEvent.hover(screen.getByRole("menuitem", { name: "Add context" }));
  expect(
    (await screen.findByRole("menuitem", { name: "Connections" })).getAttribute(
      "href",
    ),
  ).toBe("/docs/api#ai-assistants");
  expect(screen.queryByText(/Google|Skills|Coming soon/)).toBeNull();
});
