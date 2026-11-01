import type { SetupDraft, SetupPath, SetupStep } from "@/lib/web-onboarding";

type Camera = { x: number; y: number; scale: number };
type Point = [number, number, number];
type Palette = [string, string, string];
export const CAMERAS: Record<SetupStep, Camera> = {
  welcome: { x: 320, y: 360, scale: 1.1 }, choose: { x: 320, y: 360, scale: 1.05 },
  org: { x: 320, y: 370, scale: 1.15 }, purpose: { x: 320, y: 372, scale: 1.3 },
  inventory: { x: 320, y: 368, scale: 1.45 }, world: { x: 320, y: 360, scale: 1.22 },
  setup: { x: 320, y: 330, scale: 0.7 },
};
const TEAM: Palette = ["#FFFFFF", "#D6D1C9", "#E7E3DC"];
const PERSONAL: Palette = ["#FFFFFF", "#CFE0D4", "#E2EEE6"];
const WORKSPACE: Palette = ["#DDE7FB", "#A3B8E2", "#C2D2F1"];
const INVENTORY: Palette = ["#FCE3D3", "#D99A76", "#EDBB9C"];
const CUBES: [number, number, Palette][] = [
  [-36, -38, ["#FFFFFF", "#BDB8B0", "#DDD9D2"]], [-14, -40, ["#E8590C", "#9C3A07", "#C24A0A"]],
  [-38, -14, ["#FDBA8C", "#C98458", "#E39E70"]], [-12, -16, ["#B9CAEE", "#7F95C4", "#9DB1DD"]],
  [-24, -2, ["#D4D1CB", "#8F8B84", "#B3AFA8"]], [0, -26, ["#FFFFFF", "#BDB8B0", "#DDD9D2"]],
  [-2, -2, ["#FDBA8C", "#C98458", "#E39E70"]],
];
const clamp = (n: number) => Math.max(0, Math.min(1, n));
const ease = (n: number) => { const k = clamp(n); return k < 0.5 ? 4 * k ** 3 : 1 - (-2 * k + 2) ** 3 / 2; };
const out = (n: number) => 1 - (1 - clamp(n)) ** 3;
const back = (n: number) => 1 + 2.5 * (clamp(n) - 1) ** 3 + 1.5 * (clamp(n) - 1) ** 2;
const mix = (a: number, b: number, k: number) => a + (b - a) * k;
const escape = (s: string) => s.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);

function geometry(camera: Camera) {
  const project = (x: number, y: number, z: number) => [camera.x + (x - y) * Math.cos(Math.PI / 6) * camera.scale, camera.y + ((x + y) / 2 - z) * camera.scale];
  const polygon = (points: Point[], fill: string, attributes = "") => `<path d="M${points.map(p => project(...p).map(n => n.toFixed(1)).join(" ")).join("L")}Z" fill="${fill}" ${attributes}/>`;
  const box = (x: number, y: number, z: number, w: number, d: number, h: number, colors: Palette, attributes = "") => {
    const a = x - w / 2, b = x + w / 2, e = y - d / 2, f = y + d / 2, top = z + h;
    return polygon([[a, f, z], [b, f, z], [b, f, top], [a, f, top]], colors[1], attributes) +
      polygon([[b, e, z], [b, f, z], [b, f, top], [b, e, top]], colors[2], attributes) +
      polygon([[a, e, top], [b, e, top], [b, f, top], [a, f, top]], colors[0], attributes);
  };
  return { project, polygon, box };
}

function tag(x: number, y: number, label: string, color: string) {
  // Keep long valid custom names inside the 640px panel; the full name is in title.
  const visible = label.length > 26 ? `${label.slice(0, 25)}…` : label;
  const width = 26 + visible.length * 7.4;
  x = Math.max(width / 2 + 12, Math.min(628 - width / 2, x));
  return `<g><title>${escape(label)}</title><rect x="${x - width / 2}" y="${y - 15}" width="${width}" height="30" rx="15" fill="#FFFFFF" fill-opacity=".96" stroke="#E3E0DA"/><circle cx="${x - width / 2 + 14}" cy="${y}" r="4" fill="${color}"/><text x="${x - width / 2 + 24}" y="${y + 4.5}" font-size="13" font-weight="500" fill="#111112">${escape(visible)}</text></g>`;
}

