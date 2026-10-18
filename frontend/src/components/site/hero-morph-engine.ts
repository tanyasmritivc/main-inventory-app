export const DETECTIONS = [
  [54.4, 31.9, 8, 9, "battery pack 18V", "0.95"],
  [65.6, 44.4, 13, 12, "battery charger 18V", "0.97"],
  [41.7, 49.6, 9, 10, "duct tape", "0.93"],
  [27, 58, 8, 7, "spur gear", "0.84"],
  [40, 66, 17, 16, "socket head screws", "0.91"],
  [66.7, 71, 20, 16, "gearbox housing", "0.79"],
] as const;

const QUESTIONS = [
  ["Where’s the duct tape", "Workbench › Middle", 2],
  ["How many socket head screws", "40 · Front bin", 4],
  ["Do I own an 18V charger", "Yes, 1 · Right side", 1],
  ["What needs a look", "Gearbox housing · 0.79", 5],
] as const;

const LENS_R = 92;
const SCROLL_LEN = 1300;
const MAX_W = 1160;
const GUTTER = 48;
const OVER = 170;
const NARROW = 980;
const Q_EVERY = 4200;
const C = (v: number) => Math.min(1, Math.max(0, v));
const ss = (v: number) => { v = C(v); return v * v * (3 - 2 * v); };
const L = (a: number, b: number, v: number) => a + (b - a) * v;

