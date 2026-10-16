// Screenshots the reference prototype and the Next.js implementation at the same
// scroll progress through every section, so they can be compared side by side.
//
// Usage (from frontend/):
//   npx -y playwright@1.48.2 install chromium   (first time only)
//   node design/landing-lab/tools/compare.mjs [targetUrl]
// Default target: http://localhost:3000/lab
// Output: design/landing-lab/compare-out/<viewport>/<step>-ref.png and -new.png

import { chromium } from "playwright";
import path from "node:path";
import fs from "node:fs";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const REF = "file://" + path.resolve(here, "../reference/index.html");
const TARGET = process.argv[2] || "http://localhost:3000/lab";
const OUT = path.resolve(here, "../compare-out");

// [section id, progress through the section 0..1]. Pinned sections get several stops.
const STEPS = [
  ["hero", 0], ["stmt", 0.4], ["see", 0.2], ["see", 0.7],
  ["graph", 0], ["graph", 0.35], ["graph", 0.7], ["graph", 1],
  ["zoom", 0], ["zoom", 0.25], ["zoom", 0.5], ["zoom", 0.75], ["zoom", 1],
  ["ask", 0.3], ["own", 0.6], ["who", 0.3], ["find", 0.3],
  ["vision", 0.2], ["vision", 0.6], ["app", 0.2], ["app", 0.6], ["waitlist", 0.3], ["end", 0.6],
];
const VIEWPORTS = [{ name: "desktop", width: 1440, height: 900 }, { name: "mobile", width: 390, height: 844 }];

