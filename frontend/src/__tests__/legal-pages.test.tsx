/** @jest-environment jsdom */
import { fireEvent, render, screen, within } from "@testing-library/react";
import { readFileSync } from "node:fs";
import path from "node:path";
import PrivacyPage, { metadata as privacyMetadata } from "@/app/privacy/page";
import TermsPage, { metadata as termsMetadata } from "@/app/terms/page";
import { legalPublication, privacyIntro, privacySections, termsSections } from "@/lib/legal-content";
import { isProtectedPath } from "@/lib/protected-routes";

const documents = [
  { kind: "privacy", title: "Privacy Policy", Page: PrivacyPage, sections: privacySections, metadata: privacyMetadata },
  { kind: "terms", title: "Terms of Service", Page: TermsPage, sections: termsSections, metadata: termsMetadata },
] as const;

describe.each(documents)("$title review page", ({ kind, title, Page, sections, metadata }) => {
  test("renders the complete draft without account data or an auth gate", () => {
    render(<Page />);
    expect(isProtectedPath(`/${kind}`)).toBe(false);
    expect(screen.getByRole("heading", { level: 1, name: title })).toBeTruthy();
    expect(screen.getByRole("note", { name: "Review draft notice" }).textContent).toContain("not yet effective");
    expect(screen.getByText("October 4, 2026").getAttribute("datetime")).toBe("2026-10-04");
    const article = screen.getByRole("article", { name: title });
    for (const section of sections) {
      expect(within(article).getByRole("heading", { level: 2, name: section.heading })).toBeTruthy();
      for (const paragraph of section.body) expect(article.textContent).toContain(paragraph);
      for (const bullet of section.bullets ?? []) expect(article.textContent).toContain(bullet);
    }
    expect(screen.queryByRole("textbox")).toBeNull();
    expect(screen.queryByText("Sign in")).toBeNull();
  });

  test("all section links have real targets, with accessible navigation and a skip link", () => {
    const { container } = render(<Page />);
    const ids = sections.map((section) => section.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const id of ids) {
      expect(id).toMatch(/^[a-z]+(?:-[a-z]+)*$/);
      expect(container.querySelector(`#${id}`)?.getAttribute("aria-labelledby")).toBe(`${id}-heading`);
    }
    for (const link of screen.getAllByRole("link")) {
      const href = link.getAttribute("href") ?? "";
      expect(href.length).toBeGreaterThan(0);
      if (href.startsWith("#")) expect(container.querySelector(href)).not.toBeNull();
      if (href.startsWith("/privacy#")) expect(privacySections.some((section) => section.id === href.split("#")[1])).toBe(true);
    }
    expect(screen.getByRole("link", { name: `Skip to ${title}` }).getAttribute("href")).toBe("#legal-content");
    const pageNav = screen.getByRole("navigation", { name: "Legal pages" });
    expect(within(pageNav).getByRole("link", { name: kind === "privacy" ? "Privacy" : "Terms" }).getAttribute("aria-current")).toBe("page");
    expect(screen.getByRole("navigation", { name: "On this page" })).toBeTruthy();
  });

  test("offers contact, current published policy and printing without rewriting content", () => {
    const print = jest.spyOn(window, "print").mockImplementation(() => undefined);
    render(<Page />);
    expect(screen.getByRole("link", { name: `View the currently published ${title.toLowerCase()}` }).getAttribute("href")).toBe(`https://www.findez.ai/${kind}`);
    expect(screen.getByRole("link", { name: "info@findez.ai" }).getAttribute("href")).toBe("mailto:info@findez.ai");
    fireEvent.click(screen.getByRole("button", { name: "Print / save a copy" }));
    expect(print).toHaveBeenCalledTimes(1);
    print.mockRestore();
    expect(screen.getByRole("note", { name: "Review draft notice" })).toBeTruthy();
  });

  test("does not index an unresolved draft or inherit the home-page canonical", () => {
    expect(metadata.alternates).toEqual({ canonical: `https://www.findez.ai/${kind}` });
    expect(metadata.robots).toEqual({ index: false, follow: false });
    expect(metadata.title).toContain("Review Draft");
  });
});

test("draft distinguishes current no-training practice from unverified processor and deletion guarantees", () => {
  expect(legalPublication.status).toBe("draft");
  const privacy = privacySections.flatMap((section) => section.body).join("\n");
  expect(privacy).toContain("direct file URL");
  expect(privacy).toContain("without signing in");
  expect(privacy).toContain("The document storage bucket is private");
  expect(privacy).toContain("already-issued link");
  expect(privacy).not.toContain("item-photo and document storage buckets are configured for public");
  expect(privacy).toContain("uses HTTP, not an encrypted transport");
  expect(privacy).toContain("FindEZ does not currently use customer photos, chats or documents to train or fine-tune AI models");
  expect(privacy).toContain("Processing content to provide requested features");
  expect(privacy).toContain("AI Robots Inc operates both the FIND vision pipeline and the FTCTools language-model gateway");
  expect(privacy).toContain("retention remains unconfirmed");
  expect(privacy).toContain("Independently verify FIND and language-model infrastructure's permitted uses and downstream training practices");
  expect(privacy).not.toContain("customer content is used for model training");
  expect(privacy).toContain("REVIEW REQUIRED BEFORE PUBLICATION");
  expect(privacy).toContain("No immediate or universal erasure guarantee");
  expect(privacyIntro).toContain("California corporation");
});

test("future training is not authorized by today's notice or Terms and no consent control is invented", () => {
  const privacy = privacySections.find((section) => section.id === "ai")!.body.join("\n");
  const terms = termsSections.find((section) => section.id === "content")!.body.join("\n");
  expect(privacy).toContain("future possibility, not a current feature or permission granted by this notice");
  for (const content of [privacy, terms]) {
    expect(content).toContain("separate, explicit opt-in consent");
    expect(content).toContain("will not prevent ordinary use of FindEZ");
    expect(content).not.toMatch(/(?:enable|disable|toggle|turn off) training in settings/i);
  }
  expect(terms).toContain("FindEZ does not currently use customer photos, chats or documents for model training");
  expect(terms).toContain("accepting these Terms does not provide that consent");
});

test("terms preserve mandatory rights and do not promise immunity or impose arbitration", () => {
  const terms = termsSections.flatMap((section) => section.body).join("\n");
  expect(terms).toContain("must be at least 13");
  expect(terms).toContain("parent or legal guardian");
  expect(terms).toContain("California law governs");
  expect(terms).toContain("fraud, intentional misconduct, gross negligence");
  expect(terms).toContain("no mandatory arbitration or class-action waiver");
  expect(terms).toContain("not imposed on individual consumers");
  expect(terms).not.toContain("you waive all rights");
});

test("legal pages use the original supplied outlined wordmark without third-party assets", () => {
  const bundled = readFileSync(path.resolve(__dirname, "../../public/images/findez-legal-wordmark.svg"), "utf8").trim();
  const original = readFileSync(path.resolve(__dirname, "../../../mobile/assets/brand/findez-wordmark.svg"), "utf8").trim();
  expect(bundled).toBe(original);
  render(<PrivacyPage />);
  expect(screen.getByRole("img", { name: "FindEZ" }).getAttribute("src")).toBe("/images/findez-legal-wordmark.svg");
});
