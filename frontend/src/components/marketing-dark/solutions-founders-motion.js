import {EXQ,HLABS,S5C} from './solutions-founders-data';
import {IC} from './data';
export function mountSolutionsFounders(root,life,reduce,FZ_MARK){
 const document={querySelector:s=>root.querySelector(s),querySelectorAll:s=>root.querySelectorAll(s),body:window.document.body,createElement:n=>window.document.createElement(n)};
 const setTimeout=(fn,ms)=>life.timeout(fn,reduce?0:ms),setInterval=life.interval,requestAnimationFrame=life.raf;
 const listen=life.listen,addEventListener=(event,fn)=>listen(window,event,fn);
 const IntersectionObserver=class extends window.IntersectionObserver{constructor(fn,options){super(fn,options);life.dispose(()=>this.disconnect())}};
 const MutationObserver=class extends window.MutationObserver{constructor(fn){super(fn);life.dispose(()=>this.disconnect())}};
 const cl=v=>Math.max(0,Math.min(1,v)),ease=t=>1-Math.pow(1-t,3),lerp=(a,b,t)=>a+(b-a)*t;
 const ic=(n,s)=>`<svg class="i" viewBox="0 0 24 24"${s?` style="width:${s}px;height:${s}px"`:''}>${IC[n]}</svg>`;
 const timers=[];let orderFrame=()=>{};
function loopWhenVisible(cv,draw){let on=false,raf=0;const tick=t=>{if(!on||!document.body.contains(cv))return;draw(t);raf=requestAnimationFrame(tick)};
 const o=new IntersectionObserver(es=>{on=es[0].isIntersecting;cancelAnimationFrame(raf);if(on)raf=requestAnimationFrame(tick)});o.observe(cv);life.dispose(()=>{o.disconnect();on=false;cancelAnimationFrame(raf)});return ()=>{o.disconnect();on=false;cancelAnimationFrame(raf)}}
function heroDots(){const cv=document.querySelector('[data-dots]');if(!cv)return;const hero=cv.parentElement,lab=hero.querySelector('[data-hlabs]'),ctx=cv.getContext('2d');let W,H,dpr,pts=[],ptr={x:-1e4,y:-1e4},waves=[],li=0;
 const size=()=>{dpr=Math.min(1.5,devicePixelRatio||1);W=cv.clientWidth;H=cv.clientHeight;cv.width=W*dpr;cv.height=H*dpr;ctx.setTransform(dpr,0,0,dpr,0,0);const sp=W<700?19:23;pts=[];for(let y=sp/2;y<H;y+=sp)for(let x=sp/2;x<W;x+=sp)pts.push(x,y)};
 size();addEventListener('resize',size);
 listen(hero,'pointermove',e=>{const r=cv.getBoundingClientRect();ptr.x=e.clientX-r.left;ptr.y=e.clientY-r.top});listen(hero,'pointerleave',()=>{ptr.x=ptr.y=-1e4});
 const find=()=>{if(!document.body.contains(cv))return;const m=W<900,dk=cv.dataset.origin==='deck';let x=m?W*(.15+Math.random()*.7):W*(.6+Math.random()*.32),y=m?H*(.12+Math.random()*.3):H*(.22+Math.random()*.58);
  if(dk){x=m?W*(.3+Math.random()*.4):W*(.66+Math.random()*.16);y=m?H*(.12+Math.random()*.22):H*(.35+Math.random()*.3)}
  waves.push({x,y,t0:performance.now()});if(cv.hasAttribute('data-nolabels')||!lab)return;const d=document.createElement('div');d.className='hlab';const L=HLABS[li++%HLABS.length].split(' · ');d.innerHTML=`${L[0]}<small>${L[1]||''}</small>`;d.style.left=x+'px';d.style.top=y+'px';lab.appendChild(d);
  setTimeout(()=>d.classList.add('on'),450);setTimeout(()=>{d.classList.remove('on');setTimeout(()=>d.remove(),600)},3600)};
 const draw=t=>{ctx.clearRect(0,0,W,H);waves=waves.filter(w=>t-w.t0<4200);
  for(let i=0;i<pts.length;i+=2){const x=pts[i],y=pts[i+1];let a=.14;const dx=x-ptr.x,dy=y-ptr.y,dp=dx*dx+dy*dy;if(dp<32400)a+=.55*(1-Math.sqrt(dp)/180);
   for(const w of waves){const age=t-w.t0,r=age*.38,d=Math.hypot(x-w.x,y-w.y),k=d-r;if(k>-60&&k<60)a+=.55*Math.exp(-(k*k)/700)*Math.max(0,1-age/2400);if(d<26)a+=.6*Math.max(0,1-Math.max(0,age-400)/3600)}
   ctx.globalAlpha=Math.min(1,a);ctx.fillStyle='#fff';ctx.fillRect(x-.8,y-.8,1.6,1.6)}
  ctx.globalAlpha=1;for(const w of waves){const age=t-w.t0;if(age<400)continue;const k=Math.min(1,(age-400)/500);ctx.strokeStyle=`rgba(255,255,255,${.85*(1-Math.max(0,age-3000)/1200)})`;ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(w.x,w.y,6+k*8,0,7);ctx.stroke();ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(w.x,w.y,3,0,7);ctx.fill()}};
 if(reduce){draw(performance.now());return}
 loopWhenVisible(cv,draw);setTimeout(find,900);timers.push(setInterval(find,2600))}
function orderDots(){const sec=document.querySelector('[data-v4p]');if(!sec)return;const cv=sec.querySelector('[data-order]'),ctx=cv.getContext('2d');let W,H,dpr,P=[],bins=[];let rs=1;const rnd=()=>{rs=(rs*16807)%2147483647;return rs/2147483647};
 const size=()=>{dpr=Math.min(1.5,devicePixelRatio||1);W=cv.clientWidth;H=cv.clientHeight;cv.width=W*dpr;cv.height=H*dpr;ctx.setTransform(dpr,0,0,dpr,0,0);rs=7;P=[];bins=[];
  const C=4,R=3,gx=W*.06,gw=(W-gx*2),bw=gw/C-12,bh=Math.min(110,(H*.8)/R-14),oy=(H-(bh+14)*R)/2;
  for(let b=0;b<C*R;b++){const bx=gx+(b%C)*(bw+12)+6,by=oy+Math.floor(b/C)*(bh+14);bins.push([bx,by,bw,bh]);for(let j=0;j<14;j++){const tx=bx+bw*(.12+(j%7)*.127),ty=by+bh*(j<7?.38:.68);P.push({sx:rnd()*W,sy:rnd()*H,tx,ty,b,ph:rnd()*6.28,d:(b/(C*R))*.35+rnd()*.08})}}};
 size();addEventListener('resize',size);
 const draw=t=>{const p=reduce?1:cl((scrollY-sec.offsetTop+innerHeight*.75)/(sec.offsetHeight-innerHeight*.25));ctx.clearRect(0,0,W,H);
  sec.querySelectorAll('.ln').forEach(e=>e.classList.toggle('in',p>=.55));
  const bk=cl((p-.15)/.3);bins.forEach(([x,y,w,h],i)=>{ctx.globalAlpha=bk*.9;ctx.strokeStyle=i===6&&p>.75?'rgba(227,180,92,.9)':'rgba(255,255,255,.14)';ctx.lineWidth=1;ctx.beginPath();ctx.roundRect?ctx.roundRect(x,y,w,h,10):ctx.rect(x,y,w,h);ctx.stroke()});
  const found=cl((p-.75)/.12);
  for(const d of P){const k=ease(cl((p-.05-d.d*.7)/.42));const wob=(1-k)*6;const x=lerp(d.sx,d.tx,k)+Math.sin(t/900+d.ph)*wob,y=lerp(d.sy,d.ty,k)+Math.cos(t/1100+d.ph)*wob;
   const hot=d.b===6&&found>0;ctx.globalAlpha=hot?.5+.5*found:.35+.45*k;ctx.fillStyle=hot?'#E3B45C':'#fff';ctx.beginPath();ctx.arc(x,y,hot?2.6+found:2.1,0,7);ctx.fill()}
  if(found>0){const [x,y,w,h]=bins[6];ctx.globalAlpha=found;ctx.fillStyle='rgba(227,180,92,.12)';ctx.fillRect(x,y,w,h);ctx.fillStyle='#E3B45C';ctx.font='500 12px Inter,system-ui';ctx.fillText('Found · Bin 7',x+10,y+20)}ctx.globalAlpha=1};
 orderFrame=()=>{const rect=cv.getBoundingClientRect();if(rect.top<innerHeight&&rect.bottom>0)draw(performance.now())};if(reduce){draw(0);return}loopWhenVisible(cv,draw)}
function cmdInit(){const c=document.querySelector('.cmd');if(!c)return;const em=c.querySelector('em'),go=c.querySelector('.bar b'),res=c.querySelector('.res');let cur=-1,ty,auto,answerTimer;let generation=0;
 const show=i=>{const version=++generation;clearTimeout(answerTimer);cur=i;document.querySelectorAll('[data-q]').forEach(b=>b.classList.toggle('on',+b.dataset.q===i));const e=EXQ[i];res.classList.remove('on');clearInterval(ty);let n=0;em.textContent='';
  const done=()=>{go.classList.add('go');answerTimer=setTimeout(()=>{if(version!==generation)return;go.classList.remove('go');res.innerHTML=`<div class="a"><span class="k">${FZ_MARK(14)}</span><div>${e.a}</div></div>${e.r.map((r,j)=>`<div class="rw" style="transition-delay:${.15+j*.1}s"><i>${ic('box')}</i><div><b>${r[0]}</b><small>${r[1]}</small></div><span class="n">${r[2]}</span></div>`).join('')}`;requestAnimationFrame(()=>{if(version===generation)res.classList.add('on')})},320)};
  if(reduce){em.textContent=e.q;done();return}ty=setInterval(()=>{n++;em.textContent=e.q.slice(0,n);if(n>=e.q.length){clearInterval(ty);done()}},34);timers.push(ty)};
 document.querySelectorAll('[data-q]').forEach(b=>b.onclick=()=>{clearInterval(auto);show(+b.dataset.q)});
 const o=new IntersectionObserver(es=>{if(es[0].isIntersecting){o.disconnect();show(0);if(!reduce){auto=setInterval(()=>show((cur+1)%EXQ.length),7000);timers.push(auto)}}},{threshold:0});if(reduce)show(0);else o.observe(c)}
function faInit(){const st=document.querySelector('[data-stage3d]');if(!st)return;const pass=st.querySelector('.pass'),hero=st.closest('.fah');
 if(!reduce){listen(hero,'pointermove',e=>{const r=st.getBoundingClientRect();const x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;pass.style.setProperty('--ry',(-14+x*22).toFixed(2)+'deg');pass.style.setProperty('--rx',(6-y*16).toFixed(2)+'deg');pass.style.setProperty('--sx',(-x*70).toFixed(1)+'%')});
  listen(hero,'pointerleave',()=>{pass.style.removeProperty('--ry');pass.style.removeProperty('--rx');pass.style.removeProperty('--sx')})}
 const ob=new IntersectionObserver(es=>es.forEach(x=>{if(x.isIntersecting){x.target.classList.add('in');ob.unobserve(x.target)}}),{threshold:0});
 document.querySelectorAll('[data-fan],[data-ptab]').forEach(e=>reduce?e.classList.add('in'):ob.observe(e));
 document.querySelectorAll('[data-wt]').forEach(t=>listen(t,'click',()=>t.classList.toggle('open')));
 tabsInit()}
function tabsInit(){const tl=document.querySelector('[data-tl3]');if(!tl)return;const bs=[...tl.querySelectorAll('button')],ps=[...document.querySelectorAll('.appw .pane')];let cur=0,tm;
 const set=i=>{cur=i;bs.forEach((b,j)=>{b.classList.toggle('on',j===i);b.classList.remove('run')});ps.forEach((p,j)=>p.classList.toggle('on',j===i));if(reduce)return;void bs[i].offsetWidth;bs[i].classList.add('run');clearTimeout(tm);tm=setTimeout(()=>set((cur+1)%bs.length),6000);timers.push(tm)};
 bs.forEach((b,i)=>b.onclick=()=>set(i));
 const o2=new IntersectionObserver(es=>{if(es[0].isIntersecting){o2.disconnect();ps.forEach(p=>p.classList.remove('on'));requestAnimationFrame(()=>set(0))}},{threshold:0});if(reduce)set(0);else o2.observe(tl)}
function s5Init(){const dk=document.querySelector('[data-deck]');if(!dk)return;const inner=dk.querySelector('.dk'),hero=dk.closest('.s5h');
 if(!reduce){listen(hero,'pointermove',e=>{const r=dk.getBoundingClientRect();const x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;inner.style.setProperty('--ry',(-16+x*20).toFixed(2)+'deg');inner.style.setProperty('--rx',(4-y*12).toFixed(2)+'deg')});listen(hero,'pointerleave',()=>{inner.style.removeProperty('--ry');inner.style.removeProperty('--rx')});
  const cycle=()=>{if(!document.body.contains(dk))return;const cs=[...dk.querySelectorAll('.dc')];const f=cs.find(c=>c.dataset.p==='0');f.classList.add('out');
   setTimeout(()=>{cs.forEach(c=>{c.dataset.p=(+c.dataset.p+3)%4});f.style.transition='none';f.classList.remove('out');requestAnimationFrame(()=>requestAnimationFrame(()=>{f.style.transition=''}))},650)};
  timers.push(setInterval(cycle,3400))}
 document.querySelectorAll('[data-at]').forEach(t=>{listen(t,'pointermove',e=>{const r=t.getBoundingClientRect();t.style.setProperty('--mx',(e.clientX-r.left)+'px');t.style.setProperty('--my',(e.clientY-r.top)+'px')});
  listen(t,'click',e=>{if(!matchMedia('(hover:hover)').matches&&!t.classList.contains('open')){e.preventDefault();t.classList.add('open')}})});
 tabsInit();
 /* the orb behind the example questions takes the colour of the chosen audience */
 const orb=document.querySelector('.v4q .orb.c');if(orb){const tint=i=>{const k=EXQ[i].k;orb.style.background=`radial-gradient(circle,${S5C[k][1]} 0%,transparent 65%)`};tint(0);document.querySelectorAll('[data-q]').forEach(b=>listen(b,'click',()=>tint(+b.dataset.q)));
  new MutationObserver(()=>{const on=document.querySelector('[data-q].on');if(on)tint(+on.dataset.q)}).observe(document.querySelector('.qtabs'),{subtree:true,attributes:true,attributeFilter:['class']})}}

 heroDots();orderDots();cmdInit();if(root.querySelector('[data-deck]'))s5Init();else faInit();
 root.querySelectorAll('[data-q], [data-t]').forEach(button=>life.dispose(()=>{button.onclick=null}));
 const reveals=new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){entry.target.classList.add('in');reveals.unobserve(entry.target)}}),{threshold:0});
 root.querySelectorAll('.wv').forEach(el=>reduce?el.classList.add('in'):reveals.observe(el));
 listen(root,'click',event=>{const link=event.target.closest('[data-scroll-target]');if(link){event.preventDefault();root.querySelector('#'+link.dataset.scrollTarget)?.scrollIntoView({behavior:reduce?'auto':'smooth'})}});
 // A circular mask scales while its photo counter-scales, so only transforms change.
 root.querySelectorAll('.at,.wt').forEach(tile=>{
  const mask=tile.querySelector('.ph'),plane=mask?.querySelector('.photo-plane');if(!plane)return;
  let width,height,radius,cx,cy,expanded,current=1,animation=0;
  const size=()=>{width=tile.clientWidth;height=tile.clientHeight;const small=innerWidth<=900;radius=tile.classList.contains('at')?(small?28:42):34;const offset=tile.classList.contains('at')?(small?52:74):64;cx=width-offset;cy=offset;expanded=Math.hypot(width,height)/radius;
   mask.style.cssText=`left:${cx-radius}px;top:${cy-radius}px;width:${radius*2}px;height:${radius*2}px`;
   plane.style.cssText=`width:${width}px;height:${height}px;left:${radius-cx}px;top:${radius-cy}px;transform-origin:${cx}px ${cy}px`;
   paint(current);
  };
  const paint=value=>{mask.style.transform=`scale(${value})`;plane.style.transform=`scale(${1/value})`;mask.style.opacity=String(1-.55*cl((value-1)/(expanded-1)));};
  const animate=open=>{cancelAnimationFrame(animation);const from=current,to=open?expanded:1,start=performance.now();const tick=now=>{const p=reduce?1:cl((now-start)/(tile.classList.contains('at')?1000:900));current=lerp(from,to,ease(p));paint(current);if(p<1)animation=requestAnimationFrame(tick)};tick(start)};
  const update=()=>animate(tile.classList.contains('open')||tile.matches(':hover')&&matchMedia('(hover:hover)').matches);
  size();listen(tile,'pointerenter',()=>{if(matchMedia('(hover:hover)').matches)animate(true)});listen(tile,'pointerleave',update);listen(tile,'click',update);
  const resize=new ResizeObserver(size);resize.observe(tile);life.dispose(()=>{resize.disconnect();cancelAnimationFrame(animation)});
 });
 return ()=>orderFrame();
}