// Port of design/hero-morph/reference/index.html. All painting stays in rAF.
export function init(root: HTMLElement): () => void {
  const get = (name: string) => root.querySelector<HTMLElement>(`.fzh-${name}`)!;
  const inner = get("inner"), text = get("text"), s2 = get("s2");
  const photo = get("photo"), base = get("base"), lit = get("lit"), lens = get("lens");
  const card = get("card"), chip = get("chip");
  const hint = get("hint"), count = get("count"), foundEl = get("found"), needsEl = get("needs");
  const qEl = get("q"), aEl = get("a");
  const detEls = [...root.querySelectorAll<HTMLElement>(".fzh-det")];
  const header = root.closest(".fzLab")?.querySelector<HTMLElement>(".fzl-scroll-header, .fzl-site-header");
  const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const st = { p: 0, t: 0, hover: false, mx: 50, my: 45, q: 0, staticMode: false };
  let raf = 0, last = 0, lastQ = 0, dirty = true, disposed = false;
  const styled = [root, inner, text, s2, photo, base, lit, lens, card, chip, ...detEls];
  const originalStyles = styled.map(el => el.getAttribute("style"));

  function measure() {
    st.staticMode = motion.matches || window.innerWidth < NARROW;
    root.classList.toggle("fzh-static", st.staticMode);
    if (st.staticMode) { st.p = 0; return; }
    const rect = root.getBoundingClientRect();
    const span = rect.height - window.innerHeight;
    st.p = span > 0 ? C(-rect.top / span) : 0;
  }

  function render() {
    const p = st.p, statics = st.staticMode;
    const VH = window.innerHeight, VW = window.innerWidth;
    const HDR = header?.offsetHeight ?? 0;
    const e = ss((p - 0.08) / 0.62);
    const textOut = ss(p / 0.24);
    const cardOut = ss((p - 0.22) / 0.30);
    const s2In = ss((p - 0.45) / 0.35);
    const allOn = statics ? 0 : ss((p - 0.50) / 0.30);

    const lx = st.hover ? st.mx : 54 + 13 * Math.sin(st.t * 0.45);
    const ly = st.hover ? st.my : 47 + 11 * Math.sin(st.t * 0.7 + 1);
    const W = photo.offsetWidth || 580, H = W * 0.75;
    const R = Math.min(LENS_R, W * 0.2);
    let inView = 0, found = 0, needs = 0;
    DETECTIONS.forEach((d, i) => {
      const ai = statics ? 0 : ss((p - 0.46 - i * 0.045) / 0.07);
      if (ai > 0.5) { found++; if (Number(d[5]) < 0.80) needs++; }
      const seen = Math.hypot((d[0] - lx) / 100 * W, (d[1] - ly) / 100 * H) < R;
      if (seen) inView++;
      const asked = QUESTIONS[st.q][2] === i;
      detEls[i].style.opacity = String(Math.max(ai, (seen || asked) ? 1 - allOn : 0));
    });
    if (statics) {
      found = DETECTIONS.length;
      needs = DETECTIONS.filter(d => Number(d[5]) < 0.80).length;
    }
    foundEl.textContent = String(found);
    needsEl.textContent = String(needs);
    hint.textContent = allOn > 0.5 ? "One photo" : "Move your cursor to scan";
    count.textContent = allOn > 0.05
      ? found + (found === 1 ? " object found" : " objects found")
      : inView + (inView === 1 ? " object" : " objects") + " in view";
    base.style.filter = `brightness(${L(0.55, 0.92, allOn)})`;
    lit.style.clipPath = `circle(${R}px at ${lx}% ${ly}%)`;
    lit.style.opacity = String(1 - allOn);
    lens.style.cssText = `left:${lx}%;top:${ly}%;width:${R * 2}px;height:${R * 2}px;margin:${-R}px 0 0 ${-R}px;opacity:${1 - allOn}`;
    qEl.textContent = QUESTIONS[st.q][0];
    aEl.textContent = QUESTIONS[st.q][1];
    text.inert = !statics && textOut > 0.5;
    s2.inert = !statics && s2In <= 0.5;
    card.inert = !statics && cardOut > 0.5;

    if (statics) {
      [inner, text, s2, photo, card, chip].forEach(el => { el.style.cssText = ""; });
      return;
    }

    const Wi = Math.min(MAX_W, VW - 2 * GUTTER);
    const visH = VH - HDR;
    const hH = Math.max(260, Math.min(Wi * 0.62 * 0.75, visH - OVER - 40));
    const hW = hH / 0.75;
    const hL = Wi * 0.52;
    const hT = Math.max(16, Math.min(56, (visH - (hH + OVER)) / 2));
    const eW = Math.min(Wi * 0.55, VH * 0.74 / 0.75), eH = eW * 0.75;
    const eL = 0, eT = (VH - eH) / 2;
    const pW = L(hW, eW, e), pL = L(hL, eL, e), pT = L(hT, eT, e);
    const cW = Math.min(380, Wi * 0.33), cT = hT + hH - 120;
    inner.style.width = Wi + "px";
    text.style.cssText = `left:0;top:${Math.max(8, hT - 6)}px;width:${hL - 48}px;opacity:${1 - textOut};transform:translateY(${-80 * textOut}px);pointer-events:${textOut > 0.5 ? "none" : "auto"}`;
    s2.style.cssText = `left:${eW + 72}px;top:50%;width:${Wi - eW - 72}px;max-width:460px;opacity:${s2In};transform:translateY(calc(-50% + ${40 * (1 - s2In)}px));pointer-events:${s2In > 0.5 ? "auto" : "none"}`;
    photo.style.cssText = `left:${pL}px;top:${pT}px;width:${pW}px`;
    card.style.cssText = `left:${hL - 36}px;top:${cT}px;width:${cW}px;opacity:${1 - cardOut};transform:translateY(${60 * cardOut}px);pointer-events:${cardOut > 0.5 ? "none" : "auto"}`;
    chip.style.cssText = `left:${hL + hW - 250}px;top:${hT + hH - 66}px;opacity:${1 - textOut}`;
  }

  const invalidate = () => { dirty = true; };
  const onMove = (event: MouseEvent) => {
    if (motion.matches) return;
    const rect = photo.getBoundingClientRect();
    st.hover = true;
    st.mx = (event.clientX - rect.left) / rect.width * 100;
    st.my = (event.clientY - rect.top) / rect.height * 100;
    invalidate();
  };
  const onLeave = () => { st.hover = false; invalidate(); };
  const onMotion = () => { st.hover = false; st.t = 0; invalidate(); };
  function tick(ts: number) {
    if (disposed) return;
    raf = requestAnimationFrame(tick);
    if ((motion.matches || window.innerWidth < NARROW) !== st.staticMode) dirty = true;
    if (dirty) measure();
    if (ts - last >= 33) {
      last = ts;
      if (!lastQ) lastQ = ts;
      if (!st.hover && !motion.matches && st.p < 0.6) { st.t = ts / 1000; dirty = true; }
      if (ts - lastQ > Q_EVERY && st.p < 0.3) {
        lastQ = ts;
        st.q = (st.q + 1) % QUESTIONS.length;
        dirty = true;
      }
    }
    if (dirty) { dirty = false; render(); }
  }

  root.style.setProperty("--fzh-scroll-length", SCROLL_LEN + "px");
  window.addEventListener("scroll", invalidate, { passive: true });
  window.addEventListener("resize", invalidate);
  photo.addEventListener("mousemove", onMove);
  photo.addEventListener("mouseleave", onLeave);
  motion.addEventListener("change", onMotion);
  const observer = new ResizeObserver(invalidate);
  observer.observe(photo);
  if (header) observer.observe(header);
  void document.fonts.ready.then(() => { if (!disposed) invalidate(); });
  raf = requestAnimationFrame(tick);
  return () => {
    disposed = true;
    cancelAnimationFrame(raf);
    window.removeEventListener("scroll", invalidate);
    window.removeEventListener("resize", invalidate);
    photo.removeEventListener("mousemove", onMove);
    photo.removeEventListener("mouseleave", onLeave);
    motion.removeEventListener("change", onMotion);
    observer.disconnect();
    root.classList.remove("fzh-static");
    [text, s2, card].forEach(el => { el.inert = false; });
    styled.forEach((el, i) => {
      const original = originalStyles[i];
      if (original === null) el.removeAttribute("style");
      else el.setAttribute("style", original);
    });
  };
}
