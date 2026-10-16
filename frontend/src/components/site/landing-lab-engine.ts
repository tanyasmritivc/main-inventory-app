// Exact Lab prototype formulas. React renders once; the engine updates bound DOM nodes.
export const initialLabState = { W: 1440, H: 900, still: false, prog: 0, hp: 0, sp: -1, seg: 1, ge: 1, gp: 1, zp: 0, ap: 1, own: 1, wp: 1, fp: 1, vp: 1, ep: 1,
      ci: 0, qn: 999, an: 999, phase: 'hold' as 'hold' | 'q' | 'think' | 'a', askOn: false, seen: 3, email: '', joined: false, err: false, mk: {} as Record<string, number>, gx: 0 };
export type LabState = typeof initialLabState;
export function landingLabValues(state: LabState = initialLabState) {

    const S = state, W = S.W || 1440, H = S.H || 900, narrow = W < 860;
    const c = (v: number) => Math.max(0, Math.min(1, v)), ss = (t: number) => t * t * (3 - 2 * t), L = (a: number, b: number, t: number) => a + (b - a) * t;
    const pinH = Math.min(H, 860);
    const MK = S.mk || {}, kOf = (id: string) => ss(MK[id] == null ? 1 : MK[id]);
    const card = (id: string, bg: string, pad: string) => { const k = kOf(id); return 'background:' + bg + ';padding:' + pad + ';margin:0 ' + ((1 - k) * (narrow ? 10 : 72)).toFixed(1) + 'px;border-radius:' + ((1 - k) * 40).toFixed(1) + 'px'; };
    const rise = (id: string) => { const k = kOf(id); return 'opacity:' + (.15 + .85 * k).toFixed(3) + ';transform:translateY(' + ((1 - k) * 56).toFixed(1) + 'px)'; };
    const seeSec = card('see', '#EAEAEA', '130px 0'), askSec = card('ask', '#EAEAEA', '130px 0'), visSec = card('vision', '#EAEAEA', '130px 0');
    const wlCard = card('waitlist', '#000', '120px 24px') + ';color:#FFF;text-align:center';
    const findSec = 'padding-top:150px;padding-bottom:130px;' + rise('find');

    /* hero */
    const hm = ss(c(S.hp * 2.4));
    const heroSec = 'padding:0 ' + (hm * (narrow ? 12 : 28)).toFixed(1) + 'px';
    const heroBox = 'position:relative;height:' + (narrow ? 640 : 800) + 'px;border-radius:' + (hm * 28).toFixed(1) + 'px;overflow:hidden;background:#0B0B0B;transform:scale(' + (1 - .05 * S.hp).toFixed(4) + ');transform-origin:50% 0';
    const progBar = 'height:2px;background:#000;transform-origin:0 50%;transform:scaleX(' + S.prog.toFixed(4) + ')';
    const heroCopy = 'position:absolute;left:0;right:0;top:' + (narrow ? 70 : 96) + 'px;text-align:center;padding:0 20px;pointer-events:none;opacity:' + (1 - c(S.hp * 1.8)).toFixed(3) + ';transform:translateY(' + (-S.hp * 60).toFixed(1) + 'px)';
    const scanCount = S.seen + ' object' + (S.seen === 1 ? '' : 's') + ' in view';

    /* statement: words rise out of blur */
    const text = 'You don\'t organize your physical world for FindEZ. FindEZ organizes it for you.'.split(' ');
    const lit = S.sp < 0 ? text.length : S.sp * text.length * 1.2;
    const words = text.map((t, i) => { const o = c(lit - i); return { t, style: 'display:inline-block;margin-right:.24em;transition:all .5s;color:' + (i >= 7 ? '#E8590C' : '#000') + ';opacity:' + (.12 + .88 * o).toFixed(3) + ';filter:blur(' + ((1 - o) * 6).toFixed(1) + 'px);transform:translateY(' + ((1 - o) * 14).toFixed(1) + 'px)' }; });

    /* phones: real app screens */
    const pa = S.sp < 0 ? 1 : ss(c(S.sp * 1.4));
    const phoneA = 'width:' + (narrow ? 220 : 280) + 'px;transform-origin:50% 100%;transform:translateY(' + ((1 - pa) * 90).toFixed(1) + 'px) rotateX(' + ((1 - pa) * 18).toFixed(2) + 'deg) rotateZ(' + ((1 - pa) * -6).toFixed(2) + 'deg) scale(' + (.9 + .1 * pa).toFixed(4) + ');opacity:' + (.3 + .7 * pa).toFixed(3);
    const benchBox = 'position:relative;border-radius:14px;overflow:hidden;background:#E2E2E2;margin-right:' + (narrow ? 0 : 110) + 'px';
    const pb = ss(c((S.seg - .5) / .4));
    const phoneB = 'position:absolute;right:0;bottom:-56px;width:172px;transform:translateY(' + ((1 - pb) * 90).toFixed(1) + 'px) rotate(' + ((1 - pb) * 8).toFixed(2) + 'deg);opacity:' + pb.toFixed(3);
    const FAN = [['/images/landing-lab/app-capture.jpg', 'Capture', 'Capture: every object in the photo becomes its own row'],
      ['/images/landing-lab/app-review.jpg', 'Review', 'Review: anything uncertain waits for your OK'],
      ['/images/landing-lab/app-home.jpg', 'Home', 'Home: what needs a decision and where things live'],
      ['/images/landing-lab/app-ask.jpg', 'Ask', 'Ask: plain questions answered from what you own']];
    const fanList = narrow ? [FAN[0], FAN[2], FAN[3]] : FAN, nf = fanList.length, mid = (nf - 1) / 2;
    const pw = narrow ? Math.min(150, (W - 44) / 3.15) : 232, gap = narrow ? 10 : 34, ff = ss(S.fp);
    const fanBox = 'position:relative;height:' + Math.round(pw * 999 / 460 + 110) + 'px;margin-top:64px';
    const fan = fanList.map((f, i) => {
      const d = i - mid, x = L(d * 20, d * (pw + gap), ff), y = L(Math.abs(d) * 14, (i % 2 ? 40 : 0), ff), rot = L(d * 6, 0, ff);
      return { src: f[0], t: f[1], alt: f[2],
        wrap: 'position:absolute;left:50%;top:0;width:' + pw.toFixed(0) + 'px;margin-left:' + (-pw / 2).toFixed(0) + 'px;z-index:' + (10 - Math.round(Math.abs(d) * 2)) + ';transform:translate(' + x.toFixed(1) + 'px,' + y.toFixed(1) + 'px) rotate(' + rot.toFixed(2) + 'deg)',
        lab: 'text-align:center;color:#8C8C8C;margin-top:16px;opacity:' + c((S.fp - .75) / .25).toFixed(3) };
    });

    /* detection on the real workbench photo: [label, confidence, x, y, w, h] in an 800 x 520 frame */
    const SEG: [string, number, number, number, number, number, number?, number?][] = [
      ['parts cabinet', 0.96, 105, 4, 420, 170], ['parts cabinet', 0.95, 558, 4, 238, 171],
      ['battery charger 18V', 0.97, 387, 122, 212, 165], ['duct tape', 0.93, 287, 232, 100, 61],
      ['socket head screws', 0.91, 240, 285, 172, 143], ['hex nuts', 0.90, 22, 171, 122, 77],
      ['button head bolts', 0.86, 246, 152, 64, 55], ['steel shafts', 0.88, 489, 287, 83, 69],
      ['spur gear', 0.84, 196, 303, 44, 23], ['gearbox housings', 0.79, 425, 343, 232, 113],
      ['timing pulleys', 0.74, 4, 276, 84, 144], ['bagged hardware', 0.70, 92, 258, 98, 92, 92, 355],
      ['thrust washer', 0.77, 221, 392, 22, 17, 150, 436],
    ];
    const NS = SEG.length + 1.5, tkOf = (k: number) => c(S.seg * NS - k - .3);
    const seg = SEG.map((g, k) => {
      const tk = tkOf(k), drawn = ss(c(tk / .55)), filled = ss(c((tk - .45) / .45)), unsure = g[1] < .8;
      const label = g[0] + ' ' + g[1].toFixed(2), lw = label.length * 6.75 + 12;
      const inside = g[3] < 26, lx = g[6] != null ? g[6] : Math.min(g[2], 800 - lw - 4), ly = g[7] != null ? g[7] : inside ? g[3] + 8 : g[3] - 24;
      return { x: g[2], y: g[3], w: g[4], h: g[5], label, lw: lw.toFixed(0), lx, ly, tx: lx + 6, ty: ly + 14,
        tag: 'position:absolute;left:' + (lx / 8).toFixed(3) + '%;top:' + (ly / 5.2).toFixed(3) + '%;height:2.5cqw;line-height:2.5cqw;padding:0 .75cqw;border-radius:.5cqw;background:' + (unsure ? '#E8590C' : '#FFFFFF') + ';color:#111112;font-family:var(--fzl-mono),monospace;font-size:1.375cqw;white-space:nowrap;opacity:' + filled.toFixed(3) + ';transition:opacity .3s',
        hole: 'opacity:' + filled.toFixed(3),
        line: 'stroke:' + (unsure ? '#E8590C' : '#FFFFFF') + ';stroke-width:2.5;stroke-dasharray:1;stroke-dashoffset:' + (1 - drawn).toFixed(3),
      };
    });
    const segDim = 'opacity:' + (.42 * ss(c(S.seg * 4))).toFixed(3);
    const segCount = SEG.filter((g, k) => tkOf(k) > .6).length, segReview = SEG.filter((g, k) => g[1] < .8 && tkOf(k) > .6).length;
    const scanBar = 'x:' + (S.seg * 820).toFixed(0) + 'px;opacity:' + (S.seg > .02 && S.seg < .98 ? 1 : 0);

    /* memory graph */
    const gm = 1 - Math.min(ss(S.ge), 1 - ss(S.gx || 0));
    const graphSec = 'position:relative;background:#000;margin:0 ' + (gm * (narrow ? 16 : 72)).toFixed(1) + 'px;border-radius:' + (gm * 40).toFixed(1) + 'px;height:' + (S.still ? pinH : pinH + 2300) + 'px';
    const pinStyle = (S.still ? 'position:relative' : 'position:sticky;top:0') + ';height:' + pinH + 'px;display:flex;flex-direction:column;justify-content:center;overflow:hidden';
    const pinTop = (S.still ? 'position:relative' : 'position:sticky;top:0') + ';height:' + pinH + 'px;overflow:hidden';
    const zoomBox = 'position:relative;width:' + Math.min(1100, W - 48, (pinH - 290) * 1000 / 560 + 48).toFixed(0) + 'px;max-width:100%;box-sizing:border-box;margin:28px auto 0;padding:0 24px';
    const NODES: [string, string, number, number, string][] = [['Location', 'Workshop › Workbench', 70, 90, 'lives in'], ['Purchase', 'March · $49', 720, 80, 'bought'], ['Documents', 'Manual · Receipt', 760, 290, 'has'],
      ['Works with', '18V drill batteries', 700, 500, 'charges'], ['Project', 'Drivetrain rebuild', 90, 500, 'used for'], ['Last seen', 'Today, in your bench photo', 20, 290, 'seen']];
    const nodes: { k: string; v: string; ks: string; box: string }[] = [], edges: { d: string; rel: string; lab: string; style: string }[] = [];
    NODES.forEach((nd, k) => {
      const t = ss(c(S.gp * 7.2 - k - .3)), w = Math.max(nd[1].length * 9 + 40, 170);
      const cx = nd[2] + w / 2, cy = nd[3] + 27;
      nodes.push({ k: nd[0].toUpperCase(), v: nd[1],
        ks: 'font-family:var(--fzl-mono),monospace;font-size:1cqw;letter-spacing:.05em;color:' + (k === 1 || k === 3 ? '#F08A4B' : '#8C8C8C'),
        box: 'position:absolute;left:' + (nd[2] / 10) + '%;top:' + (nd[3] / 6.4) + '%;width:' + (w / 10) + '%;height:' + (54 / 6.4) + '%;box-sizing:border-box;background:#111;border:1px solid rgba(255,255,255,' + (.25 + .35 * t).toFixed(2) + ');border-radius:1cqw;padding:0 1.8cqw;display:flex;flex-direction:column;justify-content:center;opacity:' + t.toFixed(3) + ';transform:scale(' + (.85 + .15 * t).toFixed(3) + ')' });
      const mx = (cx + 500) / 2, my = (cy + 320) / 2;
      edges.push({ d: 'M500 320 Q' + mx + ' ' + (my - 40) + ' ' + cx + ' ' + cy, rel: nd[4],
        lab: 'position:absolute;left:' + (mx / 10) + '%;top:' + ((my - 34) / 6.4) + '%;transform:translate(-50%,-50%);font-family:var(--fzl-mono),monospace;font-size:1.1cqw;color:#8C8C8C;white-space:nowrap;opacity:' + t.toFixed(3),
        style: 'stroke-dasharray:1;stroke-dashoffset:' + (1 - ss(c(S.gp * 7.2 - k))).toFixed(3) });
    });

    /* infinite zoom through the location hierarchy */
    const zoomSec = 'position:relative;height:' + (S.still ? pinH : pinH + 2900) + 'px';
    // camera stops on the real photo, in a 1600 x 1200 frame: [cx, cy, width]
    const CAM = [[800, 600, 1600], [760, 470, 1300], [630, 269, 960], [800, 182, 640], [986, 152, 250]];
    const z = S.zp * 4, zi = Math.min(3, Math.floor(z)), zr = z - zi, zf = ss(c((zr - .3) / .7));
    const CA = CAM[zi], CB = CAM[zi + 1], lg = Math.log;
    const cw = Math.exp(L(lg(CA[2]), lg(CB[2]), zf)), ch = cw * .56;
    const cx = L(CA[0], CB[0], zf), cy = L(CA[1], CB[1], zf), x0 = cx - cw / 2, y0 = cy - ch / 2;
    const zImg = 'position:absolute;max-width:none;height:auto;width:' + (1600 / cw * 100).toFixed(3) + '%;left:' + (-x0 / cw * 100).toFixed(3) + '%;top:' + (-y0 / ch * 100).toFixed(3) + '%';
    const TG: [string, number, number, number, number][] = [['Workbench', 20, 110, 1560, 980], ['Parts cabinet', 205, 2, 850, 432], ['Row 5', 236, 112, 812, 84], ['Drawer PN-F40', 935, 114, 102, 74]];
    const zBoxes = TG.map((g, k) => {
      const vis = k === 3 ? c((z - 2.2) / .5) : c((z - (k - .2)) / .4) * (1 - c((z - (k + .55)) / .3)), last = k === 3;
      return { t: g[0].toUpperCase(),
        box: 'position:absolute;box-sizing:border-box;left:' + ((g[1] - x0) / cw * 100).toFixed(3) + '%;top:' + ((g[2] - y0) / ch * 100).toFixed(3) + '%;width:' + (g[3] / cw * 100).toFixed(3) + '%;height:' + (g[4] / ch * 100).toFixed(3) + '%;border:2px solid ' + (last ? '#E8590C' : '#FFFFFF') + ';border-radius:.6cqw;box-shadow:0 0 0 9999px rgba(17,17,18,' + (.4 * vis).toFixed(3) + ');opacity:' + vis.toFixed(3),
        tag: 'position:absolute;left:-2px;bottom:100%;margin-bottom:.5cqw;white-space:nowrap;font-family:var(--fzl-mono),monospace;font-size:1.15cqw;letter-spacing:.05em;padding:.3cqw .7cqw;border-radius:.4cqw;color:#111112;background:' + (last ? '#E8590C' : '#FFFFFF') };
    });
    const zc = c((z - 3.55) / .4);
    const zCard = 'position:absolute;left:3cqw;bottom:3cqw;background:#FFFFFF;border-radius:1.2cqw;padding:1.6cqw 2cqw;box-shadow:0 20px 40px -20px rgba(0,0,0,.5);opacity:' + zc.toFixed(3) + ';transform:translateY(' + ((1 - zc) * 2).toFixed(2) + 'cqw)';
    const LV = ['Workshop', 'Workbench', 'Parts cabinet', 'Row 5', 'Drawer PN-F40', 'M4 set screws'];
    const curLv = z >= 3.85 ? 5 : Math.round(z);
    const crumbs: { t: string; style: string }[] = [];
    LV.forEach((t, i) => { const on = i <= curLv; if (i) crumbs.push({ t: '›', style: 'color:#BDBDBD;opacity:' + (on ? 1 : .3) }); crumbs.push({ t, style: 'transition:color .3s;color:' + (i === curLv ? (i === 5 ? '#C2410C' : '#000') : on ? '#6B6B6B' : '#D0D0D0') }); });

    /* typing chat */
    const CHATS = [
      { q: 'Where are my batteries?', a: 'AA batteries in the office desk drawer. The garage pack has 18 left.', ctx: ['Items · 2', 'Spaces · 2', 'Quantities'] },
      { q: 'Do I already own a USB-C hub?', a: 'Yes. You have two similar hubs, one in the workshop and one in your desk drawer.', ctx: ['Visual match', 'Items · 2'] },
      { q: 'What do I need to finish my robot?', a: 'You have 18 of the 22 parts. Missing a motor controller and 4 bearings.', ctx: ['Project', 'Requirements', 'Inventory'] },
      { q: 'When did I buy the battery charger?', a: 'In March, for $49. The receipt and manual are attached to it, and it lives on the workbench.', ctx: ['Purchase', 'Documents', 'Location'] },
    ];
    const cur = CHATS[S.ci % CHATS.length];
    const chatQ = cur.q.slice(0, S.qn), chatA = S.phase === 'q' || S.phase === 'think' ? '' : cur.a.slice(0, S.an);
    const ctxOn = S.phase === 'hold';
    const chatCtx = cur.ctx.map((t) => ({ t, style: 'color:#6B6B6B;background:#F2F2F2;border-radius:6px;padding:6px 9px;transition:opacity .3s;opacity:' + (ctxOn ? 1 : 0) }));

    const am = 1 - ss(S.ap);
    const askCard = 'background:#FFF;border-radius:16px;padding:28px;min-height:360px;box-sizing:border-box;display:flex;flex-direction:column;gap:16px;box-shadow:0 30px 60px -30px rgba(0,0,0,' + (.25 * (1 - am)).toFixed(3) + ');transform:perspective(1400px) rotateX(' + (am * 18).toFixed(2) + 'deg) translateY(' + (am * 60).toFixed(1) + 'px) scale(' + (1 - am * .06).toFixed(4) + ');transform-origin:50% 100%;opacity:' + (.3 + .7 * (1 - am)).toFixed(3);
    const whoSec = card('who', '#000', '120px 0') + ';color:#FFF';


    /* do I own this */
    const op = S.own, slide = ss(c(op / .35)), match = c((op - .35) / .35), done = c((op - .7) / .2);
    const ownProd = 'transform:translateX(' + ((1 - slide) * 420).toFixed(1) + 'px);transition:transform .1s';
    const ownBox = 'stroke:#FFFFFF;stroke-width:1.5;stroke-dasharray:6 5;opacity:' + match.toFixed(3);
    const ownRing = 'stroke-dasharray:' + (match * 92).toFixed(1) + ' 100';
    const ownPct = Math.round(match * 92) + '%';
    const ownLabel = 'opacity:' + match.toFixed(3);
    const ownCard = 'margin-top:30px;background:#F2F2F2;border-radius:12px;padding:22px 24px;opacity:' + done.toFixed(3) + ';transform:translateY(' + ((1 - done) * 16).toFixed(1) + 'px)';

    /* who rows */
    const A = ['Families', 'Students', 'Makers', 'Robotics teams', 'Makerspaces', 'Schools', 'Labs', 'Roommates'];
    const B = ['Small businesses', 'Contractors', 'Warehouses', 'Organizations', 'Studios', 'Workshops', 'Offices', 'Equipment teams'];
    const tone = ['#1A1A1A', '#E8590C', '#2A2A2A', '#3B3247', '#1A1A1A', '#3A3226'];
    const row = (arr: string[], off: number) => arr.concat(arr).map((t, i) => ({ t, s: 'background:' + tone[(i + off) % tone.length] + ';color:' + (tone[(i + off) % tone.length] === '#E8590C' ? '#111112' : '#FFF') }));
    const rowA = row(A, 0), rowB = row(B, 3);

    /* pipeline flow */
    const PN: [string, string, number][] = [['Perceive', 'WHAT IS HERE', 140], ['Identify', 'WHAT IS IT', 330], ['Confidence', 'HOW SURE', 520], ['Context', 'WHERE · LINKS', 710], ['Memory', 'SAVED', 900]];
    const pipeNodes = PN.map(p => ({ t: p[0], d: p[1], s: 'position:absolute;left:' + (p[2] / 11).toFixed(3) + '%;top:' + (172 / 3.2).toFixed(3) + '%;transform:translateX(-50%);text-align:center;white-space:nowrap' }));
    const MAIN = 'M60 150 H1040', BR = 'M60 150 H520 C520 250 710 250 710 150 H1040', LOOP = 'M900 150 C900 40 140 40 140 150';
    const flow = [0, 1, 2, 3, 4, 5].map(i => ({ r: 5, c: '#000', path: MAIN, dur: '6s', begin: (-i).toFixed(1) + 's' }))
      .concat([0, 1].map(i => ({ r: 5, c: '#79648C', path: BR, dur: '8s', begin: (-i * 4).toFixed(1) + 's' })))
      .concat([0, 1].map(i => ({ r: 4, c: '#A8927C', path: LOOP, dur: '7s', begin: (-i * 3.5).toFixed(1) + 's' })));

    /* roadmap */
    const ST = [['Inventory', 'Live', 'Every item captured from a photo, counted and placed.'],
      ['Memory', 'Live', 'Where it lives, when you got it, the manual and its history.'],
      ['Context', 'Building now', 'Projects, rooms and what belongs together.'],
      ['Intelligence', 'Next', 'Knows what you will need before you run out.'],
      ['Action', 'Later', 'Finds things in the room and acts on what it knows.']];
    const vp = S.vp, visHead = 'opacity:' + (.15 + .85 * ss(c(vp * 3))).toFixed(3) + ';transform:translateY(' + ((1 - ss(c(vp * 3))) * 40).toFixed(1) + 'px)';
    const stages = ST.map((g, k) => {
      const t = ss(c(vp * 5 - k * .55 - .6)), done = k < 2, cur = k === 2;
      return { t: g[0], st: g[1], d: g[2],
        wrap: 'text-align:center;opacity:' + t.toFixed(3) + ';transform:translateY(' + ((1 - t) * 34).toFixed(1) + 'px)',
        node: 'position:relative;z-index:1;width:32px;height:32px;margin:0 auto;border-radius:50%;box-sizing:border-box;transform:scale(' + (.5 + .5 * t).toFixed(3) + ');' + (done ? 'background:#E8590C' : cur ? 'background:#FFFFFF;border:2px solid #E8590C;box-shadow:inset 0 0 0 7px #FFFFFF,inset 0 0 0 16px #E8590C' : 'background:#FFFFFF;border:2px solid #CFCFCF'),
        chip: 'display:inline-block;margin-top:10px;font-family:var(--fzl-mono),monospace;font-size:11px;letter-spacing:.05em;text-transform:uppercase;padding:4px 9px;border-radius:999px;' + (done ? 'background:#FBE1D2;color:#B33F08' : cur ? 'background:#111112;color:#FFFFFF' : 'background:#E0E0E0;color:#7A7A7A') };
    });
    const fill = 50 * ss(c(vp * 2.2 - .5));
    const roadFill = 'position:absolute;left:0;top:0;height:2px;background:#E8590C;width:' + fill.toFixed(2) + '%';
    const roadDot = 'position:absolute;top:-6px;left:calc(' + fill.toFixed(2) + '% - 7px);width:14px;height:14px;border-radius:50%;background:#E8590C;opacity:' + c(fill / 10).toFixed(3) + ';animation:fzl-vpulse 2s ease-out infinite';

    /* footer wordmark: letters settle in */
    const GL = [
      ['M579.0 -647.0V-729.0H90.0V0.0H183.0V-332.0H531.0V-414.0H183.0V-647.0Z', '#111112'],
      ['M719.0 0.0V-524.0H636.0V0.0ZM730.0 -603.0V-707.0H626.0V-603.0Z', '#111112'],
      ['M1230.0 0.0V-396.0C1230.0 -483.0 1165.0 -539.0 1064.0 -539.0C986.0 -539.0 936.0 -509.0 890.0 -436.0V-524.0H813.0V0.0H896.0V-289.0C896.0 -396.0 954.0 -466.0 1039.0 -466.0C1105.0 -466.0 1147.0 -426.0 1147.0 -363.0V0.0Z', '#111112'],
      ['M1749.0 0.0V-729.0H1666.0V-458.0C1631.0 -511.0 1575.0 -539.0 1505.0 -539.0C1369.0 -539.0 1280.0 -434.0 1280.0 -267.0C1280.0 -90.0 1367.0 15.0 1508.0 15.0C1580.0 15.0 1630.0 -12.0 1675.0 -77.0V0.0ZM1666.0 -260.0C1666.0 -139.0 1608.0 -63.0 1520.0 -63.0C1428.0 -63.0 1367.0 -140.0 1367.0 -262.0C1367.0 -384.0 1428.0 -461.0 1519.0 -461.0C1609.0 -461.0 1666.0 -381.0 1666.0 -260.0Z', '#111112'],
      ['M2378.0 0.0V-82.0H1948.0V-332.0H2345.0V-414.0H1948.0V-647.0H2360.0V-729.0H1855.0V0.0Z', '#E8590C'],
      ['M2970.0 0.0V-82.0H2532.0L2968.0 -645.0V-729.0H2443.0V-647.0H2853.0L2415.0 -82.0V0.0Z', '#E8590C']];
    const letters = GL.map((g, i) => { const t = ss(c((S.ep - .1 - i * .06) / .55)); return { d: g[0], fill: g[1], style: 'opacity:' + (.08 + .92 * t).toFixed(3) + ';transform:translateY(' + ((1 - t) * (700 + i * 160)).toFixed(0) + 'px)' }; });
    const mk = ss(c(S.ep / .45));
    const markA = 'stroke-dasharray:1;stroke-dashoffset:' + (1 - mk).toFixed(3), markB = 'stroke-dasharray:1;stroke-dashoffset:' + (1 - ss(c((S.ep - .2) / .4))).toFixed(3);

    return {
      phoneA, benchBox, phoneB, fanBox, fan, markA, markB,
      segDim, heroSec, heroBox, heroCopy, progBar, pinTop, zoomBox, askCard, whoSec, scanCount, words, seg, segCount, segReview, scanBar,
      graphSec, pinStyle, nodes, edges, zoomSec, zImg, zBoxes, zCard, crumbs,
      chatQ, chatA, chatCtx, typingQ: S.phase === 'q', typingA: S.phase === 'a', thinking: S.phase === 'think',
      ownProd, ownBox, ownRing, ownPct, ownLabel, ownCard, rowA, rowB, pipeNodes, flow, stages, roadFill, roadDot, visHead, seeSec, askSec, visSec, wlCard, findSec, letters,
      email: S.email,
      joined: S.joined, notJoined: !S.joined, emailErr: S.err,
    };
}

