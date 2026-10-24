import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
/** The prototype's tool geometry; only lifecycle and shared-clock wiring change.
 * @param {HTMLCanvasElement} cv
 * @param {HTMLDivElement} tip
 * @param {import('./useScrollProgress').MotionState} FZ */
export function createToolsScene(cv, tip, FZ) {

/* 3D items around the chat box; they leave as the page scrolls and come back for the closing call to action */
const S = { rough: .32, clear: .7 };
const PI = Math.PI;
const rootElement = cv.parentElement;
let renderer;
try {
  const context = cv.getContext('webgl2', { antialias: true, alpha: true });
  if (!context) { cv.hidden = true; return { frame() {}, dispose() {} }; }
  renderer = new THREE.WebGLRenderer({ canvas: cv, context, antialias: true, alpha: true });
} catch { cv.hidden = true; return { frame() {}, dispose() {} }; }
cv.hidden = false;
renderer.setPixelRatio(Math.min(1.75, devicePixelRatio || 1));
renderer.outputColorSpace = THREE.SRGBColorSpace; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.setClearColor(0xffffff, 0);
const scene = new THREE.Scene();
const generator = new THREE.PMREMGenerator(renderer), room = new RoomEnvironment();
const environment = generator.fromScene(room, .04);
scene.environment = environment.texture; room.dispose(); generator.dispose();
const cam = new THREE.PerspectiveCamera(32, 1, .1, 100); cam.position.set(0, 0, 20);
scene.add(new THREE.HemisphereLight(0xffffff, 0xcfe7f9, .6));
const key = new THREE.DirectionalLight(0xffffff, 1.4); key.position.set(-4, 7, 9); scene.add(key);
const root = new THREE.Group(); scene.add(root);
const HALF = Math.tan(THREE.MathUtils.degToRad(16));
const HEX = { or: '#E8590C', ink: '#1b1b1e', blue: '#93CBF1', white: '#ffffff', steel: '#CDD2D8', ice: '#C4E4FA', wood: '#F3EFE8' };
if (S.look === 'points') Object.assign(HEX, { white: '#8EC4EE', steel: '#7E8A98', ice: '#9FD0F4', blue: '#5FA8DE' });
function pal(c) { const col = new THREE.Color(HEX[c]); if (S.pastel) col.lerp(new THREE.Color('#ffffff'), c === 'ink' ? .5 : c === 'or' ? .22 : .3); return col; }
const sg = S.lowpoly ? 7 : S.look === 'lines' ? 16 : 26, ch = S.chunky || 1;
function P(geo, c, p = [0, 0, 0], r = [0, 0, 0]) {
  const g = geo.index ? geo.toNonIndexed() : geo.clone(); geo.dispose(); if (g.attributes.uv) g.deleteAttribute('uv');
  const col = pal(c), n = g.attributes.position.count, arr = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { arr[i * 3] = col.r; arr[i * 3 + 1] = col.g; arr[i * 3 + 2] = col.b; }
  g.setAttribute('color', new THREE.BufferAttribute(arr, 3));
  g.applyMatrix4(new THREE.Matrix4().compose(new THREE.Vector3(...p), new THREE.Quaternion().setFromEuler(new THREE.Euler(...r)), new THREE.Vector3(1, 1, 1)));
  return g;
}
const Cyl = (a, b, h, s = sg) => new THREE.CylinderGeometry(a, b, h, s), Tor = (R, t, s = sg) => new THREE.TorusGeometry(R, t, Math.max(6, s / 3 | 0), s * 2);
const Box = (w, h, d) => new THREE.BoxGeometry(w, h, d), RB = (w, h, d, r) => new RoundedBoxGeometry(w, h, d, S.lowpoly ? 2 : 4, r);
const MODELS = {
  iron: () => [P(new THREE.CapsuleGeometry(.14 * ch, .42, Math.max(3, sg / 4 | 0), sg), 'or', [0, -.18, 0]), P(Tor(.15 * ch, .03 * ch), 'ink', [0, -.02, 0], [PI / 2, 0, 0]), P(Tor(.15 * ch, .03 * ch), 'ink', [0, -.34, 0], [PI / 2, 0, 0]),
    P(Cyl(.05 * ch, .05 * ch, .4), 'steel', [0, .26, 0]), P(new THREE.ConeGeometry(.05 * ch, .18, sg), 'steel', [0, .55, 0]), P(Cyl(.045 * ch, .045 * ch, .14), 'ink', [0, -.5, 0])],
  battery: () => [P(Cyl(.2, .2, .5), 'ink', [0, -.08, 0]), P(Cyl(.205, .205, .2), 'or', [0, .27, 0]), P(Cyl(.08, .08, .06), 'steel', [0, .4, 0])],
  tape: () => [P(Tor(.3, .14), 'blue'), P(Tor(.17, .035), 'white')],
  drill: () => [P(RB(.64, .27, .25, .09), 'or', [0, .22, 0]), P(Cyl(.13, .13, .07), 'ink', [-.33, .22, 0], [0, 0, PI / 2]), P(Cyl(.075 * ch, .09 * ch, .16), 'steel', [.39, .22, 0], [0, 0, PI / 2]),
    P(Cyl(.022 * ch, .022 * ch, .22), 'steel', [.56, .22, 0], [0, 0, PI / 2]), P(RB(.18, .44, .2, .06), 'ink', [-.06, -.08, 0], [0, 0, -.22]), P(RB(.36, .13, .27, .04), 'ink', [-.1, -.34, 0]), P(Box(.05, .1, .06), 'or', [.07, .02, 0])],
  bolt: () => { const a = [P(Cyl(.2, .2, .12, 6), 'steel', [0, .3, 0]), P(Cyl(.08 * ch, .08 * ch, .55), 'steel', [0, -.04, 0])]; for (let i = 0; i < 5; i++) a.push(P(Tor(.085 * ch, .018 * ch), 'steel', [0, -.27 + i * .09, 0], [PI / 2, 0, 0])); return a; },
  cable: () => [P(Tor(.28, .045 * ch), 'white', [0, 0, 0]), P(Tor(.25, .045 * ch), 'white', [.03, -.02, .07], [0, 0, .5]), P(Tor(.31, .045 * ch), 'white', [-.02, .02, -.07], [0, 0, 1.1]), P(RB(.12, .22, .08, .03), 'ink', [.32, -.26, 0]), P(Box(.08, .08, .05), 'steel', [.32, -.41, 0])],
  bin: () => [P(Box(.9, .05, .6), 'blue', [0, -.3, 0]), P(Box(.9, .4, .04), 'blue', [0, -.1, .3]), P(Box(.9, .48, .04), 'blue', [0, -.06, -.3]), P(Box(.04, .44, .6), 'blue', [-.45, -.08, 0]), P(Box(.04, .44, .6), 'blue', [.45, -.08, 0]), P(Box(.3, .1, .015), 'or', [0, -.08, .325])],
  meter: () => [P(RB(.5, .8, .17, .07), 'or'), P(Box(.36, .2, .02), 'ink', [0, .2, .09]), P(Cyl(.11, .11, .04), 'white', [0, -.08, .09], [PI / 2, 0, 0]), P(Box(.02, .09, .02), 'ink', [0, -.04, .115]),
    P(Cyl(.028, .028, .03), 'ink', [-.12, -.3, .09], [PI / 2, 0, 0]), P(Cyl(.028, .028, .03), 'ink', [0, -.3, .09], [PI / 2, 0, 0]), P(Cyl(.028, .028, .03), 'or', [.12, -.3, .09], [PI / 2, 0, 0])]
};

const HERO_D = [['drill', -.84, .52, -1.0, 1.9], ['tape', -.6, -.64, .6, 1.5], ['meter', .82, .56, -.4, 1.8], ['iron', .74, -.56, 0, 1.7], ['battery', -.46, .8, 1.2, .7], ['bin', .97, -.02, -2.2, 1.3], ['bolt', .4, -.86, 1.4, 1.0], ['cable', -.97, -.08, -2.6, 1.3], ['battery', .62, .7, 1.6, .6], ['tape', -.24, -.92, -1.2, 1.0], ['bolt', .28, .76, -2.8, 1.0]];
const HERO_M = [['drill', -.72, .58, -1.0, 1.4], ['meter', .74, .6, -.4, 1.4], ['battery', -.08, .64, 1.0, .6], ['tape', -.66, -.68, .4, 1.3], ['iron', .66, -.66, 0, 1.4], ['bolt', -.1, -.88, 1.4, .7], ['cable', -.92, -.1, -2.4, 1.0]];
const NAMES = { iron: 'Soldering iron', battery: 'AA batteries', tape: 'Duct tape', drill: 'Cordless drill', bolt: 'Socket head screws', cable: 'USB-C cable', bin: 'Parts bin', meter: 'Multimeter' };
const LOCS = { iron: 'Workshop › Workbench', battery: 'Office › Desk drawer', tape: 'Workbench › Middle', drill: 'Garage › Shelf 2', bolt: 'Bin 4 · x40', cable: 'Office › Drawer 1', bin: 'Workshop › Shelf 1', meter: 'Lab › Drawer 2' };
const GEO = {}; const geoOf = t => { if (!GEO[t]) { const pieces = MODELS[t](); GEO[t] = mergeGeometries(pieces); pieces.forEach(g => g.dispose()); } return GEO[t]; };
let items = [], mode = '';
function build(m) {
  items.forEach(it => { root.remove(it.o); it.o.material.dispose(); }); items = [];
  (m === 'm' ? HERO_M : HERO_D).forEach(([type, fx, fy, z, s]) => {
    const mat = new THREE.MeshPhysicalMaterial({ vertexColors: true, roughness: S.rough, clearcoat: S.clear, clearcoatRoughness: .2 });
    const o = new THREE.Mesh(geoOf(type), mat); root.add(o);
    items.push({ type, fx, fy, z, s, o, e: new THREE.Euler(Math.random() * 6, Math.random() * 6, Math.random() * 6), sp: [(Math.random() - .5) * .5, (Math.random() - .5) * .6], ph: Math.random() * 6.28, bs: .35 + Math.random() * .35, hov: 0, kick: 0, dir: new THREE.Vector3(fx, fy, .4).normalize() });
  });
}
let W = 1, H = 1;
function layout() { W = innerWidth; H = innerHeight; renderer.setSize(W, H, false); cam.aspect = W / H; cam.updateProjectionMatrix(); const m = W / H < .9 || W < 820 ? 'm' : 'd'; if (m !== mode) { mode = m; build(m); } }
window.addEventListener('resize', layout); layout();
let pX = -1, pY = -1, onUI = false, hovered = null;
const pointer = e => { pX = e.clientX; pY = e.clientY; onUI = !!(e.target.closest && e.target.closest('a,button,textarea,form,.nav,footer')); };
window.addEventListener('pointermove', pointer, { passive: true });
const press = e => { if (hovered && !FZ.reduce && !(e.target.closest && e.target.closest('a,button,textarea,form'))) hovered.kick = 1; };
window.addEventListener('pointerdown', press);
const pv = new THREE.Vector3();
let lastTime = performance.now(), elapsed = 0, lost = false;
const contextLost = event => { event.preventDefault(); lost = true; cv.hidden = true; tip.style.opacity = 0; };
const contextRestored = () => { lost = false; cv.hidden = false; };
cv.addEventListener('webglcontextlost', contextLost);
cv.addEventListener('webglcontextrestored', contextRestored);
function frame(now) {
  const vis = Math.max(FZ.heroVis, FZ.endVis), dt = Math.min(.05, (now - lastTime) / 1000);
  lastTime = now;
  if (!FZ.reduce) elapsed += dt;
  const t = elapsed;
  cv.style.opacity = vis; if (vis < .01 || document.hidden || lost) { tip.style.opacity = 0; rootElement.style.cursor = ''; hovered = null; return; }
  root.rotation.y = FZ.tx * .22; root.rotation.x = FZ.ty * .12; root.updateMatrixWorld();
  const away = 1 - vis;
  hovered = null; let best = 1e9;
  for (const it of items) {
    const hz = HALF * (20 - it.z), bob = FZ.reduce ? 0 : Math.sin(t * it.bs + it.ph) * .18;
    it.o.position.set(it.fx * hz * cam.aspect + it.dir.x * away * 6, it.fy * hz + bob + it.dir.y * away * 6 + Math.sin(it.kick * PI) * .4, it.z + away * 6);
    it.kick *= .94; it.hov += ((it === hovered ? 1 : 0) - it.hov) * .18;
    if (!FZ.reduce) { it.e.x += it.sp[0] * dt * (1 + it.kick * 8); it.e.y += it.sp[1] * dt * (1 + it.kick * 8); }
    it.o.rotation.copy(it.e); it.o.scale.setScalar(it.s * (1 + .2 * it.hov));
    if (!onUI && pX >= 0) {
      pv.copy(it.o.position).applyMatrix4(root.matrixWorld).project(cam);
      const x = (pv.x + 1) / 2 * W, y = (1 - pv.y) / 2 * H, r = it.s * .55 * H / (2 * HALF * (20 - it.z)) + 8, d = Math.hypot(x - pX, y - pY);
      if (d < r && d < best) { best = d; hovered = it; }
    }
  }
  items.forEach(it => { it.hov += ((it === hovered ? 1 : 0) - it.hov) * .1; });
  if (hovered && vis > .5) { tip.querySelector('b').textContent = NAMES[hovered.type]; tip.querySelector('span').textContent = LOCS[hovered.type]; tip.style.left = pX + 'px'; tip.style.top = pY + 'px'; tip.style.opacity = 1; rootElement.style.cursor = 'pointer'; }
  else { tip.style.opacity = 0; rootElement.style.cursor = ''; }
  renderer.render(scene, cam);
}
return { frame, dispose() {
  window.removeEventListener('resize', layout);
  window.removeEventListener('pointermove', pointer);
  window.removeEventListener('pointerdown', press);
  cv.removeEventListener('webglcontextlost', contextLost);
  cv.removeEventListener('webglcontextrestored', contextRestored);
  rootElement.style.cursor = '';
  tip.style.opacity = 0;
  items.forEach(it => it.o.material.dispose());
  Object.values(GEO).forEach(g => g.dispose());
  // React Strict Mode reuses this canvas when replaying effects. Releasing all
  // resources is sufficient; forcing context loss would break the next mount.
  environment.dispose(); renderer.dispose();
} };
}
