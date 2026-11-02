/** @jest-environment jsdom */
import { render, screen } from "@testing-library/react";
import { AskMarkdown } from "@/components/site/ask-markdown";

test("AI emphasis, lists, headings and code render as readable semantic content", () => {
  const { container } = render(<AskMarkdown>{"## Your inventory\n\nYou have **four bolts** and *one motor*.\n\n- Garage\n- Shelf\n\nUse `M4`."}</AskMarkdown>);
  expect(screen.getByText("four bolts").tagName).toBe("STRONG");
  expect(screen.getByText("one motor").tagName).toBe("EM");
  expect(screen.getByRole("heading", { name: "Your inventory" })).toBeTruthy();
  expect(screen.getAllByRole("listitem")).toHaveLength(2);
  expect(screen.getByText("M4").tagName).toBe("CODE");
  expect(container.textContent).not.toContain("**");
});

test("partial streamed emphasis becomes bold when the closing markers arrive", () => {
  const view = render(<AskMarkdown>{"You have **four bolts"}</AskMarkdown>);
  view.rerender(<AskMarkdown>{"You have **four bolts**"}</AskMarkdown>);
  expect(screen.getByText("four bolts").tagName).toBe("STRONG");
});

test("GFM tables remain accessible and scrollable", () => {
  const { container } = render(<AskMarkdown>{"| Part | Stock |\n| --- | --- |\n| Bolt | 4 |"}</AskMarkdown>);
  expect(screen.getByRole("table")).toBeTruthy();
  expect(screen.getByRole("columnheader", { name: "Stock" })).toBeTruthy();
  expect(container.querySelector(".ask-markdown-table")).toBeTruthy();
});

test("generated images, raw HTML and executable links cannot make requests or run code", () => {
  const { container } = render(<AskMarkdown>{'![tracking](https://evil.test/pixel)\n\n<script>alert(1)</script>\n\n<a href="javascript:alert(1)">HTML link</a>\n\n[Bad link](javascript:alert%281%29)'}</AskMarkdown>);
  expect(container.querySelector("img,script,iframe")).toBeNull();
  expect(container.querySelector('a[href^="javascript:"]')).toBeNull();
  expect(screen.queryByRole("link", { name: "Bad link" })).toBeNull();
});

test("ordinary links are safe and decorative rules are omitted", () => {
  const { container } = render(<AskMarkdown>{"[Inventory](/inventory) and [Documentation](https://findez.ai/docs/api)\n\n---"}</AskMarkdown>);
  expect(screen.getByRole("link", { name: "Inventory" }).getAttribute("href")).toBe("/inventory");
  expect(screen.getByRole("link", { name: "Documentation" }).getAttribute("rel")).toContain("noopener");
  expect(container.querySelector("hr")).toBeNull();
});
