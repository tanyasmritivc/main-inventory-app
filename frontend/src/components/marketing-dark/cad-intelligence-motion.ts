// Static illustrative assembly only. No inventory, purchase, or CAD API calls.
export const CAD_SAMPLE: readonly (readonly [string, string, number, number])[] = [
  ['5mm hex shaft, 96mm', 'Hardware wall, PN-F21', 4, 6],
  ['14T pinion gear', 'Gears bin, PN-F44', 2, 2],
  ['96mm mecanum wheel', 'Drive shelf', 4, 2],
  ['Pillow block bearing', 'Hardware wall, PN-F30', 8, 12],
  ['M4 × 8mm screw', 'Hardware wall, PN-F83', 64, 120],
  ['M4 nylock nut', 'Hardware wall, PN-F90', 64, 40],
  ['U-channel, 288mm', 'Structure rack', 2, 3],
  ['Servo, 25T spline', 'Not in inventory', 1, 0],
];

export function mountCadDemo(root: HTMLElement, styles: Record<string, string>) {
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const element = (id: string) => root.querySelector<HTMLElement>(`[data-cad="${id}"]`)!;
  const cv = root.querySelector<HTMLCanvasElement>('canvas')!;
  const win = element('win');
  const g = cv.getContext('2d');
  const rows = CAD_SAMPLE.map((_, i) => ({ row: element('r'+i), count: element('h'+i), chip: element('t'+i) }));
  const upload = element('prog'), bar = element('progress'), done = element('done');
  const scan = element('scan'), label = element('mlab');
  const ready = element('ready'), sums = element('sums'), mb = element('mb'), mu = element('mu');
  const ST = Array(8).fill(0);
  let CUR = -1, progress = 0, target = 0, frameId = 0, lastTime = 0;
  let alive = true, W = 0, H = 0, ratio = 1;
  const clamp = (n: number) => Math.max(0, Math.min(1, n));
  // Scroll controls every stage. Disable timed CSS transitions so they never lag behind it.
  [bar, scan, mb, mu, ...rows.flatMap(({row, chip}) => [row, chip])].forEach(el => { el.style.transition = 'none'; });
  function render() {
    const p = progress;
    const uploaded = p >= .16;
    upload.style.display = uploaded ? 'none' : '';
    done.style.display = uploaded ? 'block' : 'none';
    bar.style.width = `${clamp(p / .16) * 100}%`;
    CUR = -1;
    rows.forEach(({row, count, chip}, i) => {
      const [, , needed, stock] = CAD_SAMPLE[i];
      const start = .16 + i * .085;
      const local = clamp((p - start) / .085);
      const shown = clamp(local / .45);
      const resolved = clamp((local - .65) / .35);
      row.style.opacity = String(shown);
      row.style.transform = `translateY(${(1-shown)*6}px)`;
      row.className = `${styles.r}${resolved > 0 && stock < needed ? ' '+styles.flag : ''}`;
      count.textContent = String(Math.round(stock * (1-Math.pow(1-local,3))));
      chip.className = `${styles.st} ${styles[stock >= needed ? 'ok' : stock === 0 ? 'miss' : 'short']}`;
      chip.textContent = stock >= needed ? 'Ready' : stock === 0 ? 'Missing' : 'Short '+(needed-stock);
      chip.style.opacity = String(resolved);
      ST[i] = resolved > 0 ? (stock >= needed ? 1 : 2) : 0;
      if (local > 0 && local < 1) CUR = i;
    });
    const completed = p >= .9;
    scan.style.opacity = CUR >= 0 ? '1' : '0';
    if (CUR >= 0) scan.style.top = rows[CUR].row.offsetTop+'px';
    label.textContent = completed ? 'Shortages shown in amber' : CUR >= 0 ? 'Matching: '+CAD_SAMPLE[CUR][0] : 'Reading assembly';
    const summary = clamp((p-.9)/.1);
    mb.style.width = `${62.5*summary}%`;
    mu.style.width = `${37.5*summary}%`;
    ready.textContent = completed ? '5' : '0';
    sums.textContent = completed ? '3 short or missing' : uploaded ? 'Comparing' : p > 0 ? 'Uploading' : 'Waiting for upload';
    draw();
  }

  // Point generation and projection are ported unchanged from the supplied source.
const P: number[][]=[];const add=(x: number,y: number,z: number,c: number)=>P.push([x,y,z,c]);const R=Math.random;
for(const sx of [-1,1]){
 for(let i=0;i<170;i++){const u=R()*2-1,v=R()*2-1,e=R();if(e<.35)add(sx*.82,Math.sign(v)*.3,u*1.2,6);else if(e<.7)add(sx*.82,v*.3,Math.sign(u)*1.2,6);else add(sx*(.82+(R()<.5?0:.08)),(R()<.5?-1:1)*.3,u*1.2,6)}
 for(const wz of [-.82,.82]){
  for(let i=0;i<120;i++){const a=R()*6.283,r=.4;add(sx*(1.02+R()*.18),Math.sin(a)*r,wz+Math.cos(a)*r,2)}
  for(let k=0;k<8;k++){const a=k/8*6.283+.3;for(let j=1;j<7;j++){const r=j/7*.4;add(sx*1.11,Math.sin(a)*r,wz+Math.cos(a)*r,2)}}
  for(let i=0;i<26;i++)add(sx*(.6+R()*.62),(R()-.5)*.04,wz+(R()-.5)*.04,0);
  for(let i=0;i<34;i++){const a=R()*6.283;add(sx*.84,Math.sin(a)*.1,wz+Math.cos(a)*.1,3)}
  for(let i=0;i<40;i++){const a=R()*6.283,r=.16+R()*.03;add(sx*.66,Math.sin(a)*r,wz+Math.cos(a)*r,1)}}
 for(let i=0;i<46;i++)add(sx*.82,(R()<.5?-1:1)*(.22+R()*.04),(R()*2-1)*1.1,4);
 for(let i=0;i<40;i++)add(sx*.9,(R()<.5?-1:1)*(.22+R()*.04),(R()*2-1)*1.1,5);}
for(let i=0;i<90;i++)add((R()*2-1)*.82,(R()<.5?-1:1)*.06,(R()<.5?-1:1)*1.2,6);
for(let i=0;i<80;i++){const f=R()*3|0,x=(R()*2-1)*.22,y=(R()*2-1)*.12,z=(R()*2-1)*.16;add(f==0?Math.sign(x)*.22:x,f==1?Math.sign(y)*.12:y,f==2?Math.sign(z)*.16:z,7)}

  function draw() {
    if (!g || !W || !H) return;
    const t = motion.matches ? 1.1 : progress * 4;
    g.clearRect(0,0,W,H);
 const cx=W*.5,cy=H*.47,S=Math.min(W*.15,H*.29),ay=t*.35+.7,ax=-.42;const ca=Math.cos(ay),sa=Math.sin(ay),cb=Math.cos(ax),sb=Math.sin(ax);
 const pul=.5+.5*Math.sin(t*8);
 for(const p of P){let x=p[0]*ca+p[2]*sa,z=-p[0]*sa+p[2]*ca,y=p[1]*cb-z*sb;z=p[1]*sb+z*cb;const f=3/(3+z),px=cx+x*S*f,py=cy+y*S*f,dep=(1-z)/2;
  const st=ST[p[3]],cur=CUR===p[3];let c;
  if(cur)c=`rgba(255,255,255,${.55+.45*pul})`;else if(st===1)c=`rgba(245,245,246,${.45+.45*dep})`;else if(st===2)c=`rgba(227,180,92,${.55+.45*dep})`;else c=`rgba(245,245,246,${.08+.16*dep})`;
  g.fillStyle=c;const s=(cur?1.5:1)*(1+1.1*dep);g.fillRect(px-s/2,py-s/2,s,s)}

  }
  function stop() { cancelAnimationFrame(frameId); frameId = 0; lastTime = 0; }
  function frame(now: number) {
    frameId = 0;
    if (!alive || document.hidden) return;
    const elapsed = lastTime ? Math.min(64, now-lastTime) : 16;
    lastTime = now;
    progress += (target-progress) * (1-Math.exp(-elapsed/65));
    if (Math.abs(target-progress) < .0005) progress = target;
    render();
    if (progress !== target) frameId = requestAnimationFrame(frame);
    else lastTime = 0;
  }
  function update() {
    if (!alive || document.hidden) return;
    const rect = win.getBoundingClientRect();
    const viewport = window.innerHeight;
    // A short natural scroll completes the demo; no pinning or extra page height.
    const distance = Math.min(420, Math.max(220, viewport*.48));
    target = motion.matches ? 1 : clamp((viewport*.8-rect.top)/distance);
    if (motion.matches || rect.bottom <= 0 || rect.top >= viewport) {
      stop(); progress = target; render();
    } else if (!frameId && progress !== target) frameId = requestAnimationFrame(frame);
  }
  function size() {
    const r = cv.getBoundingClientRect(), d = Math.min(2,devicePixelRatio||1);
    if (W !== r.width || H !== r.height || ratio !== d) {
      W = r.width; H = r.height; ratio = d;
      cv.width = W*d; cv.height = H*d; g?.setTransform(d,0,0,d,0,0);
      render();
    }
    update();
  }
  function visibilityChanged() { if (document.hidden) stop(); else update(); }
  const resizeObserver = new ResizeObserver(size);
  resizeObserver.observe(cv);
  window.addEventListener('scroll',update,{passive:true});
  window.addEventListener('resize',size);
  document.addEventListener('visibilitychange',visibilityChanged);
  motion.addEventListener('change',update);
  size(); render();
  return () => {
    alive = false; stop(); resizeObserver.disconnect();
    window.removeEventListener('scroll',update);
    window.removeEventListener('resize',size);
    document.removeEventListener('visibilitychange',visibilityChanged);
    motion.removeEventListener('change',update);
    cv.width = cv.height = 0;
  };
}
