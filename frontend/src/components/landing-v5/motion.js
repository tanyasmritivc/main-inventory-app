// Numeric scroll ranges preserved from the supplied v5 prototype.
export function createLandingMotion(root) {
const $ = s => root.querySelector(s), $$ = s => [...root.querySelectorAll(s)];
const media = matchMedia('(prefers-reduced-motion: reduce)');
const cl = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const ease = x => 1 - Math.pow(1 - x, 3);
root.dataset.motion = 'true';
/* scroll-driven motion: everything is scrubbed by scroll position, so it reverses when scrolling up */
const nav = $('#nav'), closeC = $('#closeC');
const rv = $$('[data-rv]'), par = $$('[data-par]');
let bq = 0, raf = 0;
const B = { um1: $('#um1'), th1: $('#th1'), fr1: $('#fr1'), slot: $('#slot'), plan: $('#plan'), saved: $('#saved'), prows: $('#prows'), rows: $$('#prows .pr'), pgo: $('#pgo'), um2: $('#um2'), th2: $('#th2'), fr2: $('#fr2'), ted: $('#tED'), msgs: $('#wmsgs'), area: $('#warea') };
function frameLoop() {
  const vh = innerHeight, y = scrollY;
  const reduce = media.matches;
  nav.classList.toggle('solid', y > 30);

  for (const el of rv) { const r = el.getBoundingClientRect(); const k = reduce ? 1 : ease(cl((vh - r.top) / (vh * .32))); el.style.opacity = String(k); el.style.transform = `translateY(${(1 - k) * 34}px)`; }
  for (const el of par) { const r = el.getBoundingClientRect(); const k = reduce ? .5 : cl((vh - r.top) / (vh + r.height)); el.style.backgroundPosition = `50% ${30 + k * 40}%`; }
  // describe it: the chat types, the plan fills, it is confirmed and saved, then a follow-up updates it
  { const bp = $('.bpin'), pinned = getComputedStyle(bp).position === 'sticky';
    const r = $('#build').getBoundingClientRect();
    const q = (!pinned || reduce) ? 1 : cl(-r.top / (r.height - vh + 60));
    bq = reduce || !pinned ? q : bq + (q - bq) * .2;
    const seg = (a, b) => cl((bq - a) / (b - a));
    const type = (el, k) => { const t = el.querySelector('.t'), f = t.dataset.full; const n = Math.round(f.length * k); if (t._n !== n) { t._n = n; t.textContent = f.slice(0, n) || '\u00a0'; } };
    const show = (el, k, dy = 12) => { el.style.opacity = String(k); el.style.transform = `translateY(${(1 - k) * dy}px)`; el.style.display = k > 0 ? '' : 'none'; };
    show(B.um1, ease(seg(.0, .04))); type(B.um1, seg(.02, .22));
    show(B.th1, seg(.22, .23) * (1 - seg(.27, .28)), 0);
    show(B.fr1, ease(seg(.27, .31)));
    show(B.slot, ease(seg(.3, .34)));
    const nRows = Math.floor(seg(.33, .53) * 12.999);
    B.rows.forEach((rw, i) => { rw.style.opacity = i < nRows ? "1" : "0"; });
    B.prows.style.transform = `translateY(${-Math.max(0, nRows - 4) * (B.rows[0].offsetHeight || 46)}px)`;
    const press = seg(.56, .6); B.pgo.style.transform = `scale(${1 - .06 * Math.sin(Math.PI * press)})`; B.pgo.style.background = press > 0 ? '#3A3A3D' : '';
    const sv = ease(seg(.6, .66)); B.plan.style.opacity = 1 - sv; B.plan.style.transform = `scale(${1 - .03 * sv})`; B.saved.style.opacity = sv; B.saved.style.transform = `translateY(${(1 - sv) * 14}px)`;
    B.slot.style.height = (sv > .5 ? B.saved.offsetHeight : B.plan.offsetHeight) + 'px';
    show(B.um2, ease(seg(.72, .75))); type(B.um2, seg(.73, .84));
    show(B.th2, seg(.84, .85) * (1 - seg(.89, .9)), 0);
    show(B.fr2, ease(seg(.89, .93)));
    const up = bq > .9; B.ted.classList.toggle('hl', up && bq < .995 || (up && !pinned)); B.ted.querySelector('.tu').textContent = up ? 7 : 5;
    const over = Math.max(0, B.msgs.scrollHeight - B.area.clientHeight); B.msgs.style.transform = `translateY(${-over}px)`; }
  // FIND card: detection boxes drift apart as it scrolls through
  { const c = $('#findC'), r = c.getBoundingClientRect(), k = reduce ? .5 : cl((vh - r.top) / (vh + r.height)); [...c.querySelectorAll('.fb')].forEach((b, i) => { b.style.transform = `translate(${(k - .5) * [40, -30, 20][i]}px,${(k - .5) * [-24, 30, -36][i]}px)`; b.style.opacity = .35 + .65 * Math.sin(Math.PI * k); }); c.style.backgroundPosition = `${30 + k * 40}% 50%`; }
  // closing card grows into place
  { const r = closeC.getBoundingClientRect(), k = reduce ? 1 : ease(cl((vh - r.top) / (vh * .7))); closeC.style.transform = `scale(${.92 + .08 * k})`; closeC.style.backgroundPosition = `${50 + (1 - k) * 30}% 50%`; }
  raf = requestAnimationFrame(frameLoop);
}
raf = requestAnimationFrame(frameLoop);
return () => { cancelAnimationFrame(raf); delete root.dataset.motion; };
}
