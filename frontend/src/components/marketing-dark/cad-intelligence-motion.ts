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
  const g = cv.getContext('2d');
  const D = CAD_SAMPLE;
  const timers = new Set<ReturnType<typeof setTimeout>>();
  const counters = new Set<number>();
  let alive = true, started = false, windowVisible = false, canvasVisible = false;
  let replayPending = false, frameId = 0, W = 0, H = 0, ratio = 1;
  const ST = Array(8).fill(0);
  let CUR = -1;
  const t0 = performance.now();

  const at = (ms: number, fn: () => void) => {
    const id = setTimeout(() => { timers.delete(id); if (alive) fn(); }, ms);
    timers.add(id);
  };
  function clearSequence() {
    timers.forEach(clearTimeout); timers.clear();
    counters.forEach(cancelAnimationFrame); counters.clear();
  }
  function count(i: number, ms: number) {
    const el = element('h'+i), to = D[i][3], start = performance.now();
    function tick(now: number) {
      const k = Math.min(1,(now-start)/ms);
      el.textContent = String(Math.round(to*(1-Math.pow(1-k,3))));
      if (k < 1) {
        const id = requestAnimationFrame(time => { counters.delete(id); if (alive) tick(time); });
        counters.add(id);
      }
    }
    tick(start);
  }
  function reset() {
    clearSequence(); ST.fill(0); CUR = -1;
    element('mlab').textContent = 'Reading assembly';
    D.forEach((_,i) => {
      element('r'+i).className = styles.r;
      element('h'+i).textContent = '0';
      element('t'+i).className = styles.st;
      element('t'+i).textContent = '';
    });
    element('prog').style.display = '';
    element('progress').style.transition = 'none'; element('progress').style.width = '0';
    element('done').style.display = 'none';
    element('mb').style.width = element('mu').style.width = '0';
    element('ready').textContent = '0';
    element('sums').textContent = 'Waiting for upload';
    element('scan').style.opacity = '0';
  }
  function status(i: number) {
    const [, ,n,h] = D[i], chip = element('t'+i);
    ST[i] = h >= n ? 1 : 2;
    chip.className = `${styles.st} ${styles[h >= n ? 'ok' : h === 0 ? 'miss' : 'short']} ${styles.on}`;
    chip.textContent = h >= n ? 'Ready' : h === 0 ? 'Missing' : 'Short '+(n-h);
    if (h < n) element('r'+i).classList.add(styles.flag);
  }
  function summary() {
    const ok = D.filter(d => d[3] >= d[2]).length, short = D.length-ok;
    element('mb').style.width = (ok/D.length*100)+'%';
    element('mu').style.width = (short/D.length*100)+'%';
    element('ready').textContent = String(ok);
    element('sums').textContent = `${short} short or missing`;
  }
  function finished() {
    clearSequence(); CUR = -1;
    D.forEach((d,i) => { element('r'+i).classList.add(styles.on); element('h'+i).textContent = String(d[3]); status(i); });
    element('prog').style.display = 'none'; element('done').style.display = 'block';
    element('scan').style.opacity = '0';
    summary(); element('mlab').textContent = 'Shortages shown in amber';
    draw(performance.now());
  }
  function play() {
    if (motion.matches) { finished(); return; }
    if (!windowVisible || document.hidden) { replayPending = true; return; }
    replayPending = false;
    reset(); element('sums').textContent = 'Uploading';
    at(60, () => { element('progress').style.transition = 'width 1.5s cubic-bezier(.32,.72,0,1)'; element('progress').style.width = '100%'; });
    at(1650, () => { element('prog').style.display = 'none'; element('done').style.display = 'block'; element('sums').textContent = 'Comparing'; });
    D.forEach((d,i) => {
      const time = 1900+i*340;
      at(time, () => {
        const row = element('r'+i), scan = element('scan');
        row.classList.add(styles.on); scan.style.opacity = '1'; scan.style.top = row.offsetTop+'px';
        count(i,420); CUR = i; element('mlab').textContent = 'Matching: '+d[0];
      });
      at(time+430, () => status(i));
    });
    const end = 1900+D.length*340+500;
    at(end, () => { element('scan').style.opacity = '0'; CUR = -1; element('mlab').textContent = 'Shortages shown in amber'; summary(); });
    at(end+6500,play);
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

  function draw(now: number) {
    if (!g || !W || !H) return;
    const t = motion.matches ? 1.1 : (now-t0)/1000;
    g.clearRect(0,0,W,H);
 const cx=W*.5,cy=H*.47,S=Math.min(W*.15,H*.29),ay=t*.35+.7,ax=-.42;const ca=Math.cos(ay),sa=Math.sin(ay),cb=Math.cos(ax),sb=Math.sin(ax);
 const pul=.5+.5*Math.sin(t*8);
 for(const p of P){let x=p[0]*ca+p[2]*sa,z=-p[0]*sa+p[2]*ca,y=p[1]*cb-z*sb;z=p[1]*sb+z*cb;const f=3/(3+z),px=cx+x*S*f,py=cy+y*S*f,dep=(1-z)/2;
  const st=ST[p[3]],cur=CUR===p[3];let c;
  if(cur)c=`rgba(255,255,255,${.55+.45*pul})`;else if(st===1)c=`rgba(245,245,246,${.45+.45*dep})`;else if(st===2)c=`rgba(227,180,92,${.55+.45*dep})`;else c=`rgba(245,245,246,${.08+.16*dep})`;
  g.fillStyle=c;const s=(cur?1.5:1)*(1+1.1*dep);g.fillRect(px-s/2,py-s/2,s,s)}

  }
  function stopCanvas() { cancelAnimationFrame(frameId); frameId = 0; }
  function frame(now: number) {
    frameId = 0;
    if (!alive || motion.matches || document.hidden || !canvasVisible) return;
    draw(now); frameId = requestAnimationFrame(frame);
  }
  function refreshCanvas() {
    stopCanvas();
    if (document.hidden || !canvasVisible) return;
    draw(performance.now());
    if (!motion.matches) frameId = requestAnimationFrame(frame);
  }
  function size() {
    const r = cv.getBoundingClientRect(), d = Math.min(2,devicePixelRatio||1);
    if (W === r.width && H === r.height && ratio === d) return;
    W = r.width; H = r.height; ratio = d;
    cv.width = W*d; cv.height = H*d; g?.setTransform(d,0,0,d,0,0);
    draw(performance.now());
  }
  function motionChanged() {
    if (motion.matches) finished(); else if (started || windowVisible) { started = true; play(); }
    refreshCanvas();
  }
  function visibilityChanged() {
    refreshCanvas();
    if (document.hidden && started && !motion.matches) { clearSequence(); replayPending = true; }
    else if (replayPending) play();
  }
  const trigger = new IntersectionObserver(entries => {
    windowVisible = entries[0].isIntersecting && entries[0].intersectionRatio >= .35;
    if (windowVisible && !motion.matches && (!started || replayPending)) { started = true; play(); }
  }, { threshold: [0,.35] });
  const canvasObserver = new IntersectionObserver(entries => { canvasVisible = entries[0].isIntersecting; refreshCanvas(); });
  const resizeObserver = new ResizeObserver(size);
  trigger.observe(element('win')); canvasObserver.observe(cv); resizeObserver.observe(cv);
  window.addEventListener('resize',size);
  document.addEventListener('visibilitychange',visibilityChanged);
  motion.addEventListener('change',motionChanged);
  size();
  if (motion.matches) finished();
  return () => {
    alive = false; clearSequence(); stopCanvas();
    trigger.disconnect(); canvasObserver.disconnect(); resizeObserver.disconnect();
    window.removeEventListener('resize',size);
    document.removeEventListener('visibilitychange',visibilityChanged);
    motion.removeEventListener('change',motionChanged);
    cv.width = cv.height = 0;
  };
}