const shoot = async (page, url, dir, tag) => {
  await page.goto(url, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  // The shared site's cookie notice is not part of the isolated prototype.
  const cookieNotice = page.getByRole("complementary", { name: "Cookies and device storage" });
  if (await cookieNotice.isVisible()) await cookieNotice.getByRole("button", { name: "Got it" }).click();
  await page.waitForTimeout(1200);
  let i = 0;
  for (const [id, f] of STEPS) {
    if (process.env.LAB_SECTIONS && !process.env.LAB_SECTIONS.split(",").includes(id)) { i++; continue; }
    const y = await page.evaluate(([id, f]) => {
      const el = document.getElementById(id);
      if (!el) return null;
      const top = el.getBoundingClientRect().top + window.scrollY;
      const travel = Math.max(0, el.offsetHeight - window.innerHeight);
      return Math.round(top + f * (travel || el.offsetHeight * 0.5) - (travel ? 0 : window.innerHeight * 0.3));
    }, [id, f]);
    const name = String(++i).padStart(2, "0") + "-" + id + "-" + Math.round(f * 100);
    if (y == null) { console.log(tag, "missing section id:", id); continue; }
    await page.evaluate((y) => window.scrollTo(0, y), y);
    await page.waitForTimeout(700);
    // Sample ambient animation at the same time without changing scroll styles.
    await page.evaluate(() => {
      for (const animation of document.getAnimations()) {
        animation.pause(); animation.currentTime = 1500;
      }
      for (const svg of document.querySelectorAll("svg")) {
        svg.pauseAnimations(); svg.setCurrentTime(1.5);
      }
    });
    await page.screenshot({ path: path.join(dir, name + "-" + tag + ".png") });
  }
};

const browser = await chromium.launch();
for (const vp of VIEWPORTS) {
  const dir = path.join(OUT, vp.name);
  fs.mkdirSync(dir, { recursive: true });
  for (const [url, tag] of [[REF, "ref"], [TARGET, "new"]]) {
    const page = await browser.newPage({ viewport: { width: vp.width, height: vp.height }, deviceScaleFactor: 1 });
    const errors = [];
    page.on("pageerror", error => errors.push(error.message));
    page.on("console", message => { if (message.type() === "error") errors.push(message.text()); });
    await shoot(page, url, dir, tag);
    const metrics = await page.evaluate(() => ({
      controls: [...document.querySelectorAll("#waitlist input, #waitlist button, #who .pill")].slice(0, 2).map(e => ({ tag: e.tagName, height: e.getBoundingClientRect().height, css: Object.fromEntries(["fontFamily", "fontSize", "fontWeight", "lineHeight", "padding", "border", "boxSizing"].map(k => [k, getComputedStyle(e)[k]])) })),
      waitlist: [...document.querySelectorAll("#waitlist input, #waitlist button")].map(e => ({ tag: e.tagName, height: e.getBoundingClientRect().height, css: Object.fromEntries(["fontFamily", "fontSize", "fontWeight", "lineHeight", "padding", "border", "boxSizing", "display"].map(k => [k, getComputedStyle(e)[k]])) })),
      width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
      fonts: [...document.fonts].map(f => ({ family: f.family, status: f.status })),
      sections: [...document.querySelectorAll("section[id], footer[id]")].map(e => ({ id: e.id, height: e.getBoundingClientRect().height })),
    }));
    fs.writeFileSync(path.join(dir, tag + "-checks.json"), JSON.stringify({ errors, ...metrics }, null, 2));
    if (tag === "new") {
      assert.equal(errors.length, 0, "Browser console must be clean");
      assert.equal(metrics.scrollWidth, vp.width, "No horizontal page overflow");
      const mainNav = page.getByRole("navigation", { name: "Main navigation" });
      if (await mainNav.count()) {
        assert.equal(await mainNav.getByRole("link").count(), 3);
        assert.equal(await mainNav.getByRole("link", { name: "Developers", exact: true }).getAttribute("href"), "/docs/api");
        assert.equal(await mainNav.getByRole("link", { name: "iOS App", exact: true }).getAttribute("href"), "https://apps.apple.com/us/app/findez-ai/id6760401697");
        const footerNav = page.getByRole("navigation", { name: "Footer navigation" });
        const links = { Plans: "/pricing", Developers: "/docs/api", "iOS App": "https://apps.apple.com/us/app/findez-ai/id6760401697", Privacy: "/privacy", Terms: "/terms", Contact: "mailto:info@findez.ai" };
        for (const [name, href] of Object.entries(links)) assert.equal(await footerNav.getByRole("link", { name, exact: true }).getAttribute("href"), href);
      } else {
        assert.equal(await page.getByRole("link", { name: "Log in", exact: true }).getAttribute("href"), "/signin");
      }
      for (const link of await page.getByRole("link", { name: "Get started", exact: true }).all()) {
        assert.equal(await link.getAttribute("href"), "/signup");
      }
      const requests = [];
      page.on("request", r => { if (["fetch", "xhr"].includes(r.resourceType())) requests.push(r.url()); });
      const email = page.getByLabel("Email address", { exact: true });
      await email.fill("invalid");
      await page.getByRole("button", { name: "Join waitlist", exact: true }).click();
      await page.getByText("Enter an email address like you@example.com.", { exact: true }).waitFor({ state: "visible" });
      await email.fill("preview@example.com");
      await email.press("Enter");
      await page.getByText("You are on the list. We will email", { exact: false }).waitFor({ state: "visible" });
      assert.equal(requests.length, 0, "Preview waitlist must send no API request");
      await page.emulateMedia({ reducedMotion: "reduce" });
      await page.waitForTimeout(150);
      const reduced = await page.evaluate(() => ({
        graph: document.getElementById("graph").offsetHeight,
        zoom: document.getElementById("zoom").offsetHeight,
        position: getComputedStyle(document.getElementById("zoom").firstElementChild).position,
        svgPaused: [...document.querySelectorAll("svg")].every(s => s.animationsPaused()),
        width: document.documentElement.scrollWidth,
      }));
      assert.equal(reduced.graph, Math.min(vp.height, 860));
      assert.equal(reduced.zoom, Math.min(vp.height, 860));
      assert.equal(reduced.position, "relative");
      assert.equal(reduced.svgPaused, true);
      assert.equal(reduced.width, vp.width);
      fs.writeFileSync(path.join(dir, "behavior-checks.json"), JSON.stringify({ waitlist: "validation and confirmation passed", requests, reduced }, null, 2));
    }
    await page.close();
  }
  console.log("wrote", dir);
}
await browser.close();
