/** @jest-environment node */
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { initialLabState, landingLabValues } from "../components/site/landing-lab-engine";

type Reference = { state: typeof initialLabState; renderVals(): Record<string, unknown> };
const source = fs.readFileSync(path.join(process.cwd(), "design/landing-lab/source/Lab.dc.html"), "utf8");
const script = source.slice(source.indexOf("class Component extends DCLogic"), source.lastIndexOf("</script>"));
const context = vm.createContext({ DCLogic: class {} });
vm.runInContext(script + ";globalThis.Reference = Component;", context);
const ReferenceClass = context.Reference as new () => Reference;
function normalize(value: unknown): unknown {
  if (typeof value === "string") return value.replaceAll("assets/", "/images/landing-lab/").replaceAll("font-family:'Geist Mono'", "font-family:var(--fzl-mono)").replaceAll("animation:vpulse", "animation:fzl-vpulse");
  if (Array.isArray(value)) return Array.from(value, normalize);
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).filter(([, v]) => typeof v !== "function").map(([key, v]) => [key, normalize(v)]));
  return value;
}
for (const [W, H] of [[1440, 900], [390, 844]]) {
  for (const progress of [0, 0.25, 0.5, 0.75, 1]) {
    test(`matches every prototype formula at ${W}px and ${progress}`, () => {
      const reference = new ReferenceClass();
      const state = { ...initialLabState, W, H, prog: progress, hp: progress, sp: progress, seg: progress, ge: progress, gp: progress, zp: progress, ap: progress, own: progress, wp: progress, fp: progress, vp: progress, ep: progress, gx: progress, mk: { see: progress, ask: progress, vision: progress, who: progress, waitlist: progress, find: progress } };
      reference.state = state;
      expect(normalize(landingLabValues(state))).toEqual(normalize(reference.renderVals()));
    });
  }
}
test("reduced motion finishes the camera and removes pinned travel", () => {
  const values = landingLabValues({ ...initialLabState, still: true, zp: 1, gp: 1, vp: 1 });
  expect(values.graphSec).toContain("height:860px");
  expect(values.zoomSec).toContain("height:860px");
  expect(values.pinTop).toContain("position:relative");
  expect(values.zCard).toContain("opacity:1.000");
  expect(values.ownPct).toBe("92%");
});

test("the location headline reveals in order and reverses with scroll", () => {
  const before = landingLabValues({ ...initialLabState, ze: 0 }, true).locationLetters!;
  const during = landingLabValues({ ...initialLabState, ze: 0.55 }, true).locationLetters!;
  const after = landingLabValues({ ...initialLabState, ze: 1 }, true).locationLetters!;
  expect(before.every(letter => letter.style === "opacity:0.000")).toBe(true);
  expect(during[0].style).toBe("opacity:1.000");
  expect(during.at(-1)!.style).toBe("opacity:0.000");
  expect(after.every(letter => letter.style === "opacity:1.000")).toBe(true);
  expect(landingLabValues({ ...initialLabState, ze: 0 }, true).locationLetters).toEqual(before);
  expect(landingLabValues({ ...initialLabState, still: true, ze: 0 }, true).locationLetters!.every(letter => letter.style === "opacity:1.000")).toBe(true);
});