const LAB_CHATS = [
      { q: 'Where are my batteries?', a: 'AA batteries in the office desk drawer. The garage pack has 18 left.', ctx: ['Items · 2', 'Spaces · 2', 'Quantities'] },
      { q: 'Do I already own a USB-C hub?', a: 'Yes. You have two similar hubs, one in the workshop and one in your desk drawer.', ctx: ['Visual match', 'Items · 2'] },
      { q: 'What do I need to finish my robot?', a: 'You have 18 of the 22 parts. Missing a motor controller and 4 bearings.', ctx: ['Project', 'Requirements', 'Inventory'] },
      { q: 'When did I buy the battery charger?', a: 'In March, for $49. The receipt and manual are attached to it, and it lives on the workbench.', ctx: ['Purchase', 'Documents', 'Location'] },
    ];
type Binding = { element: Element; kind: string; path: string; previous?: unknown };
function atPath(value: unknown, path: string): unknown {
  return path.split(".").reduce<unknown>((current, key) =>
    current != null && typeof current === "object" ? (current as Record<string, unknown>)[key] : undefined, value);
}
class LabEngine {
  state: LabState = { ...initialLabState, mk: {} };
  reduce = false;
  disposed = false;
  mouse: { x: number; y: number } | null = null;
  lastMove = 0;
  raf = 0;
  paintRaf = 0;
  glideRaf = 0;
  fieldLoop = 0;
  chat = 0;
  hold = 0;
  wait = 0;
  cur = 0;
  target = 0;
  gliding = false;
  cleanups: (() => void)[] = [];
  bindings: Binding[] = [];
  constructor(private root: HTMLElement) {
    this.onScroll = this.onScroll.bind(this);
    this.onWheel = this.onWheel.bind(this);
    this.glide = this.glide.bind(this);
    root.querySelectorAll("*").forEach(element => {
      for (const attr of element.attributes) {
        if (attr.name.startsWith("data-lab-") && attr.name !== "data-lab-join") {
          this.bindings.push({ element, kind: attr.name.slice(9), path: attr.value, previous: Symbol("unpainted") });
        }
      }
    });
  }
  setState(patch: Partial<LabState>) {
    Object.assign(this.state, patch);
    if (!this.paintRaf && !this.disposed) this.paintRaf = requestAnimationFrame(() => {
      this.paintRaf = 0;
      this.paint();
    });
  }
  paint() {
    if (this.disposed) return;
    const values = landingLabValues(this.state);
    for (const binding of this.bindings) {
      const { element, kind, path } = binding;
      const value = atPath(values, path);
      if (value === binding.previous) continue;
      binding.previous = value;
      if (kind === "row" || kind === "show") {
        element.toggleAttribute("hidden", kind === "row" ? value == null : !value);
      } else if (kind === "text") {
        element.textContent = value == null ? "" : String(value);
      } else if (value != null) {
        element.setAttribute(kind, String(value));
      }
    }
  }
  mount() {
    const previousScrollBehavior = document.documentElement.style.scrollBehavior;
    document.documentElement.style.scrollBehavior = "auto";
    const motion = matchMedia("(prefers-reduced-motion: reduce)");
    const updateMotion = () => {
      this.reduce = motion.matches;
      cancelAnimationFrame(this.fieldLoop);
      cancelAnimationFrame(this.glideRaf);
      this.gliding = false;
      this.cleanups.splice(0).forEach(cleanup => cleanup());
      this.root.querySelectorAll<SVGSVGElement>("svg").forEach(svg => {
        if (this.reduce) { svg.pauseAnimations(); svg.setCurrentTime(0); }
        else svg.unpauseAnimations();
      });
      this.onScroll();
      this.startField();
    };
    updateMotion();
    motion.addEventListener("change", updateMotion);
    window.addEventListener("scroll", this.onScroll, { passive: true, capture: true });
    window.addEventListener("resize", this.onScroll);
    window.addEventListener("wheel", this.onWheel, { passive: false });
    this.chat = window.setInterval(() => this.chatTick(), 40);
    const email = this.root.querySelector<HTMLInputElement>("#em");
    const button = this.root.querySelector<HTMLButtonElement>("[data-lab-join]");
    const onEmail = () => this.setState({ email: email?.value || "", err: false });
    // TODO: Preview only. Connect an approved waitlist service before publication.
    // This handler intentionally sends no request and only shows the confirmation.
    const join = () => {
      const ok = /.+@.+\..+/.test(email?.value || "");
      this.setState(ok ? { email: email!.value, joined: true, err: false } : { err: true });
    };
    const onKey = (event: KeyboardEvent) => { if (event.key === "Enter") { event.preventDefault(); join(); } };
    email?.addEventListener("input", onEmail);
    email?.addEventListener("keydown", onKey);
    button?.addEventListener("click", join);
    void document.fonts.ready.then(() => { if (!this.disposed) this.onScroll(); });
    return () => {
      this.disposed = true;
      document.documentElement.style.scrollBehavior = previousScrollBehavior;
      motion.removeEventListener("change", updateMotion);
      window.removeEventListener("scroll", this.onScroll, true);
      window.removeEventListener("resize", this.onScroll);
      window.removeEventListener("wheel", this.onWheel);
      email?.removeEventListener("input", onEmail);
      email?.removeEventListener("keydown", onKey);
      button?.removeEventListener("click", join);
      [this.raf, this.paintRaf, this.glideRaf, this.fieldLoop].forEach(cancelAnimationFrame);
      clearInterval(this.chat);
      this.cleanups.forEach(cleanup => cleanup());
    };
  }
  startField() {
    const cv = this.root.querySelector<HTMLCanvasElement>('#fzField'); if (!cv) return;
    const ctx = cv.getContext('2d'); if (!ctx) return;
    const img = new Image(); let ready = false;
    // objects in the real workbench photo (1448 x 1086): [name, confidence, x, y, w, h]
    const OBJ: [string, number, number, number, number, number][] = [['needle-nose pliers', .96, 230, 655, 650, 295], ['aluminum standoffs', .91, 175, 460, 230, 240], ['aluminum U-channel', .89, 735, 280, 595, 320],
      ['socket head screws', .88, 745, 570, 255, 135], ['servo hub', .78, 105, 905, 140, 130], ['crimp terminals', .84, 25, 310, 160, 140],
      ['rubber O-ring', .76, 300, 385, 155, 135], ['button head screws', .90, 565, 120, 135, 125], ['bagged bearings', .72, 1005, 30, 443, 300],
      ['hex nuts', .85, 1125, 640, 140, 95], ['cable clamps', .74, 850, 680, 55, 55], ['shipping box', .93, 0, 480, 200, 520],
      ['parts cabinet', .95, 70, 0, 840, 275], ['hardware pack', .70, 700, 450, 180, 150], ['pillow block bearing', .73, 950, 520, 250, 210], ['clear storage bin', .94, 330, 230, 400, 450]];
    let W = 0, H = 0, dpr = 1, sc = 1, ox = 0, oy = 0;
    const lens = { x: 0, y: 0 };
    const build = () => {
      const r = cv.getBoundingClientRect(); dpr = Math.min(2, window.devicePixelRatio || 1);
      W = r.width; H = r.height; cv.width = W * dpr; cv.height = H * dpr;
      sc = Math.max(W / 1448, H / 1086); ox = (W - 1448 * sc) / 2; oy = (H - 1086 * sc) * .3;
      lens.x = W * .5; lens.y = H * .71;
    };
    const photo = () => ctx.drawImage(img, ox, oy, 1448 * sc, 1086 * sc);
    const draw = (now: number) => {
      if (this.disposed) return;
      if (Math.abs(cv.getBoundingClientRect().width - W) > 1) build();
      const t = (now || 0) / 1000;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = '#0B0B0B'; ctx.fillRect(0, 0, W, H);
      const idle = !this.mouse || now - this.lastMove > 2600;
      const tx = idle ? W * (.5 + .36 * Math.sin(t * .33)) : this.mouse!.x, ty = idle ? H * (.71 + .07 * Math.sin(t * .51)) : this.mouse!.y;
      lens.x += (tx - lens.x) * (this.reduce ? 1 : .08); lens.y += (ty - lens.y) * (this.reduce ? 1 : .08);
      const R = W < 700 ? 95 : 150;
      let seen = 0;
      if (ready) {
        photo(); ctx.fillStyle = 'rgba(11,11,11,.62)'; ctx.fillRect(0, 0, W, H);
        // inside the lens: the photo at full brightness, with every object it covers outlined
        ctx.save(); ctx.beginPath(); ctx.arc(lens.x, lens.y, R, 0, 7); ctx.clip(); photo();
        const hits: [[string, number, number, number, number, number], number, number, number, number][] = [];
        OBJ.forEach(o => {
          const x = ox + o[2] * sc, y = oy + o[3] * sc, w = o[4] * sc, h = o[5] * sc;
          if (Math.hypot(x + w / 2 - lens.x, y + h / 2 - lens.y) < R * .95) {
            seen++; hits.push([o, x, y, w, h]);
            const unsure = o[1] < .8;
            ctx.strokeStyle = unsure ? '#E8590C' : '#FFFFFF'; ctx.lineWidth = 2; ctx.setLineDash(unsure ? [5, 4] : []);
            ctx.strokeRect(x, y, w, h); ctx.setLineDash([]);
          }
        });
        ctx.restore();
        hits.forEach(([o, x, y]) => {
          const lab = o[0] + ' ' + o[1].toFixed(2); ctx.font = '500 11px ' + getComputedStyle(this.root).getPropertyValue('--fzl-mono') + ', monospace';
          const lw = ctx.measureText(lab).width + 12;
          const lx = Math.max(lens.x - R, Math.min(x, lens.x + R - lw)), ly = Math.max(lens.y - R - 10, Math.min(y - 20, lens.y + R - 10));
          ctx.fillStyle = o[1] < .8 ? '#E8590C' : '#FFFFFF'; ctx.fillRect(lx, ly, lw, 18);
          ctx.fillStyle = '#111112'; ctx.fillText(lab, lx + 6, ly + 13);
        });
      }
      ctx.strokeStyle = 'rgba(255,255,255,.75)'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(lens.x, lens.y, R, 0, 7); ctx.stroke();
      ctx.strokeStyle = 'rgba(255,255,255,.35)';
      for (let k = 0; k < 48; k++) { const a = k / 48 * Math.PI * 2 + t * .25, r1 = R + 6, r2 = R + (k % 4 ? 10 : 16);
        ctx.beginPath(); ctx.moveTo(lens.x + Math.cos(a) * r1, lens.y + Math.sin(a) * r1); ctx.lineTo(lens.x + Math.cos(a) * r2, lens.y + Math.sin(a) * r2); ctx.stroke(); }
      ctx.strokeStyle = '#E8590C'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(lens.x - 8, lens.y); ctx.lineTo(lens.x + 8, lens.y); ctx.moveTo(lens.x, lens.y - 8); ctx.lineTo(lens.x, lens.y + 8); ctx.stroke();
      if (seen !== this.state.seen) this.setState({ seen });
      if (!this.reduce) this.fieldLoop = requestAnimationFrame(draw);
    };
    const move = (e: MouseEvent | TouchEvent) => { const r = cv.getBoundingClientRect(), p = 'touches' in e ? e.touches[0] : e; this.mouse = { x: p.clientX - r.left, y: p.clientY - r.top }; this.lastMove = performance.now(); };
    cv.addEventListener('mousemove', move); cv.addEventListener('touchmove', move, { passive: true });
    const resize = () => { build(); if (this.reduce) draw(0); };
    window.addEventListener('resize', resize);
    img.onload = () => { ready = true; if (this.reduce) draw(performance.now()); };
    img.src = '/images/landing-lab/hero.jpg';
    build();
    if (!this.reduce) this.fieldLoop = requestAnimationFrame(draw);
    this.cleanups.push(() => {
      img.onload = null;
      cv.removeEventListener('mousemove', move);
      cv.removeEventListener('touchmove', move);
      window.removeEventListener('resize', resize);
    });
  }

