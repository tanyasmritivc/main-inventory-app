/** @jest-environment jsdom */

import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ApiDocumentation } from "@/components/site/api-documentation";
import { CodeExample, PrintDocumentation } from "@/components/site/api-docs-controls";
import { apiEndpoints, guideSections } from "@/lib/api-docs";

test("public guide renders all operations, sections, and working navigation anchors", () => {
  const { container } = render(<ApiDocumentation />);
  expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Build with your inventory.");
  for (const section of guideSections) expect(document.getElementById(section.id)).not.toBeNull();
  expect(screen.getAllByRole("heading", { level: 3 }).map(heading => heading.id)).toEqual(apiEndpoints.map(endpoint => `${endpoint.id}-title`));
  for (const link of container.querySelectorAll<HTMLAnchorElement>('a[href^="#"]')) {
    expect(document.getElementById(link.hash.slice(1))).not.toBeNull();
  }
  const ids = Array.from(container.querySelectorAll("[id]"), element => element.id);
  expect(new Set(ids).size).toBe(ids.length);
  expect(screen.queryByRole("textbox")).toBeNull(); // No secret-entry playground.
});

test("offers guide/specification downloads and the protected key-management destination", () => {
  render(<ApiDocumentation />);
  expect(screen.getByRole("link", { name: "Download guide" }).getAttribute("href")).toBe("/docs/api/guide.md");
  expect(screen.getByRole("link", { name: "OpenAPI specification" }).getAttribute("href")).toBe("/docs/api/openapi.json");
  expect(screen.getByRole("link", { name: "Create an API key" }).getAttribute("href")).toBe("/settings/api-keys");
});

test("copy sends exactly the displayed example to the clipboard", async () => {
  const user = userEvent.setup();
  const write = jest.spyOn(navigator.clipboard, "writeText");
  const value = 'curl https://api.findez.ai/api/v1/whoami \\\n  -H "Authorization: Bearer $FINDEZ_API_KEY"';
  render(<CodeExample label="Connection request" language="cURL" value={value} />);
  await user.click(screen.getByRole("button", { name: "Copy Connection request" }));
  expect(write).toHaveBeenCalledWith(value);
  expect(screen.getByRole("status").textContent).toBe("Connection request copied.");
});

test("blocked clipboard exposes manual-copy fallback instead of claiming success", async () => {
  const user = userEvent.setup();
  jest.spyOn(navigator.clipboard, "writeText").mockRejectedValueOnce(new Error("blocked"));
  render(<CodeExample label="Example" language="JSON" value={'{"quantity": 4}'} />);
  await user.click(screen.getByRole("button", { name: "Copy Example" }));
  expect(screen.getByRole("status").textContent).toContain("copy it manually");
  expect(window.getSelection()?.toString()).toBe('{"quantity": 4}');
  expect(screen.queryByText("Copied")).toBeNull();
});

test("print guide invokes the browser's print dialog", async () => {
  const user = userEvent.setup();
  const print = jest.spyOn(window, "print").mockImplementation(() => {});
  render(<PrintDocumentation />);
  await user.click(screen.getByRole("button", { name: "Print guide" }));
  expect(print).toHaveBeenCalledTimes(1);
});