export function miniModel(path: SetupPath) {
  const { box, polygon } = geometry({ x: 0, y: 0, scale: 0.36 });
  return box(0, 0, 0, 200, 200, 22, path === "team" ? TEAM : PERSONAL) +
    polygon([[-100, -100, 22], [100, -100, 22], [100, 100, 22], [-100, 100, 22]], "none", `stroke="${path === "team" ? "#E8590C" : "#3E9B63"}" stroke-width="2"`) +
    box(-20, -20, 22, 110, 110, 46, WORKSPACE) + (path === "team" ? box(-20, -20, 68, 70, 70, 12, INVENTORY) : "");
}

export class WorldModel {
  private camera = CAMERAS.welcome;
  private from = this.camera;
  private target = this.camera;
  private cameraAt = 0;
  private platformAt = -10000;
  private workspaceAt = -10000;
  private inventoryAt = -10000;
  private frameId = 0;
  private draft: SetupDraft | null = null;
  private hover: SetupPath | null = null;
  private reduced = false;
  private disposed = false;

  constructor(private svg: SVGSVGElement) {}

  update(draft: SetupDraft, hover: SetupPath | null, reduced: boolean) {
    const now = performance.now(), previous = this.draft;
    if (!previous || previous.step !== draft.step) {
      this.from = this.camera;
      this.target = CAMERAS[draft.step];
      this.cameraAt = previous ? now : -10000;
    }
    if (previous && !previous.path && draft.path) this.platformAt = now;
    if (previous && !previous.purpose && draft.purpose) this.workspaceAt = now;
    if (previous && !previous.inventory && draft.inventory) this.inventoryAt = now;
    this.draft = draft; this.hover = hover; this.reduced = reduced;
    cancelAnimationFrame(this.frameId);
    this.draw(now);
  }

  dispose() { this.disposed = true; cancelAnimationFrame(this.frameId); }

