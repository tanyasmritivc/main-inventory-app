/* FindEZ landing page — the imperative half.
 *
 * Two scroll-driven morphs and three canvases live here. React owns the markup
 * (landing-morph.tsx); this module owns everything that has to run per frame.
 * `initLanding` returns a teardown that kills every loop, listener and timer,
 * so the page unmounts cleanly on client navigation.
 */

type Rect = { x: number; y: number; w: number; h: number };
type Pt = { x: number; y: number; z: number; s: number; a: number; t?: string };
type Proj = { X: number; Y: number; k: number; d: number };
type Layout = {
  photo: Rect[];
  frame: (Rect | null)[];
  rows: Rect;
  result: Rect;
  W: number;
  H: number;
  narrow: boolean;
};
type CloudMod = { ink: number[]; alpha: number; scale: number; label: number };
type CloudOpts = {
  cx: number; cy: number; scale: number; spin: number; alpha: number;
  track: boolean; scrollSpin?: boolean; ink: string; labels: Pt[]; mod?: CloudMod;
};

export function initLanding(root: HTMLElement): () => void {
  var dead = false;
  var offs: Array<() => void> = [];
  var timers: number[] = [];

  var $ = function (sel: string) { return root.querySelector(sel) as HTMLElement; };
  var $c = function (sel: string) { return root.querySelector(sel) as HTMLCanvasElement | null; };
  var $$ = function (sel: string) {
    return Array.prototype.slice.call(root.querySelectorAll(sel)) as HTMLElement[];
  };
  var on = function (
    t: Window | Document,
    e: string,
    f: EventListenerOrEventListenerObject,
    o?: AddEventListenerOptions
  ) {
    t.addEventListener(e, f, o);
    offs.push(function () { t.removeEventListener(e, f, o); });
  };
  var onEl = function (t: Element, e: string, f: EventListenerOrEventListenerObject) {
    t.addEventListener(e, f);
    offs.push(function () { t.removeEventListener(e, f); });
  };

  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var canObserve = 'IntersectionObserver' in window;
  var raf = window.requestAnimationFrame.bind(window);
  var clamp = function(v: number, a: number, b: number){ return v < a ? a : (v > b ? b : v); };
  var lerp  = function(a: number, b: number, t: number){ return a + (b-a)*t; };
  var smooth = function(t: number){ t = clamp(t,0,1); return t*t*(3-2*t); };
  /* ramp: 0 before a, 1 after b, smooth between */
  var ramp = function(v: number, a: number, b: number){ return smooth((v-a)/(b-a)); };
  /* window: fades in over [a,b], out over [c,d] */
  var win = function(v: number, a: number, b: number, c: number, d: number){ return Math.min(ramp(v,a,b), 1-ramp(v,c,d)); };

  /* ---------------- reticle ---------------- */
  if (window.matchMedia && window.matchMedia('(pointer:fine)').matches && !reduced){
    root.classList.add('pointer-fine');
    var ret = $('#retic'), rx = innerWidth/2, ry = innerHeight/2, ppx = rx, ppy = ry;
    on(window, 'pointermove', function(ev){
      var e = ev as PointerEvent;
      rx = e.clientX; ry = e.clientY;
      var el = e.target as Element | null;
      ret.classList.toggle('hot', !!(el && el.closest && el.closest('a,button')));
    }, {passive:true});
    (function loop(){ if (dead) return; ppx += (rx-ppx)*.22; ppy += (ry-ppy)*.22;
      ret.style.transform = 'translate3d(' + ppx + 'px,' + ppy + 'px,0)'; raf(loop); })();
  }

  /* ---------------- reveal ---------------- */
  var sections = $$('[data-reveal]');
  if (!reduced && canObserve) sections.forEach(function(s){ s.classList.add('armed'); });
  function unarm(s: Element){
    s.classList.remove('armed');
    if (s.id === 'thesis') s.classList.add('drawn');
    if (s.id === 'ask') startAsk();
  }
  if (!reduced && canObserve){
    var io = new IntersectionObserver(function(es){
      es.forEach(function(e){ if (e.isIntersecting){ unarm(e.target); io.unobserve(e.target); } });
    }, {threshold:.15, rootMargin:'0px 0px -6% 0px'});
    sections.forEach(function(s){ io.observe(s); });
    timers.push(window.setTimeout(function(){ sections.forEach(unarm); }, 9000));
  } else {
    sections.forEach(function(s){ s.classList.remove('armed'); s.classList.add('drawn'); });
    timers.push(window.setTimeout(startAsk, 300));
  }

  /* ---------------- header / rail ---------------- */
  var hdr = $('#hdr'), rail = $('#railFill');
  var darks = $$('[data-dark]');
  var scrollY = 0;
  function onScroll(){
    scrollY = pageYOffset || document.documentElement.scrollTop;
    hdr.classList.toggle('stuck', scrollY > 20);
    var max = document.documentElement.scrollHeight - innerHeight;
    rail.style.height = (max > 0 ? (scrollY/max)*100 : 0) + '%';
    var dark = false;
    var sr = a1Stage.getBoundingClientRect();
    if (sr.top <= 40 && sr.bottom >= 40){
      dark = a1Progress() > .30;
    } else {
      for (var i=0;i<darks.length;i++){
        var r = darks[i].getBoundingClientRect();
        if (r.top <= 40 && r.bottom >= 40){ dark = true; break; }
      }
    }
    hdr.classList.toggle('on-dark', dark);
  }
  on(window, 'scroll', onScroll, {passive:true});
  on(window, 'resize', onScroll);

  /* =====================================================================
     ACT ONE — the hero page morphs into the statements page on scroll
     ===================================================================== */
  var act1    = $('#act1');
  var a1Stage = $('#a1Stage');
  var a1Hero  = $('#a1Hero');
  var a1Sts   = $$('#a1Statements .st');
  var weaveEl = $c('#weave');
  var CREAM = [241,241,239], DARK = [11,37,25], INK_G = [21,65,48], INK_S = [147,171,158];
  var heroMod = {ink:[21,65,48], alpha:1, scale:1, label:1};
  var a1Shown = 0;

  function a1Progress(){
    var r = act1.getBoundingClientRect(), travel = act1.offsetHeight - innerHeight;
    if (travel <= 0) return 0;
    return clamp(-r.top / travel, 0, 1);
  }
  function a1Live(){
    var r = act1.getBoundingClientRect();
    return r.top < innerHeight + 200 && r.bottom > -200;
  }
  function a1Render(p: number){
    /* the ground itself changes colour — no section seam anywhere */
    var dk = ramp(p, .12, .36);
    a1Stage.style.background = 'rgb(' +
      Math.round(lerp(CREAM[0],DARK[0],dk)) + ',' +
      Math.round(lerp(CREAM[1],DARK[1],dk)) + ',' +
      Math.round(lerp(CREAM[2],DARK[2],dk)) + ')';

    /* the headline lifts away */
    var out = ramp(p, .05, .28);
    a1Hero.style.opacity = (1 - out).toFixed(3);
    a1Hero.style.transform = 'translate3d(0,' + (-out*9).toFixed(2) + 'vh,0) scale(' + (1 - out*.045).toFixed(4) + ')';
    a1Hero.style.pointerEvents = out > .5 ? 'none' : 'auto';

    /* the three statements arrive one at a time */
    for (var i = 0; i < a1Sts.length; i++){
      var a = ramp(p, .30 + i*.185, .47 + i*.185);
      a1Sts[i].style.opacity = a.toFixed(3);
      a1Sts[i].style.transform = 'translate3d(0,' + ((1-a)*44).toFixed(1) + 'px,0)';
    }

    /* the rack survives the transition — it just turns to light on the dark */
    heroMod.ink[0] = lerp(INK_G[0], INK_S[0], dk);
    heroMod.ink[1] = lerp(INK_G[1], INK_S[1], dk);
    heroMod.ink[2] = lerp(INK_G[2], INK_S[2], dk);
    heroMod.alpha = lerp(1, .42, dk);
    heroMod.scale = 1 - .34*ramp(p, .18, .92);
    heroMod.label = 1 - ramp(p, .10, .26);
    if (weaveEl) weaveEl.style.opacity = (ramp(p, .34, .58) * .6).toFixed(3);
  }
  a1Render(0);

  /* ---------------- ticker ---------------- */
  var PARTS = ['608 bearing','XT60 connector','motor mount','M3×16 socket head','nyloc nut','35T hex gear',
    '1/2" hex shaft','timing belt','servo horn','odometry pod','spark mini','aluminium channel',
    'compliant wheel','shoulder bolt','limit switch','zip ties','thread locker','spacer 8mm'];
  var tk = PARTS.map(function(p){ return '<span>'+p+'</span>'; }).join('');
  $('#tick').innerHTML = tk + tk;

  /* =====================================================================
     MORPH RIG — one surface, four states, driven entirely by scroll
     ===================================================================== */
  var ROWS: { n: string; q: string; l: string }[] = [
    {n:'motor mount',    q:'6',   l:'Machine shop &middot; Shelf B2'},
    {n:'XT60 connector', q:'18',  l:'Electronics &middot; Bin C07'},
    {n:'hex bolt',       q:'120', l:'Hardware wall &middot; Tray 3'},
    {n:'nyloc nut M3',   q:'240', l:'Hardware wall &middot; Tray 1'},
    {n:'35T hex gear',   q:'9',   l:'Machine shop &middot; Drawer A02'}
  ];
  var rowsEl = $('#mRows');
  ROWS.forEach(function(r){
    var d = document.createElement('div');
    d.className = 'irow';
    d.innerHTML = '<span class="th"></span><span class="nm">'+r.n+'</span>' +
                  '<span class="qt">'+r.q+'</span><span class="lc">'+r.l+'</span>';
    rowsEl.appendChild(d);
  });

  var wrap   = $('#morphWrap');
  var rig    = $('#rig');
  var photo  = $('#mPhoto');
  var ghosts = $('#mGhosts');
  var frame  = $('#mFrame');
  var veil   = $('#mVeil');
  var mscan  = $('#mScan');
  var result = $('#mResult');
  var lChip  = $('#lChip');
  var lRec   = $('#lRecord');
  var lRow   = $('#lRow');
  var lSea   = $('#lSearch');
  var mQuery = $('#mQuery');
  var mCur   = $('#mCur');
  var phEls  = $$('.ph');
  var capEls = $$('.caption span');
  var pbar   = $('#pbarFill');

  /* detection-box position inside the photo, as fractions of the photo */
  var BOX = {x:.400, y:.264, w:.180, h:.285};
  var QUERY = '608 bearing';

  /* keyframe stops */
  var STOPS = [0, .34, .64, .88];

  function layout(): Layout {
    var W = rig.clientWidth, H = rig.clientHeight, narrow = W < 900;
    var top = narrow ? .22 : .17;              /* clear the phase index */
    var L: Layout = {} as Layout;

    if (narrow){
      L.photo = [
        {x:.00,  y:top,      w:1,    h:.44},
        {x:.00,  y:top,      w:1,    h:.30},
        {x:.012, y:top+.055, w:.115, h:.052},
        {x:.012, y:top+.055, w:.115, h:.052}
      ];
      L.frame = [
        null,
        {x:.00, y:top+.50, w:1,   h:.42},
        {x:.00, y:top+.04, w:1,   h:.075},
        {x:.00, y:top+.10, w:1,   h:.105}
      ];
      L.rows   = {x:0, y:top+.115, w:1, h:.066};
      L.result = {x:0, y:top+.245, w:1, h:.30};
    } else {
      L.photo = [
        {x:.14,  y:top,      w:.72,  h:.74},
        {x:.015, y:top+.02,  w:.45,  h:.62},
        {x:.055, y:top+.075, w:.048, h:.052},
        {x:.055, y:top+.075, w:.048, h:.052}
      ];
      L.frame = [
        null,
        {x:.52,  y:top+.02,  w:.465, h:.62},
        {x:.03,  y:top+.06,  w:.94,  h:.082},
        {x:.19,  y:top+.10,  w:.62,  h:.105}
      ];
      L.rows   = {x:.03, y:top+.142, w:.94, h:.072};
      L.result = {x:.19, y:top+.245, w:.62, h:.26};
    }

    /* the photo shrinks into the row's own thumbnail cell */
    var pad = (narrow ? 10 : 20) / W, tw = (narrow ? 34 : 46) / W;
    var f2 = L.frame[2] as Rect;
    var thumb = {x: f2.x + pad, y: f2.y + f2.h*.15, w: tw, h: f2.h*.70};
    L.photo[2] = thumb; L.photo[3] = thumb;

    /* frame state 0 is the detection box painted on the photo */
    var p0 = L.photo[0];
    L.frame[0] = {
      x: p0.x + BOX.x*p0.w,
      y: p0.y + BOX.y*p0.h,
      w: BOX.w*p0.w,
      h: BOX.h*p0.h
    };
    L.W = W; L.H = H; L.narrow = narrow;
    return L;
  }

  var LAY = layout();
  on(window, 'resize', function(){ LAY = layout(); });

  function place(el: HTMLElement, r: Rect, W: number, H: number){
    el.style.transform = 'translate3d(' + (r.x*W).toFixed(2) + 'px,' + (r.y*H).toFixed(2) + 'px,0)';
    el.style.width  = (r.w*W).toFixed(2) + 'px';
    el.style.height = (r.h*H).toFixed(2) + 'px';
  }
  /* interpolate a keyframe track at progress p */
  function track(kfs: (Rect | null)[], p: number){
    var i = 0;
    while (i < STOPS.length-1 && p > STOPS[i+1]) i++;
    var a = kfs[i] as Rect, b = kfs[Math.min(i+1, kfs.length-1)] as Rect;
    var span = (STOPS[Math.min(i+1,STOPS.length-1)] - STOPS[i]) || 1;
    var t = smooth(clamp(((p - STOPS[i]) / span - .5) / .5, 0, 1));
    return {x:lerp(a.x,b.x,t), y:lerp(a.y,b.y,t), w:lerp(a.w,b.w,t), h:lerp(a.h,b.h,t)};
  }

  var target = 0, shown = 0, rigLive = false, typed = -1;

  function readProgress(){
    var r = wrap.getBoundingClientRect();
    var travel = wrap.offsetHeight - innerHeight;
    rigLive = r.top < innerHeight && r.bottom > 0;
    if (travel <= 0) return 0;
    return clamp(-r.top / travel, 0, 1);
  }

  function render(p: number){
    var W = LAY.W, H = LAY.H;

    /* ---- photo ---- */
    var pr = track(LAY.photo, p);
    place(photo, pr, W, H);
    photo.style.opacity = (1 - ramp(p, .78, .86)).toFixed(3);
    veil.style.opacity = (ramp(p, .26, .46) * .5).toFixed(3);

    /* scan sweep across the opening beat */
    var sp = ramp(p, .015, .17);
    mscan.style.transform = 'translateY(' + (-120 + sp*420).toFixed(1) + '%)';
    mscan.style.opacity = String(sp > .002 && sp < .999 ? 1 : 0);

    /* ---- ghost detections ride the photo, then dissolve ---- */
    place(ghosts, pr, W, H);
    ghosts.style.opacity = win(p, .06, .16, .22, .33).toFixed(3);

    /* ---- the morphing surface ---- */
    var fr = track(LAY.frame, p);
    place(frame, fr, W, H);

    var lift = ramp(p, .16, .32);                 /* detaches from the photo */
    var settle = ramp(p, .50, .63);               /* becomes a table row */
    frame.style.background = 'rgba(255,255,255,' + (lift*0.99).toFixed(3) + ')';
    var bw = lerp(2, 1, lift);
    frame.style.borderWidth = bw.toFixed(2) + 'px';
    frame.style.borderColor = 'rgba(' + Math.round(lerp(255,19,lift)) + ',' +
        Math.round(lerp(255,19,lift)) + ',' + Math.round(lerp(255,19,lift)) + ',' +
        lerp(.92,.16,lift).toFixed(3) + ')';
    var sh = lift * (1 - settle*.75);
    frame.style.boxShadow = '0 ' + (26*sh).toFixed(1) + 'px ' + (60*sh).toFixed(1) +
        'px -' + (28*sh).toFixed(1) + 'px rgba(11,37,25,' + (0.5*sh).toFixed(3) + ')';

    /* ---- content layers cross-fade ---- */
    lChip.style.opacity = win(p, .0,  .04, .12, .18).toFixed(3);
    lRec.style.opacity  = win(p, .29, .37, .46, .53).toFixed(3);
    lRow.style.opacity  = win(p, .59, .66, .755, .80).toFixed(3);
    lSea.style.opacity  = ramp(p, .855, .90).toFixed(3);

    /* ---- index rows stack in under the first row ---- */
    var rowShow = win(p, .62, .74, .80, .87);
    rowsEl.style.opacity = '1';
    var rw = LAY.rows;
    place(rowsEl, {x:rw.x, y:rw.y, w:rw.w, h:rw.h*ROWS.length}, W, H);
    var kids = rowsEl.children as HTMLCollectionOf<HTMLElement>;
    for (var i = 0; i < kids.length; i++){
      var st = ramp(p, .60 + i*.011, .662 + i*.011) * (1 - ramp(p, .745 + i*.005, .79));
      kids[i].style.opacity = st.toFixed(3);
      kids[i].style.transform = 'translate3d(0,' + (rw.h*H*i + (1-st)*18).toFixed(2) + 'px,0)';
      kids[i].style.height = (rw.h*H).toFixed(2) + 'px';
      kids[i].style.setProperty('--thumb', (LAY.narrow ? 34 : 46) + 'px');
    }

    /* first row keeps a thumbnail of the photo — the object itself, filed */
    (lRow.querySelector('.irow') as HTMLElement).style.setProperty('--thumb', (LAY.narrow ? 34 : 46) + 'px');

    /* ---- typed query ---- */
    var qp = ramp(p, .895, .962);
    var n = Math.round(qp * QUERY.length);
    if (n !== typed){ typed = n; mQuery.textContent = QUERY.slice(0, n); }
    mCur.style.opacity = String((qp > 0 && qp < 1) ? 1 : (p > .985 ? ((Date.now()/500|0)%2 ? .25 : 1) : 0));

    /* ---- result ---- */
    var rr = LAY.result;
    place(result, rr, W, H);
    var ro = ramp(p, .94, .99);
    result.style.opacity = ro.toFixed(3);
    result.style.transform = 'translate3d(' + (rr.x*W).toFixed(2) + 'px,' +
        ((rr.y*H) + (1-ro)*26).toFixed(2) + 'px,0)';

    /* ---- phase index ---- */
    var beat = p < .28 ? 0 : p < .57 ? 1 : p < .83 ? 2 : 3;
    for (var k = 0; k < phEls.length; k++) phEls[k].classList.toggle('on', k === beat);
    for (var c = 0; c < capEls.length; c++) capEls[c].classList.toggle('on', c === beat);
    pbar.style.width = (p*100).toFixed(2) + '%';
  }

  if (!reduced){
    /* silky: chase the scroll position instead of snapping to it */
    (function tick(){
      if (dead) return;
      if (a1Live()){
        var a1t = a1Progress();
        a1Shown += (a1t - a1Shown) * .16;
        if (Math.abs(a1t - a1Shown) < .0004) a1Shown = a1t;
        a1Render(a1Shown);
      }
      target = readProgress();
      if (rigLive || Math.abs(target - shown) > .0005){
        shown += (target - shown) * .14;
        if (Math.abs(target - shown) < .0004) shown = target;
        render(shown);
      }
      raf(tick);
    })();
    render(0);
  }

  /* ---------------- ask console ---------------- */
  var QA: { q: string; a: string[] }[] = [
    {q:'Where are the 608 bearings?', a:['<strong>608 bearings</strong>','34 in stock','<span class="dim">Machine shop &middot; Drawer A04</span>']},
    {q:'What do we have for the drivetrain?', a:['<strong>14 parts across 3 spaces</strong>','Hex shafts, compliant wheels, 35T gears','<span class="dim">Machine shop &middot; Shelf B1–B3</span>']},
    {q:'What is running low?', a:['<strong>3 items below threshold</strong>','XT60 connectors &middot; 4 left','<span class="dim">Nyloc nuts, 8mm spacers</span>']}
  ];
  var qtext = $('#qtext'), caret = $('#caret'),
      abody = $('#abody'), chips = $('#chips');
  var typing: number | undefined, askOn = false;
  QA.forEach(function(item,i){
    var b = document.createElement('button');
    b.className = 'chip' + (i === 0 ? ' on' : '');
    b.type = 'button'; b.textContent = item.q;
    onEl(b, 'click', function(){ play(i); });
    chips.appendChild(b);
  });
  function paint(i: number, instant: boolean){
    abody.innerHTML = '';
    QA[i].a.forEach(function(line,n){
      var el = document.createElement('div');
      el.innerHTML = line; abody.appendChild(el);
      timers.push(window.setTimeout(function(){ el.classList.add('in'); }, instant ? 0 : 150*n + 60));
    });
  }
  function play(i: number){
    $$('.chip').forEach(function(c, n){ c.classList.toggle('on', n === i); });
    window.clearInterval(typing); abody.innerHTML = '';
    if (reduced){ qtext.textContent = QA[i].q; caret.style.display = 'none'; paint(i,true); return; }
    caret.style.display = ''; qtext.textContent = '';
    var s = QA[i].q, n = 0;
    typing = window.setInterval(function(){
      qtext.textContent = s.slice(0, ++n);
      if (n >= s.length){
        window.clearInterval(typing);
        timers.push(window.setTimeout(function(){ caret.style.display = 'none'; paint(i,false); }, 380));
      }
    }, 40);
  }
  function startAsk(){ if (askOn) return; askOn = true; play(0); }

  /* ---------------- point cloud ---------------- */
  function Cloud(canvas: HTMLCanvasElement, opts: CloudOpts){
    var M = opts.mod || {ink:[21,65,48], alpha:1, scale:1, label:1};
    var ctx2d: CanvasRenderingContext2D | null = null;
    try { ctx2d = canvas.getContext('2d'); } catch { ctx2d = null; }
    if (!ctx2d) return;
    var ctx = ctx2d;
    var w = 0, h = 0, dpr = Math.min(devicePixelRatio || 1, 2);
    var pts: Pt[] = [], edges: Pt[][] = [], labels = opts.labels || [], yaw = 0, tyaw = 0, mx = 0, my = 0;

    function boxEdges(cx0: number, cy0: number, cz0: number, hw: number, hh: number, hd: number){
      var c: Pt[] = [];
      for (var i = 0; i < 8; i++)
        c.push({x:cx0 + (i&1?hw:-hw), y:cy0 + (i&2?hh:-hh), z:cz0 + (i&4?hd:-hd), s:1, a:1});
      var pairs = [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]];
      for (var e = 0; e < pairs.length; e++) edges.push([c[pairs[e][0]], c[pairs[e][1]]]);
    }
    function build(){
      pts = []; edges = [];
      var rnd = function(a: number, b: number){ return a + Math.random()*(b-a); };
      boxEdges(0,-20,0,206,132,112);
      for (var s = 0; s < 3; s++){
        var sy = -70 + s*70;
        boxEdges(0, sy, 0, 204, 1.5, 110);
        for (var i = 0; i < 130; i++) pts.push({x:rnd(-200,200), y:sy+rnd(-2,2), z:rnd(-110,110), s:1, a:.7});
        for (var b = 0; b < 4; b++){
          var bx = -156 + b*104;
          boxEdges(bx, sy-19, 0, 36, 19, 72);
          for (var j = 0; j < 95; j++){
            var e2 = Math.random();
            pts.push({x:bx+rnd(-33,33), y:sy-rnd(2,34), z:rnd(-70,70), s:e2>.92?2.4:1.15, a:e2>.92?1:.55});
          }
        }
      }
      for (var u = 0; u < 4; u++){
        var ux = (u < 2 ? -206 : 206), uz = (u % 2 ? -112 : 112);
        for (var k = 0; k < 80; k++) pts.push({x:ux, y:rnd(-152,112), z:uz, s:1.2, a:.6});
      }
    }
    function size(){
      w = canvas.clientWidth; h = canvas.clientHeight;
      if (!w || !h) return;
      canvas.width = w*dpr; canvas.height = h*dpr; ctx.setTransform(dpr,0,0,dpr,0,0);
    }
    function project(p: Pt, cy: number, cs: number){
      var c = Math.cos(yaw), s = Math.sin(yaw);
      var x = p.x*c - p.z*s, z = p.x*s + p.z*c, d = 620 + z;
      if (d < 40) return null;
      var k = 560/d;
      return {X:w*opts.cx + x*k*cs, Y:h*cy + (p.y + my*16)*k*cs, k:k, d:d};
    }
    var t0 = performance.now();
    function frame2(now: number){
      if (dead) return;
      if (!w || !h){ size(); if (!reduced) raf(frame2); return; }
      var vr = canvas.getBoundingClientRect();
      if (!reduced && (vr.bottom < -120 || vr.top > innerHeight + 120)){ raf(frame2); return; }
      var t = (now - t0)/1000;
      var INK = 'rgba(' + Math.round(M.ink[0]) + ',' + Math.round(M.ink[1]) + ',' + Math.round(M.ink[2]) + ',';
      var AL = opts.alpha * M.alpha;
      tyaw = (mx - .5)*.55 + t*opts.spin + (opts.scrollSpin ? scrollY*0.0007 : 0);
      yaw += (tyaw - yaw)*.06;
      ctx.clearRect(0,0,w,h);
      var cs = Math.min(1, w/1200) * opts.scale * M.scale;

      ctx.lineWidth = 1;
      for (var E = 0; E < edges.length; E++){
        var a1 = project(edges[E][0], opts.cy, cs), a2 = project(edges[E][1], opts.cy, cs);
        if (!a1 || !a2) continue;
        var ef = clamp((900 - (a1.d+a2.d)/2)/460, 0, 1), ea = ef*.3*AL;
        if (ea <= .012) continue;
        ctx.strokeStyle = INK + ea.toFixed(3) + ')';
        ctx.beginPath(); ctx.moveTo(a1.X,a1.Y); ctx.lineTo(a2.X,a2.Y); ctx.stroke();
      }
      var arr: { p: Pt; r: Proj }[] = [];
      for (var i = 0; i < pts.length; i++){
        var pr2 = project(pts[i], opts.cy, cs);
        if (pr2) arr.push({p:pts[i], r:pr2});
      }
      arr.sort(function(a: { r: Proj }, b: { r: Proj }){ return b.r.d - a.r.d; });
      for (var j = 0; j < arr.length; j++){
        var p = arr[j].p, r = arr[j].r;
        var fade = clamp((900 - r.d)/420, 0, 1), a = p.a*fade*AL*1.25;
        if (a <= .01) continue;
        var sz = Math.max(.7, p.s*r.k*1.25);
        ctx.fillStyle = INK + a.toFixed(3) + ')';
        ctx.fillRect(r.X - sz/2, r.Y - sz/2, sz, sz);
      }
      for (var L = 0; L < labels.length; L++){
        var lb = labels[L], r2 = project(lb, opts.cy, cs);
        if (!r2) continue;
        var front = clamp((760 - r2.d)/260, 0, 1), puls = .55 + .45*Math.sin(t*1.1 + L*1.7);
        var la = front*puls*AL*M.label;
        if (la <= .04) continue;
        ctx.save(); ctx.globalAlpha = la;
        ctx.font = '400 11px ' + getComputedStyle(document.body).fontFamily;
        ctx.strokeStyle = INK + '0.9)'; ctx.lineWidth = 1;
        var bw2 = 34*r2.k, bh2 = 24*r2.k;
        ctx.strokeRect(r2.X - bw2/2, r2.Y - bh2/2, bw2, bh2);
        ctx.beginPath();
        ctx.moveTo(r2.X + bw2/2, r2.Y - bh2/2);
        ctx.lineTo(r2.X + bw2/2 + 26, r2.Y - bh2/2 - 20);
        ctx.lineTo(r2.X + bw2/2 + 26 + ctx.measureText(lb.t as string).width + 14, r2.Y - bh2/2 - 20);
        ctx.stroke();
        ctx.fillStyle = INK + '0.95)';
        ctx.fillText(lb.t as string, r2.X + bw2/2 + 32, r2.Y - bh2/2 - 25);
        ctx.restore();
      }
      if (!reduced) raf(frame2);
    }
    on(window, 'resize', size);
    if (opts.track) on(window, 'pointermove', function(ev){
      var e = ev as PointerEvent;
      mx = e.clientX/innerWidth; my = e.clientY/innerHeight - .5;
    }, {passive:true});
    build(); size();
    if (reduced){ yaw = .35; frame2(performance.now()); } else raf(frame2);
  }
  var c1 = $c('#cloud');
  if (c1) Cloud(c1, {cx:.5, cy:.5, scale:1.55, spin:.03, alpha:.95, track:true, scrollSpin:true,
    mod:heroMod, ink:'rgba(21,65,48,',
    labels:[{x:-152,y:-98,z:24,s:1,a:1,t:'608 bearing'},{x:58,y:-30,z:-46,s:1,a:1,t:'XT60 connector'},
            {x:156,y:46,z:34,s:1,a:1,t:'motor mount'},{x:-48,y:38,z:70,s:1,a:1,t:'hex bolt'}]});
  var c2 = $c('#cloud2');
  if (c2) Cloud(c2, {cx:.5, cy:.56, scale:1.05, spin:-.018, alpha:.4, track:false, ink:'rgba(21,65,48,', labels:[]});

  /* ---------------- weave ---------------- */
  var weaveCanvas = $c('#weave');
  if (weaveCanvas && !reduced){
    var weave = weaveCanvas;
    var wc2d: CanvasRenderingContext2D | null = null;
      try { wc2d = weave.getContext('2d'); } catch { wc2d = null; }
      if (wc2d){
      var wc = wc2d;
      var ww = 0, wh = 0, wd = Math.min(devicePixelRatio||1,2);
    function wsize(){
      ww = weave.clientWidth; wh = weave.clientHeight;
      if (!ww || !wh) return;
      weave.width = ww*wd; weave.height = wh*wd; wc.setTransform(wd,0,0,wd,0,0);
    }
    on(window, 'resize', wsize); wsize();
    var w0 = performance.now();
    (function wdraw(now: number){
      if (dead) return;
      if (!ww || !wh){ wsize(); raf(wdraw); return; }
      if (!a1Live()){ raf(wdraw); return; }
      var t = (now - w0)/1000;
      wc.clearRect(0,0,ww,wh);
      var step = ww < 700 ? 58 : 76;
      for (var x = step/2; x < ww; x += step){
        for (var y = step/2; y < wh; y += step){
          var d = Math.sin(x*.012 + y*.016 + t*.8);
          var a = .05 + Math.max(0,d)*.22, s = 1.2 + Math.max(0,d)*1.6;
          wc.fillStyle = 'rgba(147,171,158,' + a.toFixed(3) + ')';
          wc.fillRect(x - s/2, y - s/2, s, s);
        }
      }
      raf(wdraw);
      })(performance.now());
      }
  }

  onScroll();

  return function destroy() {
    dead = true;
    for (var i = 0; i < offs.length; i++) offs[i]();
    for (var t = 0; t < timers.length; t++) window.clearTimeout(timers[t]);
    if (typing) window.clearInterval(typing);
    offs = [];
    timers = [];
  };
}
