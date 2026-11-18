"use client";

import {useEffect, useRef} from "react";

// Sample illustration from the supplied hero-art.js. Geometry and drawing timeline
// are unchanged; React owns visibility, resizing and disposal.
export function CadHeroArt() {
  const canvasRef = useRef(null);
  useEffect(() => {
    const cv = canvasRef.current;
    if (!cv) return;
    const g = cv.getContext('2d');
    if (!g) return;
    const media = matchMedia('(prefers-reduced-motion: reduce)');
    let RM = media.matches;
    const css = getComputedStyle(document.documentElement);
    const F = {
      sans: css.getPropertyValue('--font-app-inter').trim() || 'sans-serif',
      mono: css.getPropertyValue('--font-geist-mono').trim() || 'monospace',
    };
const cl=(v,a=0,b=1)=>Math.min(b,Math.max(a,v)),ss=(a,b,x)=>{const t=cl((x-a)/(b-a));return t*t*(3-2*t)},eo=t=>1-Math.pow(1-cl(t),3);
// geometry: list of [part, a, b] line segments in model space
const SEG=[];const seg=(k,a,b)=>SEG.push([k,a,b]);
const box=(k,x0,x1,y0,y1,z0,z1)=>{const P=[[x0,y0,z0],[x1,y0,z0],[x1,y1,z0],[x0,y1,z0],[x0,y0,z1],[x1,y0,z1],[x1,y1,z1],[x0,y1,z1]];[[0,1],[1,2],[2,3],[3,0],[4,5],[5,6],[6,7],[7,4],[0,4],[1,5],[2,6],[3,7]].forEach(([i,j])=>seg(k,P[i],P[j]))};
const ring=(k,cx,cy,cz,r,n=28)=>{for(let i=0;i<n;i++){const a=i/n*6.283,b=(i+1)/n*6.283;seg(k,[cx,cy+Math.sin(a)*r,cz+Math.cos(a)*r],[cx,cy+Math.sin(b)*r,cz+Math.cos(b)*r])}};
// side U-channels (part 2) and cross channels (part 2)
for(const sx of [-1,1]){box('ch',sx*.86,sx*.78,-.26,.26,-1.15,1.15);seg('ch',[sx*.82,-.26,-1.15],[sx*.82,-.26,1.15])}
for(const sz of [-1,1])box('ch',-.78,.78,-.08,.08,sz*1.1,sz*1.02);
// wheels (part 0): two rims plus rollers
for(const sx of [-1,1])for(const sz of [-1,1]){const cx=sx*1.2;ring('wh',cx-.09,0,sz*.82,.38);ring('wh',cx+.09,0,sz*.82,.38);
 for(let i=0;i<8;i++){const a=i/8*6.283,b=a+.55;seg('wh',[cx-.09,Math.sin(a)*.38,sz*.82+Math.cos(a)*.38],[cx+.09,Math.sin(b)*.38,sz*.82+Math.cos(b)*.38])}
 ring('wh',cx-.09,0,sz*.82,.1,12);
 // hex shafts (part 1)
 seg('sh',[sx*.6,0,sz*.82],[sx*1.32,0,sz*.82]);seg('sh',[sx*.6,.025,sz*.82],[sx*1.32,.025,sz*.82])}
// servo (part 3) in the middle
box('sv',-.2,.2,-.12,.12,-.16,.16);box('sv',-.06,.06,-.2,-.12,-.05,.05);
const PARTS=[{k:'wh',n:'96mm mecanum wheel',q:'× 4',st:'Short 2',c:'sh',side:-1,row:0},{k:'sh',n:'5mm hex shaft',q:'× 4',st:'Covered',c:'ok',side:1,row:0},
 {k:'ch',n:'U-channel, 288mm',q:'× 2',st:'Needs review',c:'rv',side:-1,row:1},{k:'sv',n:'Servo, 25T spline',q:'× 1',st:'Missing',c:'ms',side:1,row:1}];
const AMB='227,180,92';let W=0,H=0,dpr=1;
function size(){const r=cv.getBoundingClientRect();dpr=Math.min(2,devicePixelRatio||1);W=r.width;H=r.height;cv.width=Math.round(W*dpr);cv.height=Math.round(H*dpr);g.setTransform(dpr,0,0,dpr,0,0)}
function rr(x,y,w,h,r){g.beginPath();g.roundRect(x,y,w,h,r)}
const T=10;
function draw(t){g.clearRect(0,0,W,H);const u=RM?7.6:t%T,sc=W/580;
 const fade=RM?1:ss(0,.5,u)*(1-ss(9.4,10,u));
 const ang=RM?.62:.62+Math.sin(t*.35)*.32,ca=Math.cos(ang),sa=Math.sin(ang),tl=-.42,cb=Math.cos(tl),sb=Math.sin(tl);
 const cx=W/2,cy=H*.47,S=W*.2;
 const pj=([x,y,z])=>{let X=x*ca+z*sa,Z=-x*sa+z*ca,Y=y*cb-Z*sb;Z=y*sb+Z*cb;const f=4.5/(4.5+Z);return [cx+X*S*f,cy+Y*S*f,Z]};
 // draw-on progress for the wireframe
 const build=RM?1:eo(ss(0,1.4,u));const nShow=Math.floor(SEG.length*build);
 const act={};PARTS.forEach((p,i)=>{const a=RM?1:ss(1.6+i*.75,2.0+i*.75,u);act[p.k]={a,st:RM?1:ss(4.9+i*.35,5.2+i*.35,u),p}});
 const cen={};
 for(let i=0;i<nShow;i++){const [k,a,b]=SEG[i];const A=pj(a),B=pj(b);const d=cl(.5-(A[2]+B[2])/4);const ac=act[k];const on=ac?ac.a:0,stv=ac?ac.st:0;
  const warm=ac&&(ac.p.c==='sh'||ac.p.c==='ms')&&stv>0;
  const base=.12+.38*d;g.strokeStyle=warm?`rgba(${AMB},${(base+.35*on)*fade})`:`rgba(245,245,246,${(base+.4*on)*fade})`;g.lineWidth=on>.5?1.3:1;
  g.beginPath();g.moveTo(A[0],A[1]);g.lineTo(B[0],B[1]);g.stroke();
  (cen[k]=cen[k]||[0,0,0,-9]);cen[k][0]+=A[0];cen[k][1]+=A[1];cen[k][2]++;}
 // labels
 const cw=Math.min(232,W*.42),chh=58*Math.max(.8,sc);
 PARTS.forEach(p=>{const a=act[p.k].a*fade;if(a<=0||!cen[p.k])return;const st=act[p.k].st;
  const lx=p.side<0?0:W-cw,ly=p.row===0?H*.04:H*.66,ex=p.side<0?lx+cw:lx;
  // anchor: the projected point of that part nearest the label
  let best=null,bd=1e9;for(const [k,A] of SEG){if(k!==p.k)continue;const P=pj(A);const d=Math.hypot(P[0]-ex,P[1]-(ly+chh/2));if(d<bd){bd=d;best=P}}
  const lp=eo(ss(0,.6,a));g.strokeStyle=`rgba(245,245,246,${.45*a})`;g.lineWidth=1;g.setLineDash([3,4]);g.beginPath();g.moveTo(ex,ly+chh/2);g.lineTo(ex+(best[0]-ex)*lp,ly+chh/2+(best[1]-ly-chh/2)*lp);g.stroke();g.setLineDash([]);
  g.fillStyle=`rgba(245,245,246,${a})`;g.beginPath();g.arc(best[0],best[1],2.4,0,7);g.fill();
  g.globalAlpha=a;rr(lx,ly,cw,chh,12);g.fillStyle='#0B0B0C';g.fill();g.strokeStyle='#2C2C2E';g.lineWidth=1;g.stroke();
  const fs=Math.max(11.5,13*Math.min(1,sc));g.font=`400 ${fs}px ${F.sans}`;g.fillStyle='#F5F5F6';g.fillText(p.n,lx+14,ly+chh*.4);
  g.font=`500 ${fs-1}px ${F.mono}`;g.fillStyle='#8E8E93';g.fillText(p.q,lx+14,ly+chh*.8);
  if(st>0){g.globalAlpha=a*st;g.font=`500 ${fs-1.5}px ${F.sans}`;const tw=g.measureText(p.st).width+18,th=fs+9,tx=lx+cw-tw-12,ty=ly+chh*.73-th/2;rr(tx,ty,tw,th,th/2);
   if(p.c==='ok'){g.fillStyle='#F5F5F6';g.fill();g.fillStyle='#0B0B0C'}else if(p.c==='sh'){g.fillStyle='#E3B45C';g.fill();g.fillStyle='#1A1305'}else{g.lineWidth=1.2;g.setLineDash(p.c==='ms'?[3,3]:[]);g.strokeStyle=p.c==='ms'?'rgba(227,180,92,.8)':'#5A5A5F';g.stroke();g.setLineDash([]);g.fillStyle=p.c==='ms'?'#E3B45C':'#A1A1A6'}
   g.fillText(p.st,tx+9,ty+th*.68)}
  g.globalAlpha=1});
 // summary
 const sa2=(RM?1:ss(6.6,7.1,u))*fade;if(sa2>0){const y=H*.93;g.globalAlpha=sa2;g.font=`500 ${Math.max(11.5,12.5*Math.min(1,sc))}px ${F.mono}`;g.fillStyle='#A1A1A6';g.textAlign='center';g.fillText('4 COVERED · 2 SHORT · 1 MISSING · 1 NEEDS REVIEW',W/2,y);g.textAlign='left';
  const bw=Math.min(W*.8,420),bx=W/2-bw/2;let x=bx;[[4,'#F5F5F6'],[2,'#E3B45C'],[1,'rgba(227,180,92,.45)'],[1,'#5A5A5F']].forEach(([n,c])=>{const w=bw*n/8*eo(ss(6.7,7.4,u)+(RM?1:0));g.fillStyle=c;g.fillRect(x,y+14,Math.max(0,w-3),3);x+=bw*n/8});g.globalAlpha=1}
}

    let alive = true, visible = false, raf = 0, elapsed = 0, last = null;
    const active = () => alive && visible && !document.hidden && !RM;
    function pause() {
      if (last !== null) elapsed += Math.max(0, performance.now() - last) / 1000;
      last = null;
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    }
    function loop(now) {
      raf = 0;
      if (!active()) { last = null; return; }
      if (last !== null) elapsed += Math.max(0, now - last) / 1000;
      last = now;
      draw(elapsed);
      raf = requestAnimationFrame(loop);
    }
    function sync() {
      if (!active()) {
        pause();
        if (alive && visible && !document.hidden && RM) draw(0);
      } else if (!raf) {
        last = performance.now();
        raf = requestAnimationFrame(loop);
      }
    }
    function resize() {
      if (!alive) return;
      size();
      if (visible && !document.hidden) draw(RM ? 0 : elapsed);
    }
    function motionChange() { RM = media.matches; sync(); }
    size();
    const resizeObserver = new ResizeObserver(resize);
    resizeObserver.observe(cv);
    const observer = new IntersectionObserver(entries => {
      visible = entries[0].isIntersecting;
      sync();
    }, {threshold: 0});
    observer.observe(cv);
    document.addEventListener('visibilitychange', sync);
    media.addEventListener('change', motionChange);
    document.fonts?.ready.then(() => { if (alive) resize(); });
    return () => {
      alive = false;
      pause();
      observer.disconnect();
      resizeObserver.disconnect();
      document.removeEventListener('visibilitychange', sync);
      media.removeEventListener('change', motionChange);
    };
  }, []);
  return <div className="hart" aria-hidden="true"><canvas id="hvc" ref={canvasRef} aria-hidden="true" /></div>;
}