  private draw = (now: number) => {
    if (this.disposed || !this.draft) return;
    const draft = this.draft, k = this.reduced ? 1 : ease((now - this.cameraAt) / 800);
    this.camera = { x: mix(this.from.x, this.target.x, k), y: mix(this.from.y, this.target.y, k), scale: mix(this.from.scale, this.target.scale, k) };
    const { project: p, box, polygon } = geometry(this.camera), scale = this.camera.scale;
    let markup = '<defs><radialGradient id="onboarding-glow"><stop offset="0" stop-color="#111112" stop-opacity=".10"/><stop offset="1" stop-color="#111112" stop-opacity="0"/></radialGradient></defs>';
    if (draft.step === "welcome") {
      const phase = this.reduced ? 2.1 : now / 1000 % 4.2, line = mix(90, 560, ease((phase - 0.4) / 1.8));
      if (!this.reduced && phase > 0.3 && phase < 2.4) markup += `<rect x="40" y="${line - 1}" width="560" height="2" fill="#E8590C" opacity=".8"/>`;
      for (const [x, y] of [[150, 170], [470, 140], [220, 470], [450, 430], [110, 330], [520, 300], [320, 220], [330, 540], [260, 330], [400, 360]]) {
        const hit = line > y && phase > 0.4 && phase < 3.8;
        markup += `<circle cx="${x}" cy="${y}" r="3.2" fill="${hit ? "#E8590C" : "#C4C1BA"}"/>`;
        if (hit) markup += `<rect x="${x - 10}" y="${y - 10}" width="20" height="20" rx="4" fill="none" stroke="#E8590C" stroke-width="1.6"/>`;
      }
    } else if (draft.step === "choose" && !draft.path && !this.hover) {
      const dashed = 'stroke="#B9B5AE" stroke-width="1.4" stroke-dasharray="6 6" stroke-linejoin="round"';
      markup += polygon([[-100, -100, 0], [100, -100, 0], [100, 100, 0], [-100, 100, 0]], "none", dashed);
      markup += polygon([[-75, -75, 46], [35, -75, 46], [35, 35, 46], [-75, 35, 46]], "none", dashed);
      for (const [x, y] of [[-75, 35], [35, 35], [35, -75]]) {
        const bottom = p(x, y, 0), top = p(x, y, 46);
        markup += `<path d="M${bottom.join(" ")}L${top.join(" ")}" fill="none" ${dashed}/>`;
      }
      const center = p(0, 0, 0);
      markup += `<text x="${center[0]}" y="${center[1] + 150 * scale}" text-anchor="middle" font-size="16" fill="#8A8782">Your world builds here as you answer</text>`;
    } else {
      const path = draft.step === "choose" && this.hover ? this.hover : draft.path;
      if (path) {
        const team = path === "team", preview = draft.step === "choose", outline = team ? "#E8590C" : "#3E9B63";
        const alpha = this.reduced ? 1 : out((now - this.platformAt) / 600), center = p(0, 0, 0);
        markup += `<ellipse cx="${center[0]}" cy="${center[1] + 18 * scale}" rx="${240 * scale}" ry="${120 * scale}" fill="url(#onboarding-glow)" opacity="${alpha}"/>`;
        markup += `<g opacity="${alpha}">${box(0, 0, 0, 200, 200, 22, team ? TEAM : PERSONAL)}`;
        markup += polygon([[-100, -100, 22], [100, -100, 22], [100, 100, 22], [-100, 100, 22]], "none", `stroke="${outline}" stroke-width="1.4" stroke-linejoin="round"`);
        markup += polygon([[-100, 100, 0], [100, 100, 0], [100, -100, 0]], "none", `stroke="${outline}" stroke-opacity=".35" stroke-width="1"`) + "</g>";
        let top = 22;
        if (draft.purpose || preview) {
          const height = preview || this.reduced ? 46 : 46 * Math.max(0.02, back((now - this.workspaceAt) / 700));
          markup += `<g opacity="${preview ? 0.5 : 1}">${box(-20, -20, 22, 110, 110, height, WORKSPACE)}</g>`;
          top += height;
          if (!preview) for (const [x, y] of [[62, -50], [-50, 62]]) {
            const ghost = this.reduced ? 1 : out((now - this.workspaceAt - 1000) / 600);
            markup += polygon([[x - 28, y - 28, 22.5], [x + 28, y - 28, 22.5], [x + 28, y + 28, 22.5], [x - 28, y + 28, 22.5]], "none", `stroke="#8A8782" stroke-opacity="${0.6 * ghost}" stroke-dasharray="4 4" stroke-width="1.2"`);
          }
        }
        const workspaceTop = top;
        if (draft.inventory || (preview && team)) {
          const height = preview || this.reduced ? 12 : 12 * Math.max(0.05, back((now - this.inventoryAt) / 600));
          markup += `<g opacity="${preview ? 0.5 : 1}">${box(-20, -20, top, 70, 70, height, INVENTORY)}</g>`;
          top += height;
          if (!preview) for (const cube of [...CUBES].sort((a, b) => a[0] + a[1] - b[0] - b[1])) {
            const i = CUBES.indexOf(cube), progress = this.reduced ? 1 : clamp((now - this.inventoryAt - 800 - i * 120) / 450);
            if (!progress) continue;
            const offset = progress < 0.75 ? (1 - progress / 0.75) * 80 : Math.sin((progress - 0.75) / 0.25 * Math.PI) * 6;
            const size = 12 + i % 3 * 2;
            markup += box(cube[0], cube[1], top + offset, size, size, size, cube[2], `opacity="${clamp(progress * 3)}"`);
          }
        }
        if (!preview) {
          let point = p(0, 100, 0);
          markup += tag(point[0] - 70 * scale, point[1] + 26, team ? draft.orgName || "Your organization" : "Personal", outline);
          if (draft.purpose) { point = p(-20, -20, workspaceTop); markup += tag(point[0] + 95 * scale, point[1] - 10 * scale, draft.purpose, "#7F95C4"); }
          if (draft.inventory) { point = p(-20, -20, top + 30); markup += tag(point[0] - 70 * scale, point[1] - 30 * scale, draft.inventory, "#D99A76"); }
        }
      }
    }
    // Only generated SVG geometry and XML-escaped text enter this isolated node.
    this.svg.innerHTML = markup;
    const animating = draft.step === "welcome" || now - this.cameraAt < 800 || now - this.platformAt < 600 || now - this.workspaceAt < 1600 || now - this.inventoryAt < 2000;
    if (!this.reduced && animating) this.frameId = requestAnimationFrame(this.draw);
  };
}