  /* ---------- the typing conversation ---------- */
  chatTick() {
    const S = this.state, C = LAB_CHATS;
    if (!C || !S.askOn || this.reduce) return;
    const cur = C[S.ci];
    if (S.phase === 'hold') { this.hold = (this.hold || 0) + 1; if (this.hold > 70) { this.hold = 0; this.setState({ ci: (S.ci + 1) % C.length, qn: 0, an: 0, phase: 'q' }); } return; }
    if (S.phase === 'q') { if (S.qn < cur.q.length) this.setState({ qn: S.qn + 1 }); else { this.wait = 0; this.setState({ phase: 'think' }); } return; }
    if (S.phase === 'think') { this.wait = (this.wait || 0) + 1; if (this.wait > 18) this.setState({ phase: 'a' }); return; }
    if (S.phase === 'a') { if (S.an < cur.a.length) this.setState({ an: Math.min(cur.a.length, S.an + 3) }); else this.setState({ phase: 'hold' }); }
  }

  onWheel(e: WheelEvent) {
    if (this.reduce || !matchMedia("(pointer: fine)").matches || window.innerWidth < 860) return;
    const target = e.target instanceof Element ? e.target : null;
    if (target?.closest("input, textarea, select, [data-native-scroll]")) return;
    if (e.ctrlKey || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
    const se = document.scrollingElement || document.documentElement, max = se.scrollHeight - window.innerHeight;
    if (max <= 0) return;
    e.preventDefault();
    const dy = e.deltaMode === 1 ? e.deltaY * 16 : e.deltaMode === 2 ? e.deltaY * window.innerHeight : e.deltaY;
    if (!this.gliding) { this.cur = se.scrollTop; this.target = se.scrollTop; }
    this.target = Math.max(0, Math.min(max, this.target + dy * .8));
    if (!this.gliding) { this.gliding = true; this.glideRaf = requestAnimationFrame(this.glide); }
  }
  glide() {
    const se = document.scrollingElement || document.documentElement;
    this.cur += (this.target - this.cur) * .09;
    if (Math.abs(this.target - this.cur) < .5) { this.cur = this.target; this.gliding = false; }
    se.scrollTop = this.cur;
    if (this.gliding) this.glideRaf = requestAnimationFrame(this.glide);
  }

  onScroll() {
    if (this.raf) return;
    this.raf = requestAnimationFrame(() => {
      this.raf = 0;
      const H = window.innerHeight || 900, W = window.innerWidth || 1440;
      const c = (v: number) => Math.max(0, Math.min(1, v));
      const r = (id: string) => { const el = this.root.querySelector<HTMLElement>(`#${id}`); return el ? el.getBoundingClientRect() : null; };
      // Reduced motion uses the prototype finished state without pinned travel.
      if (this.reduce) { this.setState({ W, H, still: true, prog: 0, hp: 0, sp: -1, seg: 1, ge: 1, gp: 1, zp: 1, ap: 1, own: 1, wp: 1, fp: 1, vp: 1, ep: 1, askOn: true, phase: "hold", qn: 999, an: 999, mk: {}, gx: 0 }); return; }
      const pin = Math.min(H, 860), n: Partial<LabState> = { W, H, still: false };
      const se = document.scrollingElement || document.documentElement;
      n.prog = c(se.scrollTop / Math.max(1, se.scrollHeight - H));
      const h = r('hero'); if (h) n.hp = c(-h.top / (h.height * .8));
      const s = r('stmt'); if (s) n.sp = s.top < H ? c((H * .9 - s.top) / (s.height * .9)) : 0;
      const sg = r('see'); if (sg) n.seg = c((H * .85 - sg.top) / (sg.height * .8));
      const g = r('graph'); if (g) { n.ge = c((H - g.top) / H); n.gp = c(-g.top / Math.max(1, g.height - pin)); }
      const z = r('zoom'); if (z) n.zp = c(-z.top / Math.max(1, z.height - pin));
      const a = r('ask'); if (a) { n.askOn = a.top < H && a.bottom > 0; n.ap = c((H - a.top) / (H * .75)); }
      const o = r('own'); if (o) n.own = c((H * .85 - o.top) / (o.height * .75));
      const w = r('who'); if (w) n.wp = c((H - w.top) / (H * .9));
      n.mk = {};
      ['see', 'ask', 'vision', 'who', 'waitlist', 'find'].forEach(id => { const q = r(id); if (q) n.mk![id] = Math.min(c((H - q.top) / (H * .7)), 1 - c((H * .55 - q.bottom) / (H * .55))); });
      if (g) n.gx = c((H * .6 - g.bottom) / (H * .6));
      const fa = r('app'); if (fa) n.fp = c((H * .9 - fa.top) / (H * .75));
      const v = r('vision'); if (v) n.vp = c((H * .85 - v.top) / (v.height * .8));
      const e = r('end'); if (e) n.ep = c((H - e.top) / (e.height * .9));
      this.setState(n);
    });
  }


}
export function initLandingLab(root: HTMLElement): () => void {
  return new LabEngine(root).mount();
}
