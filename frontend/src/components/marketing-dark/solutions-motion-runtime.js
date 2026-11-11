import {homeLife} from './home-life';
const $=id=>document.getElementById(id),cl=(v,a=0,b=1)=>Math.min(b,Math.max(a,v)),L=(a,b,t)=>a+(b-a)*t,ss=(a,b,x)=>{const t=cl((x-a)/(b-a));return t*t*(3-2*t)},eo=t=>1-Math.pow(1-t,3);
const fonts=()=>{const css=getComputedStyle(document.documentElement);return {sans:css.getPropertyValue('--font-app-inter')||'sans-serif',mono:css.getPropertyValue('--font-geist-mono')||'monospace'}};
export function mountInventoryMap(){const life=homeLife(),RM=matchMedia("(prefers-reduced-motion: reduce)").matches,F=fonts();
const AUD=[{"tab": "Robotics teams", "href": "/solutions/robotics", "short": "robotics", "q": "Where are the 24 tooth HTD pulleys?", "names": ["Robotics Lab", "Parts wall", "Bin PN-F260", "5mm HTD pulley ×18"], "path": [0, 1, 4, 9], "a": "<b>18</b>, in bin <b>PN-F260</b> on the Parts wall."}, {"tab": "Workshops", "href": "/solutions/workshops", "short": "workshop", "q": "Where are the ER32 collets?", "names": ["Shop floor", "CNC 1 tool cart", "Drawer 2", "ER32 collets ×14"], "path": [1, 4, 13, 27], "a": "<b>14</b>, on the <b>CNC 1 tool cart</b>, drawer 2."}, {"tab": "Makerspaces", "href": "/solutions/makerspaces", "short": "makerspace", "q": "How many multimeters are there?", "names": ["Makerspace", "Electronics wall", "Bin E4", "Multimeters ×6"], "path": [2, 7, 22, 44], "a": "<b>6</b>, on the <b>Electronics wall</b>."}, {"tab": "Engineering labs", "href": "/solutions/engineering-labs", "short": "lab", "q": "Where are the strain gauges?", "names": ["Lab B", "Cabinet B", "Drawer 3", "Strain gauges"], "path": [2, 8, 25, 51], "a": "<b>Cabinet B</b>, drawer 3."}];
const gc=$('s-graph'),g2=gc.getContext('2d');let GW=0,GH=0,ai=0,qt=0,phase=0,ptime=0,insVis=false,tmo=[];
function gsize(){const d=Math.min(2,devicePixelRatio||1);GW=gc.clientWidth;GH=gc.clientHeight;gc.width=GW*d;gc.height=GH*d;g2.setTransform(d,0,0,d,0,0)}life.on(window,'resize',()=>{gsize();if(RM)life.raf(drawGraph)});gsize();
const LV=[3,9,27,54];
function nodes(){const xs=GW<700?[.1,.37,.64,.9]:[.08,.36,.64,.9],pad=36;return LV.map((n,l)=>Array.from({length:n},(_,i)=>({x:GW*xs[l],y:pad+(GH-pad*2)*(n===1?.5:i/(n-1))})))}
function pathIdx(a){return a.path}
let anim=0;const t0=performance.now();
function drawGraph(now){if((!insVis||document.hidden)&&!RM)return;const t=(now-t0)/1000,N=nodes(),A=AUD[ai],P=A.path,k=RM?1:cl((now-ptime)/1400);g2.clearRect(0,0,GW,GH);
 g2.font=`500 10.5px ${F.mono},monospace`;g2.fillStyle='rgba(255,255,255,.28)';['SPACE','STORAGE','BIN','ITEM'].forEach((h,l)=>{g2.fillText(h,N[l][0].x-(l===3?40:0),18)});
 for(let l=0;l<3;l++)N[l+1].forEach((c,i)=>{const p=N[l][Math.floor(i/(LV[l+1]/LV[l]))];const on=phase>=1&&P[l]===Math.floor(i/(LV[l+1]/LV[l]))&&P[l+1]===i;
  g2.strokeStyle=on?'rgba(255,255,255,0)':'rgba(255,255,255,.07)';g2.lineWidth=1;g2.beginPath();g2.moveTo(p.x,p.y);const mx=(p.x+c.x)/2;g2.bezierCurveTo(mx,p.y,mx,c.y,c.x,c.y);g2.stroke()});
 N.forEach((lv,l)=>lv.forEach((n,i)=>{const tw=.5+.5*Math.sin(t*1.3+i*1.7+l);g2.fillStyle=`rgba(255,255,255,${.18+.12*tw})`;const s=l===3?2:3;g2.fillRect(n.x-s/2,n.y-s/2,s,s)}));
 if(phase>=1){const seg=k*3;g2.strokeStyle='#fff';g2.lineWidth=1.6;
  for(let l=0;l<3;l++){const a=N[l][P[l]],b=N[l+1][P[l+1]],f=cl(seg-l);if(f<=0)break;g2.beginPath();const mx=(a.x+b.x)/2;const steps=24;for(let s=0;s<=steps*f;s++){const u=s/steps,x=(1-u)**3*a.x+3*(1-u)**2*u*mx+3*(1-u)*u*u*mx+u**3*b.x,y=(1-u)**3*a.y+3*(1-u)**2*u*a.y+3*(1-u)*u*u*b.y+u**3*b.y;s?g2.lineTo(x,y):g2.moveTo(x,y)}g2.stroke()}
  for(let l=0;l<4;l++){if(seg<l-.05)break;const n=N[l][P[l]];const pulse=l===3&&k>=1?.5+.5*Math.sin(t*4):0;g2.fillStyle='#fff';g2.beginPath();g2.arc(n.x,n.y,l===3?5+pulse*2:4,0,7);g2.fill();
   if(l===3){g2.strokeStyle=`rgba(255,255,255,${.35-pulse*.25})`;g2.beginPath();g2.arc(n.x,n.y,12+pulse*6,0,7);g2.stroke()}
   if(GW<700&&l<3)continue;const lab=A.names[l];g2.font=`500 12px ${F.sans},sans-serif`;const w=g2.measureText(lab).width+16;let lx=l===3?n.x-w+8:n.x+10,ly=l===3?n.y+12:n.y-28;if(ly<26)ly=n.y+10;if(ly+22>GH-4)ly=n.y-30;g2.fillStyle='rgba(20,20,22,.92)';g2.fillRect(lx,ly,w,22);g2.strokeStyle='rgba(255,255,255,.18)';g2.lineWidth=1;g2.strokeRect(lx+.5,ly+.5,w-1,21);g2.fillStyle='#F5F5F6';g2.fillText(lab,lx+8,ly+15)}}
 if(!RM)life.raf(drawGraph)}
const tabs=[...document.querySelectorAll('.s-tab')],qEl=$('s-q'),aEl=$('s-a'),pn=[...document.querySelectorAll('.s-pn')];
function clr(){tmo.forEach(j=>life.clear(j.id));tmo=[]}
const active=()=>insVis&&!document.hidden;
function schedule(j){j.start=performance.now();j.id=life.timeout(()=>{tmo=tmo.filter(x=>x!==j);j.f()},j.remaining)}
const at=(ms,f)=>{const j={remaining:ms,f,id:0,start:0};tmo.push(j);if(active())schedule(j)};
let pausedAt=0,started=false;
function pause(){if(pausedAt)return;pausedAt=performance.now();tmo.forEach(j=>{life.clear(j.id);j.remaining=Math.max(0,j.remaining-(pausedAt-j.start))})}
function resume(){if(pausedAt){ptime+=performance.now()-pausedAt;pausedAt=0;tmo.forEach(schedule)}if(!started){started=true;play(0,true)}life.raf(drawGraph)}

function play(i,auto){clr();ai=i;phase=0;const A=AUD[i];tabs.forEach((b,k)=>{b.classList.toggle('on',k===i);b.setAttribute('aria-selected',String(k===i))});aEl.classList.remove('on');pn.forEach((p,k)=>{p.classList.remove('on');$('p'+k).textContent=A.names[k]});$('s-stat').textContent='inventory map · '+A.short;const mo=$('s-more');mo.href=A.href;mo.firstChild.textContent=A.tab;
 if(RM){qEl.textContent=A.q;phase=1;ptime=0;pn.forEach(p=>p.classList.add('on'));aEl.innerHTML=A.a;aEl.classList.add('on');life.raf(drawGraph);return}
 let n=0;(function ty(){n++;qEl.innerHTML=A.q.slice(0,n)+'<i></i>';if(n<A.q.length)at(38,ty);else{qEl.textContent=A.q;at(250,()=>{phase=1;ptime=performance.now();pn.forEach((p,k)=>at(k*450,()=>p.classList.add('on')));at(1700,()=>{aEl.innerHTML=A.a;aEl.classList.add('on')});if(auto)at(6200,()=>play((i+1)%AUD.length,true))})}})()}
tabs.forEach((b,k)=>life.on(b,'click',()=>play(k,true)));

life.observer(es=>{const visible=es[0].isIntersecting&&es[0].intersectionRatio>=.2;if(visible===insVis)return;insVis=visible;if(active())resume();else pause()},{threshold:[0,.2]}).observe($('s-ins'));
life.on(document,'visibilitychange',()=>{if(active())resume();else pause()});
if(RM){started=true;play(0,false)}
life.dispose(()=>{clr();gc.width=gc.height=0});
return ()=>life.close();}
export function mountAudience(){const life=homeLife(),RM=matchMedia('(prefers-reduced-motion: reduce)').matches;
const qio=life.observer(es=>es.forEach(e=>{if(!e.isIntersecting||e.intersectionRatio<.6)return;qio.unobserve(e.target);const u=e.target.querySelector('.u'),txt=u.dataset.q;let n=0;(function ty(){n++;u.textContent=txt.slice(0,n);if(n<txt.length)life.timeout(ty,32);else life.timeout(()=>e.target.classList.add('done'),280)})()}),{threshold:.6});
document.querySelectorAll('.solutions-page .s-qa').forEach(q=>{if(RM){q.querySelector('.u').textContent=q.querySelector('.u').dataset.q;q.classList.add('done')}else qio.observe(q)});
return ()=>life.close();}
export function mountInventoryMorph(){const life=homeLife(),RM=matchMedia("(prefers-reduced-motion: reduce)").matches,F=fonts();const ROWS=[["5mm HTD pulley, 24 tooth", 18, "PN-F260"], ["M3x16 screw", 140, "PN-F84"], ["Gear 30T M0.8", 6, "PN-F66"], ["Extension springs", 22, "Box 3"], ["GT2 pinion pulley, 20T", 6, "Pulley box"], ["M4 nylock nut", 60, "PN-F90"], ["Servo hub", 1, "Tote E"], ["Hex shaft 5mm, 96mm", 8, "PN-F21"], ["Bearing, 8mm bore", 24, "PN-F30"], ["Zip ties", 200, "Bench 1"], ["Super glue", 4, "Bench 1"], ["Mecanum wheel", 4, "Drive shelf"]];
const smS=$('sm'),sc=$('smc'),sg=sc.getContext('2d'),sr=[...document.querySelectorAll('.sm-r')];let SW=0,SH=0;
function ssize(){const d=Math.min(1.5,devicePixelRatio||1);SW=sc.clientWidth;SH=sc.clientHeight;sc.width=SW*d;sc.height=SH*d;sg.setTransform(d,0,0,d,0,0)}life.on(window,'resize',ssize);ssize();
function rr(c,x,y,w,h,r){c.beginPath();c.moveTo(x+r,y);c.arcTo(x+w,y,x+w,y+h,r);c.arcTo(x+w,y+h,x,y+h,r);c.arcTo(x,y+h,x,y,r);c.arcTo(x,y,x+w,y,r);c.closePath()}
function fitText(c,s,w){if(c.measureText(s).width<=w)return s;while(s.length>1&&c.measureText(s+'…').width>w)s=s.slice(0,-1);return s+'…'}
function drawSm(p){sg.clearRect(0,0,SW,SH);const mob=SW<700;
 const aw=mob?SW-32:Math.min(700,SW-Math.max(40,(SW-1160)/2)*2-420),ax=mob?16:SW-aw-Math.max(40,(SW-1160)/2),ah=mob?SH*.56:Math.min(SH*.74,560),ay=mob?SH-ah-24:(SH-ah)/2+20;
 const m=ss(.24,.56,p),q=ss(.62,.9,p),tA=1-ss(.28,.38,p),tB=ss(.48,.58,p);
 const n=ROWS.length,rh=Math.min(30,(ah-70)/n),tx=ax,ty=ay+44;
 const cols=mob?3:4,rows=Math.ceil(n/cols),gap=10,top=mob?132:80,dw=(aw-gap*(cols-1))/cols,dh=(ah-top-10-gap*(rows-1))/rows,gy=ay+top;
 // header
 sg.globalAlpha=tA;sg.font=`500 11.5px ${F.mono},monospace`;sg.fillStyle='#A1A1A6';sg.fillText('inventory.xlsx · 298 rows',tx,ay+14);
 sg.fillStyle='#6E6E73';sg.fillText('PART',tx+12,ay+36);sg.fillText('QTY',tx+aw*.62,ay+36);sg.fillText('BIN',tx+aw*.76,ay+36);sg.globalAlpha=1;
 const hit=0;
 ROWS.forEach((r,i)=>{const c=i%cols,ro=Math.floor(i/cols),k=eo(cl((m-(i/n)*.35)/.65));
  const x=L(tx,ax+c*(dw+gap),k),y=L(ty+i*rh,gy+ro*(dh+gap),k),w=L(aw,dw,k),h=L(rh-2,dh,k),rad=L(3,10,k);
  const isHit=i===hit,dim=q>0&&!isHit?1-.6*q:1,lit=isHit?q:0;
  sg.globalAlpha=dim;rr(sg,x,y,w,h,rad);sg.fillStyle=lit>0?`rgba(${L(20,242,lit)|0},${L(20,242,lit)|0},${L(22,243,lit)|0},1)`:(i%2&&k<.5?'#121214':'#141416');sg.fill();sg.strokeStyle=`rgba(255,255,255,${L(.04,.12,k)})`;sg.lineWidth=1;sg.stroke();
  if(tA>0){sg.globalAlpha=dim*tA;sg.font=`400 13px ${F.sans},sans-serif`;sg.fillStyle='#E5E5E8';sg.fillText(fitText(sg,r[0],aw*.56),x+12,y+rh/2+3);sg.font=`500 12px ${F.mono},monospace`;sg.fillStyle='#A1A1A6';sg.fillText(String(r[1]),x+aw*.62,y+rh/2+3);sg.fillText(r[2],x+aw*.76,y+rh/2+3)}
  if(tB>0){sg.globalAlpha=dim*tB;const ink=lit>.5?'#0B0B0C':'#F5F5F6',sub=lit>.5?'rgba(11,11,12,.6)':'#6E6E73';
   sg.fillStyle=lit>.5?'rgba(11,11,12,.25)':'rgba(255,255,255,.14)';sg.fillRect(x+12,y+12,w*.36,3);
   sg.font=`500 10.5px ${F.mono},monospace`;sg.fillStyle=sub;sg.fillText(r[2].toUpperCase(),x+12,y+32);
   sg.font=`400 12.5px ${F.sans},sans-serif`;sg.fillStyle=ink;sg.fillText(fitText(sg,r[0],w-24),x+12,y+h-28);
   sg.font=`500 12px ${F.mono},monospace`;sg.fillStyle=sub;sg.fillText('× '+r[1],x+12,y+h-11)}
  sg.globalAlpha=1});
 // query
 if(q>0){const qs='Where are the 24 tooth HTD pulleys?',nc=Math.round(qs.length*cl(q/.45));sg.globalAlpha=cl(q*4);rr(sg,ax,ay+18,aw,44,22);sg.fillStyle='#111113';sg.fill();sg.strokeStyle='rgba(255,255,255,.14)';sg.stroke();
  sg.font=`400 14px ${F.sans},sans-serif`;sg.fillStyle='#F5F5F6';sg.fillText(qs.slice(0,nc)+(nc<qs.length?'|':''),ax+18,ay+45);
  const lp=cl((q-.45)/.35);if(lp>0){const d=0,c=d%cols,ro=Math.floor(d/cols),bx=ax+c*(dw+gap)+dw/2,by=gy+ro*(dh+gap);const sx=mob?ax+aw-30:ax+40,sy=ay+62;sg.strokeStyle='#fff';sg.lineWidth=1.5;sg.beginPath();sg.moveTo(sx,sy);sg.lineTo(sx,L(sy,by-8,lp));if(lp>.99){sg.lineTo(bx,by-8)}sg.stroke();sg.fillStyle='#fff';sg.fillRect(sx-3,sy-3,6,6)}
  const ap=cl((q-.82)/.18);if(ap>0){const t='18 in bin PN-F260',w=sg.measureText(t).width+28;sg.globalAlpha=ap;const px2=mob?ax:ax+aw-w,py2=mob?ay+72:ay+18;rr(sg,px2,py2,w,44,22);sg.fillStyle='#F2F2F3';sg.fill();sg.fillStyle='#0B0B0C';sg.font=`500 13.5px ${F.sans},sans-serif`;sg.fillText(t,px2+14,py2+27)}
  sg.globalAlpha=1}
 const ph=p<.3?0:p<.6?1:2;sr.forEach((r,i)=>r.classList.toggle('on',i===ph))}

let last=-1,dirty=true,alive=true;life.on(window,'resize',()=>{dirty=true});
function frame(){const y=scrollY;if(y!==last||dirty){last=y;const r=smS.getBoundingClientRect();if(r.top<innerHeight&&r.bottom>0){drawSm(RM?1:cl(-r.top/(r.height-innerHeight)));dirty=false}}if(!document.hidden)life.raf(frame)}
life.on(document,'visibilitychange',()=>{if(!document.hidden){dirty=true;life.raf(frame)}});
document.fonts.ready.then(()=>{if(alive)dirty=true});life.raf(frame);life.dispose(()=>{alive=false;sc.width=sc.height=0});
return ()=>life.close();}
