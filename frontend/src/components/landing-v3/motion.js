// Faithful numeric timeline/layout port of docs/landing-v3/landing-prototype.html.
// React owns the scene markup; this module only paints cached DOM references.
import { TAGS } from './sceneData';
/** @param {HTMLElement} root
 * @param {import('./useScrollProgress').MotionState} FZ
 * @param {(key: string, element: HTMLElement, reduced: boolean) => number | null} sample */

export function createLandingMotion(root, FZ, sample) {
  // Cache scoped element references once; animation never updates React state.
  const cache = new Map();
  const $ = s => { if (!cache.has(s)) cache.set(s, root.querySelector(s)); return cache.get(s); };
  const $$ = s => [...root.querySelectorAll(s)];
  let active = true;
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const ease = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  const lerp = (a, b, k) => a + (b - a) * k;
  const win = (t, a0, a1, b0, b1) => Math.min(a0 < 0 ? 1 : seg(t, a0, a1), b0 > 99 ? 1 : 1 - seg(t, b0, b1));
  const pointer = e => { FZ.mx = e.clientX / innerWidth - .5; FZ.my = e.clientY / innerHeight - .5; };
  window.addEventListener('pointermove', pointer, { passive: true });

  /* chat box */
  const ask = $('#ask');
  const prompts = ['Start an inventory for my garage', 'Create a Workshop space for my robotics team', 'Add 20 M3 screws, a soldering iron and 2 multimeters', 'Snap a shelf and list everything on it', 'Import my parts spreadsheet'];
  let pi = 0, pc = 0, pd = 1;
  let typedAt = 0;
  function typePlaceholder(now) {
    if (FZ.reduce || FZ.heroVis < .01 || now - typedAt < 55) return;
    typedAt = now;
    if (document.activeElement === ask || ask.value) return;
    const text = prompts[pi]; pc += pd;
    if (pc > text.length + 18) pd = -1;
    if (pc <= 0 && pd < 0) { pd = 1; pi = (pi + 1) % prompts.length; }
    ask.placeholder = text.slice(0, clamp(pc, 0, text.length));
  }

  /* text that rises in, drifts up while held, and leaves upward */
  function setText(el, p, a0, a1, b0, b1) {
    const i = a0 < 0 ? 1 : seg(p, a0, a1), o = b0 > 99 ? 0 : seg(p, b0, b1), hp = seg(p, a1, b0 > 99 ? 1 : b0), v = Math.min(i, 1 - o);
    const y = (1 - ease(i)) * 90 - ease(o) * 90 + (.5 - hp) * 40;
    el.style.opacity = v; el.style.transform = `translate3d(0,${y.toFixed(1)}px,0) rotateX(${((1 - i) * -24 + o * 18).toFixed(1)}deg)`;
    el.style.pointerEvents = v > .5 ? 'auto' : 'none'; el.style.visibility = v < .01 ? 'hidden' : 'visible';
  }
  const R = (el, r) => { el.style.left = r.x + 'px'; el.style.top = r.y + 'px'; el.style.width = r.w + 'px'; el.style.height = r.h + 'px'; };
  const LR = (a, b, k) => ({ x: lerp(a.x, b.x, k), y: lerp(a.y, b.y, k), w: lerp(a.w, b.w, k), h: lerp(a.h, b.h, k) });
  const mixc = (a, b, k) => a.map((v, i) => lerp(v, b[i], k));
  const rgb = c => `rgb(${c[0] | 0},${c[1] | 0},${c[2] | 0})`;
  let W, H, mob, C, left;

  /* ================= A: capture -> memory -> exact place -> ask ================= */
  const sA = $('#storyA'), stA = $('#stA'), M = $('#m'), rev = $('#review'), foundC = $('#foundC'), crumbs = $$('#crumbs span'), crumbBox = $('#crumbs');
  const A0 = $('#a0'), A = [1, 2, 3, 4].map(i => $('#a' + i)), LY = ['#lComp', '#lPhoto', '#lCard', '#lCab', '#lChat'].map($);
  const tagEls = $$('#tags .tg');
  const orbit = $('#orbit');
  const nodeEls = $$('#graph .node').map((d, i) => ({d, ln: $$('#graph line')[i], tx: $$('#graph text')[i], yo: [-130, -90, 10, 120, 110, -10][i]}));
  /* parts cabinet */
  const cab = $('#cab'), COLS = 8, ROWS = 6, DW = 96, DH = 58, GAP = 8, CW = COLS * DW + (COLS - 1) * GAP, CH = ROWS * DH + (ROWS - 1) * GAP;
  cab.style.width = CW + 'px'; cab.style.height = CH + 'px';
  const drF40 = $('[data-drawer="40"]');
  const row5Y = 4 * (DH + GAP) + DH / 2, f40X = 7 * (DW + GAP) + DW / 2;
  Object.assign($('#rowBox').style, { left: '-8px', top: (4 * (DH + GAP) - 7) + 'px', width: (CW + 16) + 'px', height: (DH + 14) + 'px' });
  Object.assign($('#drBox').style, { left: (7 * (DW + GAP) - 5) + 'px', top: (4 * (DH + GAP) - 5) + 'px', width: (DW + 10) + 'px', height: (DH + 10) + 'px' });

  let KA = [], gC = { x: 0, y: 0 }, gR = 330;
  function layoutA() {
    const tw = Math.min(450, C * .4);
    A.forEach(el => el.style.transform = 'none');
    [0, 1, 3].forEach(i => { const el = A[i]; if (mob) { el.style.left = '16px'; el.style.width = (W - 32) + 'px'; el.style.top = '80px'; } else { el.style.left = left + 'px'; el.style.width = tw + 'px'; el.style.top = Math.max(84, (H - el.offsetHeight) / 2) + 'px'; } });
    A[2].style.left = '16px'; A[2].style.width = (W - 32) + 'px'; A[2].style.top = (mob ? 80 : Math.max(84, H * .1)) + 'px';
    let k0, k1, k2, k3, k4;
    { const w = Math.min(720, W - 32), h = mob ? 128 : 136; k0 = { x: (W - w) / 2, y: H / 2 - h / 2 + (mob ? 26 : 22), w, h }; A0.style.transform = 'none'; A0.style.left = '16px'; A0.style.width = (W - 32) + 'px'; A0.style.top = (k0.y - A0.offsetHeight - 22) + 'px'; }
    if (mob) {
      const w = W - 32, h = w / 1.833, y = Math.max(80 + A[0].offsetHeight + 20, H - h - 150); k1 = { x: 16, y, w, h };
      gC = { x: W / 2, y: H * .64 }; gR = Math.min(150, W * .36); k2 = { x: gC.x - 150, y: gC.y - 44, w: 300, h: 88 };
      const y3 = 80 + A[2].offsetHeight + 18; k3 = { x: 12, y: y3, w: W - 24, h: H - y3 - 86 };
      const y4 = 80 + A[3].offsetHeight + 18; k4 = { x: 16, y: y4, w: W - 32, h: H - y4 - 18 };
    } else {
      const w = Math.min(620, C * .52), h = w / 1.833; k1 = { x: left + C - w, y: (H - h) / 2 + 10, w, h };
      gC = { x: left + C * .75, y: H / 2 + 10 }; gR = Math.min(300, C * .23); k2 = { x: gC.x - 180, y: gC.y - 48, w: 360, h: 96 };
      const y3 = Math.max(84, H * .1) + A[2].offsetHeight + 26; k3 = { x: left, y: y3, w: C, h: H - y3 - 74 };
      const w4 = Math.min(440, C * .42), h4 = Math.min(480, H - 150); k4 = { x: left + C - w4, y: (H - h4) / 2 + 10, w: w4, h: h4 };
    }
    KA = [k0, k1, k2, k3, k4];
    Object.assign(k0, { r: 26, bg: [255, 255, 255], rx: 0, ry: 0 });
    Object.assign(k1, { r: 22, bg: [20, 20, 22], rx: 6, ry: -12 }); Object.assign(k2, { r: 18, bg: [255, 255, 255], rx: 0, ry: 0 });
    Object.assign(k3, { r: 26, bg: [234, 243, 251], rx: 0, ry: 0 }); Object.assign(k4, { r: 24, bg: [255, 255, 255], rx: 4, ry: -10 });
    orbit.style.left = (gC.x - (mob ? 90 : 120)) + 'px'; orbit.style.top = (gC.y - (mob ? 90 : 120)) + 'px'; orbit.style.width = orbit.style.height = (mob ? 180 : 240) + 'px';
    crumbBox.style.left = '16px'; crumbBox.style.right = '16px'; crumbBox.style.top = (k3.y + k3.h + 18) + 'px';
  }
  const TL = [[0, 0], [.02, 0], [.085, 1], [.21, 1], [.28, 2], [.44, 2], [.5, 3], [.68, 3], [.74, 4], [1, 4]];
  const Q = 'Where are my batteries?';
  function renderA(p) {
    let i = 0; while (i < TL.length - 2 && p > TL[i + 1][0]) i++;
    const [ta, a] = TL[i], [tb, b] = TL[i + 1], k = a === b ? 0 : ease(seg(p, ta, tb)), Ka = KA[a], Kb = KA[b];
    const hold = a === b ? (.5 - seg(p, ta, tb)) * 46 : 0;
    const r = LR(Ka, Kb, k); R(M, r);
    const sw = a === b ? 0 : Math.sin(Math.PI * k);
    M.style.borderRadius = lerp(Ka.r, Kb.r, k) + 'px';
    M.style.background = rgb(mixc(Ka.bg, Kb.bg, k));
    M.style.boxShadow = `0 ${lerp(20, 40, sw)}px ${lerp(50, 90, sw)}px rgba(17,17,18,${(.16 + .1 * sw).toFixed(2)})`;
    M.style.transform = `translate3d(0,${hold.toFixed(1)}px,${(sw * 120).toFixed(1)}px) rotateX(${(lerp(Ka.rx, Kb.rx, k) - FZ.ty * 7).toFixed(2)}deg) rotateY(${(lerp(Ka.ry, Kb.ry, k) + FZ.tx * 10 + sw * 14).toFixed(2)}deg)`;
    const lv = [1 - seg(p, .03, .06), win(p, .03, .06, .23, .27), win(p, .25, .28, .45, .48), win(p, .47, .5, .68, .71), seg(p, .7, .74)];
    LY.forEach((el, j) => { el.style.opacity = lv[j]; el.style.visibility = lv[j] < .01 ? 'hidden' : 'visible'; el.style.pointerEvents = lv[j] > .5 ? 'auto' : 'none'; });
    M.style.pointerEvents = 'auto';
    /* stage colour */
    const dark = win(p, .23, .27, .44, .48), tint = seg(p, .68, .74), bga = seg(p, 0, .07);
    const bc = mixc(mixc([255, 255, 255], [238, 246, 253], tint), [11, 11, 13], dark); stA.style.background = `rgba(${bc[0] | 0},${bc[1] | 0},${bc[2] | 0},${bga.toFixed(3)})`;
    FZ.heroVis = 1 - seg(p, 0, .075);
    stA.dataset.dark = dark > .5 ? 1 : 0;
    setText(A0, p, -1, 0, .008, .045); setText(A[0], p, .045, .09, .22, .26); setText(A[1], p, .26, .3, .43, .47); setText(A[2], p, .48, .52, .66, .69); setText(A[3], p, .71, .75, 100, 101);
    /* capture: scan, tags, counters, floating review panel */
    const sc = seg(p, .065, .14);
    $('#scan').style.top = sc * 100 + '%'; $('#scan').style.opacity = p > .065 && p < .142 ? 1 : 0;
    $('#scanfade').style.height = sc * 100 + '%'; $('#scanfade').style.opacity = 1 - seg(p, .15, .2);
    let n = 0, warn = 0;
    tagEls.forEach((t, j) => { const o = seg(p, .09 + j * .013, .105 + j * .013); t.style.opacity = o; t.style.transform = `scale(${lerp(.85, 1, o)})`; if (o > .5) { n++; if (TAGS[j][1] < .8) warn = 1; } });
    $('#cntA').textContent = n; $('#cntB').textContent = warn; $('#pcapR').textContent = n === 6 ? '6 OBJECTS FOUND' : 'SCANNING';
    const ro = win(p, .15, .175, .21, .24);
    rev.style.opacity = ro; rev.style.visibility = ro < .01 ? 'hidden' : 'visible';
    const k1 = KA[1], rx0 = mob ? W - 16 - 240 : k1.x - 70, ry0 = mob ? k1.y + k1.h - 30 : k1.y + k1.h - 150;
    rev.style.left = rx0 + 'px'; rev.style.top = ry0 + 'px';
    rev.style.transform = `perspective(1200px) translate3d(0,${((1 - ro) * 40).toFixed(1)}px,${(60 * ro).toFixed(1)}px) rotateX(${(4 - FZ.ty * 6).toFixed(2)}deg) rotateY(${(-10 + FZ.tx * 10).toFixed(2)}deg)`;
    /* memory graph */
    const gv = win(p, .27, .3, .44, .48);
    orbit.style.opacity = gv * .9; orbit.style.transform = `rotateX(70deg) scale(${lerp(.6, 1, gv)})`;
    const rot = p * 6 + FZ.tx * .8, f = 900;
    nodeEls.forEach((nd, j) => {
      const o = Math.min(seg(p, .28 + j * .012, .31 + j * .012), 1 - seg(p, .44, .48));
      const ang = j / nodeEls.length * Math.PI * 2 + rot, x = Math.cos(ang) * gR, z = Math.sin(ang) * gR * .6, y = nd.yo * (mob ? .8 : 1) - FZ.ty * 30;
      const spread = 1 + seg(p, .44, .48) * .6, s = f / (f - z), sx = gC.x + x * s * spread, sy = gC.y + y * s * spread, depth = (z / (gR * .6) + 1) / 2;
      nd.d.style.opacity = o * (.45 + .55 * depth); nd.d.style.visibility = o < .01 ? 'hidden' : 'visible';
      nd.d.style.transform = `translate(${sx.toFixed(1)}px,${sy.toFixed(1)}px) translate(-50%,-50%) scale(${(s * (mob ? .82 : 1)).toFixed(3)})`; nd.d.style.zIndex = z > 0 ? 4 : 1;
      nd.ln.setAttribute('x1', gC.x); nd.ln.setAttribute('y1', gC.y); nd.ln.setAttribute('x2', sx); nd.ln.setAttribute('y2', sy); nd.ln.style.opacity = o * (.5 + .5 * depth);
      nd.tx.setAttribute('x', (gC.x + sx) / 2 + 6); nd.tx.setAttribute('y', (gC.y + sy) / 2 - 4); nd.tx.style.opacity = o * depth;
    });
    /* cabinet zoom */
    const K3 = KA[3], base = Math.min(K3.w * .82 / CW, K3.h * .8 / CH);
    const z0 = ease(seg(p, .47, .52)), z1 = ease(seg(p, .52, .56)), z2 = ease(seg(p, .565, .61));
    let sc2 = lerp(base * .88, base, z0), rx = lerp(18, 10, z0), ry = lerp(-20, -12, z0), fx = CW / 2, fy = CH / 2;
    sc2 = lerp(sc2, base * 1.2, z1); rx = lerp(rx, 5, z1); ry = lerp(ry, -6, z1); fy = lerp(fy, row5Y, z1);
    sc2 = lerp(sc2, base * (mob ? 3.4 : 2.9), z2); rx = lerp(rx, 2, z2); ry = lerp(ry, -3, z2); fx = lerp(fx, f40X, z2);
    cab.style.transform = `scale(${sc2.toFixed(4)}) rotateX(${(rx - FZ.ty * 5).toFixed(2)}deg) rotateY(${(ry + FZ.tx * 7).toFixed(2)}deg) translate(${(CW / 2 - fx).toFixed(1)}px,${(CH / 2 - fy).toFixed(1)}px)`;
    $('#rowBox').style.opacity = win(p, .53, .55, .68, .71); $('#drBox').style.opacity = win(p, .58, .595, .68, .71);
    drF40.style.transform = `translateZ(${(seg(p, .585, .61) * 40).toFixed(1)}px)`; drF40.classList.toggle('hit', p > .595);
    const fc = win(p, .605, .625, .68, .71);
    foundC.style.opacity = fc; foundC.style.visibility = fc < .01 ? 'hidden' : 'visible';
    foundC.style.left = (K3.x + (mob ? 14 : 28)) + 'px'; foundC.style.top = (K3.y + K3.h - (mob ? 100 : 120)) + 'px';
    foundC.style.transform = `perspective(900px) translate3d(0,${((1 - fc) * 30).toFixed(1)}px,${(fc * 50).toFixed(1)}px) rotateY(${(8 + FZ.tx * 8).toFixed(2)}deg)`;
    const cut = [.5, .5, .515, .515, .53, .53, .55, .55, .59, .59, .615];
    crumbs.forEach((c, j) => c.classList.toggle('on', p > cut[j] && p < .69));
    /* ask */
    $('#qt').textContent = FZ.reduce ? Q : Q.slice(0, Math.round(seg(p, .76, .81) * Q.length));
    [['#ans', .83], ['#ic1', .85], ['#ic2', .87], ['#tgs', .89]].forEach(([s, t]) => $(s).classList.toggle('hid', p < t));
  }

  /* ================= who ================= */
  const rowsEl = $('#rows');
  const MR = $$('#rows .mrow').map((el, i) => ({el, x: -Math.random() * 300, dir: i ? 1 : -1, w: 0}));

  /* ================= business ================= */
  const stB = $('#biz'), b1 = $('#b1'), SP = ['#sp1', '#sp2', '#sp3'].map($), team = $('#team');
  let bC = { x: 0, y: 0 };
  /* ================= app ================= */
  const appS = $('#app'), c1 = $('#c1'), ring = $('#ring'), caps = $$('#caps span');
  const PH = $$('#ring .ph');
  let phW = 0, phH = 0, step = 26;
  /* ================= sync ================= */
  const syncS = $('#sync'), d1 = $('#d1'), lap = $('#lap'), sph = $('#sph'), fly = $('#fly');
  let LAP = {}, SPH = {};

  function layout() {
    W = innerWidth; H = innerHeight; mob = W < 820; C = Math.min(1200, W - (mob ? 32 : 64)); left = (W - C) / 2;
    layoutA();
    /* business */
    [b1, d1].forEach(el => { el.style.transform = 'none'; if (mob) { el.style.left = '16px'; el.style.width = (W - 32) + 'px'; el.style.top = '80px'; } else { el.style.left = left + 'px'; el.style.width = Math.min(460, C * .42) + 'px'; el.style.top = Math.max(84, (H - el.offsetHeight) / 2) + 'px'; } });
    bC = mob ? { x: W / 2, y: Math.max(80 + b1.offsetHeight + 150, H * .68) } : { x: left + C * .72, y: H / 2 };
    /* app */
    c1.style.transform = 'none'; c1.style.left = '16px'; c1.style.width = (W - 32) + 'px'; c1.style.top = (mob ? 80 : Math.max(80, H * .08)) + 'px';
    const top = (mob ? 80 : Math.max(80, H * .08)) + c1.offsetHeight + 22; phH = Math.min(mob ? 420 : 520, H - top - 76); phW = phH * .49;
    ring.style.top = top + 'px'; PH.forEach(d => { d.style.width = phW + 'px'; d.style.height = phH + 'px'; d.style.marginLeft = (-phW / 2) + 'px'; });
    $('#caps').style.top = (top + phH + 18) + 'px'; step = mob ? 32 : 24;
    /* sync */
    if (mob) { const lw = W - 60, lh = lw * .62, y = Math.max(80 + d1.offsetHeight + 40, H - lh - 60); LAP = { x: 44, y, w: lw, h: lh }; }
    else { const lw = Math.min(560, C * .5), lh = lw * .62; LAP = { x: left + C - lw, y: (H - lh) / 2 - 10, w: lw, h: lh }; }
    Object.assign(lap.style, { left: LAP.x + 'px', top: LAP.y + 'px', width: LAP.w + 'px', height: LAP.h + 'px' });
    lap.querySelector('.lid').style.height = LAP.h + 'px'; lap.querySelector('.base').style.top = LAP.h + 'px';
    const sh = LAP.h * (mob ? .9 : 1.0), sw = sh * .49; SPH = { x: LAP.x - sw * (mob ? .35 : .9), y: LAP.y + LAP.h * .2, w: sw, h: sh };
    Object.assign(sph.style, { left: SPH.x + 'px', top: SPH.y + 'px', width: SPH.w + 'px', height: SPH.h + 'px' });
  }

  function renderB(p) {
    setText(b1, p, -.7, -.25, 100, 101);
    const k = ease(seg(p, .1, .55)), inn = ease(seg(p, -.8, -.1));
    const F = mob ? [[-70, -95, -9, -50], [40, -10, 5, 0], [-40, 85, -4, 50]] : [[-170, -120, -10, -60], [60, -10, 5, 0], [-90, 130, -5, 60]];
    SP.forEach((el, i) => {
      const [dx, dy, rz, z] = F[i], x = bC.x + lerp(dx, (i - 1) * 10, k), y = bC.y + lerp(dy, -60 + i * 10, k) + (1 - inn) * 200;
      el.style.left = '0'; el.style.top = '0';
      el.style.opacity = inn * (1 - k * .55);
      el.style.transform = `perspective(1200px) translate3d(${(x - el.offsetWidth / 2).toFixed(1)}px,${(y - el.offsetHeight / 2).toFixed(1)}px,${lerp(z, -80 - i * 30, k).toFixed(1)}px) rotateX(${(lerp(10, 4, k) - FZ.ty * 6).toFixed(1)}deg) rotateY(${(lerp(-20, -6, k) + FZ.tx * 10).toFixed(1)}deg) rotateZ(${lerp(rz, 0, k).toFixed(1)}deg)`;
    });
    const tv = ease(seg(p, .4, .65));
    team.style.left = '0'; team.style.top = '0'; team.style.opacity = tv; team.style.visibility = tv < .01 ? 'hidden' : 'visible';
    team.style.transform = `perspective(1200px) translate3d(${(bC.x - team.offsetWidth / 2).toFixed(1)}px,${(bC.y - team.offsetHeight / 2 + 40 + (1 - tv) * 60).toFixed(1)}px,${(tv * 60).toFixed(1)}px) rotateX(${(4 - FZ.ty * 6).toFixed(1)}deg) rotateY(${(-6 + FZ.tx * 10).toFixed(1)}deg)`;
  }
  function renderC(p) {
    setText(c1, p, -.7, -.25, 100, 101);
    const f = clamp(p, 0, 1) * 3.1 - .05, inn = ease(seg(p, -.75, -.1));
    PH.forEach((d, i) => {
      const th = (i - clamp(f, 0, 3)) * step, a = Math.abs(th);
      d.style.opacity = inn * clamp(1.15 - a / (step * 2.2));
      d.style.transform = `translateY(${((1 - inn) * 160).toFixed(1)}px) translateZ(${(-phW * 2.6).toFixed(1)}px) rotateY(${(th + FZ.tx * 8).toFixed(2)}deg) translateZ(${(phW * 2.6).toFixed(1)}px) rotateX(${(-FZ.ty * 6).toFixed(2)}deg)`;
      d.style.zIndex = 10 - Math.round(a);
    });
    caps.forEach((c, i) => c.classList.toggle('on', Math.round(clamp(f, 0, 3)) === i));
    $('#caps').style.opacity = inn;
  }
  function renderD(p) {
    setText(d1, p, -.7, -.25, 100, 101);
    const inn = ease(seg(p, -.8, -.1));
    lap.style.opacity = inn; sph.style.opacity = inn;
    lap.style.transform = `perspective(1400px) translateY(${((1 - inn) * 120).toFixed(1)}px) rotateX(${(8 - FZ.ty * 6).toFixed(1)}deg) rotateY(${(-16 + FZ.tx * 10).toFixed(1)}deg)`;
    sph.style.transform = `perspective(1200px) translate3d(0,${((1 - inn) * 180).toFixed(1)}px,60px) rotateY(${(16 + FZ.tx * 10).toFixed(1)}deg) rotateZ(-4deg)`;
    const k = ease(seg(p, .08, .55)), fo = win(p, .05, .1, .55, .6);
    const sx = SPH.x + SPH.w * .5, sy = SPH.y + SPH.h * .32, tx = LAP.x + LAP.w * .45, ty = LAP.y + 70;
    fly.style.opacity = fo; fly.style.visibility = fo < .01 ? 'hidden' : 'visible';
    fly.style.left = '0'; fly.style.top = '0';
    fly.style.transform = `perspective(1000px) translate3d(${lerp(sx, tx, k).toFixed(1)}px,${(lerp(sy, ty, k) - Math.sin(Math.PI * k) * 90).toFixed(1)}px,${(Math.sin(Math.PI * k) * 140).toFixed(1)}px) translate(-50%,-50%) rotateY(${(Math.sin(Math.PI * k) * -20).toFixed(1)}deg)`;
    const done = p > .55; $('#newRow').style.display = done ? 'flex' : 'none'; $('#lcnt').textContent = done ? '19 items' : '18 items';
  }

  /* ================= loop ================= */
  const nav = $('#nav'), who = $('#who'), end = $('#end'), rvs = $$('.rv');
  let lastT = performance.now(), lastY = scrollY, vel = 0;
  function frame(now) {
    const dt = Math.min(64, now - lastT); lastT = now;
    typePlaceholder(now);
    if (!FZ.reduce) { FZ.tx += (FZ.mx - FZ.tx) * .07; FZ.ty += (FZ.my - FZ.ty) * .07; }
    if (sA.getBoundingClientRect().bottom < 0) FZ.heroVis = 0;
    const er = end.getBoundingClientRect(); FZ.endVis = clamp((innerHeight - er.top) / innerHeight * 1.2);
    $('#heroBg').style.opacity = Math.max(FZ.heroVis, FZ.endVis);
    const smooth = (key, el, fn) => { const p = sample(key, el, FZ.reduce); if (p !== null) fn(p); };
    smooth('a', sA, renderA); smooth('b', stB, renderB); smooth('c', appS, renderC); smooth('d', syncS, renderD);
    /* who: rows lie back and straighten as they arrive; marquee speeds up with scroll */
    vel = lerp(vel, scrollY - lastY, .2); lastY = scrollY;
    const wr = who.getBoundingClientRect();
    if (wr.bottom > 0 && wr.top < innerHeight) {
      const q = ease(clamp((innerHeight - wr.top) / innerHeight));
      rowsEl.style.transform = `rotateX(${lerp(50, 16, q).toFixed(1)}deg) rotateZ(${lerp(-8, -3, q).toFixed(1)}deg) translateZ(${lerp(-150, 0, q).toFixed(0)}px)`;
      MR.forEach(m => { if (!m.w) m.w = m.el.scrollWidth / 4; m.x += (FZ.reduce ? 0 : (.04 + Math.min(1.2, Math.abs(vel) * .02)) * dt) * m.dir; if (m.x <= -m.w) m.x += m.w; if (m.x > 0) m.x -= m.w; m.el.style.transform = `translate3d(${m.x.toFixed(1)}px,0,0)`; });
    }
    rvs.forEach(el => { const r = el.getBoundingClientRect(), v = ease(clamp((innerHeight - r.top) / (innerHeight * .45))); el.style.opacity = v; el.style.transform = `translate3d(0,${((1 - v) * 60).toFixed(1)}px,0) rotateX(${((1 - v) * -20).toFixed(1)}deg)`; });
    /* nav */
    const ar = sA.getBoundingClientRect(), inA = ar.top <= 1 && ar.bottom >= innerHeight - 1 && stA.dataset.dark === '1';
    const dark = inA || (wr.top < 40 && wr.bottom > 40);
    nav.classList.toggle('is-night', dark); nav.classList.toggle('solid', !dark && scrollY > innerHeight * .5);
  }
  layout();
  const resize = () => { if (active) { layout(); MR.forEach(row => row.w = 0); } };
  window.addEventListener('resize', resize);
  document.fonts?.ready.then(resize);
  frame(performance.now());
  root.dataset.ready = 'true';
  return { frame, dispose() { active = false; window.removeEventListener('resize', resize); window.removeEventListener('pointermove', pointer); delete root.dataset.ready; } };
}
