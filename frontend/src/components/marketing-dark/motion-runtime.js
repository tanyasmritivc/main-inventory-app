import {SOL,ORDER,TINT,IC,ROUTES} from './data';
import {lifecycle} from './lifecycle';
import {layoutMotion} from './layout-motion';
export function mountMotion(root,key){
const life=lifecycle();
const setTimeout=(fn,ms)=>life.timeout(fn,matchMedia('(prefers-reduced-motion: reduce)').matches?0:ms);
const setInterval=life.interval,requestAnimationFrame=life.raf;
const ic=(n,s)=>`<svg class="i" viewBox="0 0 24 24"${s?` style="width:${s}px;height:${s}px"`:''}>${IC[n]}</svg>`;
const FZ_MARK=size=>{const mark=root.querySelector('#lg .brand-slot').cloneNode(true);const svg=mark.querySelector('svg');svg.setAttribute('width',size);svg.setAttribute('height',size);return mark.outerHTML};
const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
const moveLayout=layoutMotion(life,reduce);
const cl=(v,a=0,b=1)=>Math.max(a,Math.min(b,v)),ease=t=>1-Math.pow(1-t,3);
let timers=[],io;

/* ===== smooth word slide-up for all text ===== */
const SPLIT_SEL='main h1,main h2,main h3,main .sub,main .lead,main .eb,main .free,main .nr2 .n,main .nr2 p,main .qa2 .qt,main .qa2 p,main .later b,main .later p,main .plan li,main .plan .pr,main .plan>div>div:first-child,main .ws small,main .sx-hero h1,main .sx-hero .eb';
function split(el){if(el.dataset.sp||el.closest('.fz,.win,.qa,.btn,.scard,footer,.demo,.way,.cmp,.note,.ct,.rack,.ix,.fban'))return;el.dataset.sp=1;let i=0;
 const walk=n=>{[...n.childNodes].forEach(c=>{if(c.nodeType===3){if(!c.textContent.trim())return;const f=document.createDocumentFragment();c.textContent.split(/(\s+)/).forEach(p=>{if(!p)return;if(/^\s+$/.test(p)){f.appendChild(document.createTextNode(p));return}const o=document.createElement('span');o.className='w';const inn=document.createElement('span');inn.textContent=p;inn.style.setProperty('--i',i++);if(n.classList&&n.classList.contains('ember'))inn.className='ember';o.appendChild(inn);f.appendChild(o)});c.replaceWith(f)}
  else if(c.nodeType===1&&c.tagName!=='BR'&&c.tagName.toLowerCase()!=='svg'&&!c.classList.contains('w'))walk(c)})};
 walk(el);el.querySelectorAll('.ember').forEach(e=>{if(!e.querySelector('.ember'))return;e.classList.remove('ember')});el.classList.add('split')}
let tio;function splitAll(){tio?.disconnect();tio=new IntersectionObserver(es=>es.forEach(x=>{if(x.isIntersecting){x.target.classList.add('in');tio.unobserve(x.target)}}),{threshold:.15,rootMargin:'0px 0px -6% 0px'});
 root.querySelectorAll(SPLIT_SEL).forEach(e=>{split(e);if(e.classList.contains('split')){if(e.closest('[data-hero]'))setTimeout(()=>e.classList.add('in'),e.matches('h1')?80:e.matches('.eb')?0:320);else tio.observe(e)}})}


/* hero stage: cover-fit the photo so detection boxes stay on their objects */
function clearT(){timers.forEach(clearInterval);timers=[]}
function bins(hero,labels){const b=hero&&hero.querySelector('.bins');if(!b)return;const W=innerWidth,H=hero.offsetHeight;const cw=W<700?72:120,ch=W<700?60:84;const cols=Math.ceil(W/cw)+1,rows=Math.ceil(H/ch)+1;
 b.style.gridTemplateColumns=`repeat(${cols},${cw}px)`;b.style.gridAutoRows=ch+'px';b.innerHTML='<i></i>'.repeat(cols*rows);const cells=[...b.children];
 const ok=i=>{const c=i%cols,r=Math.floor(i/cols);if(c<1||c>cols-3||r<1)return false;const dx=(c+.5)/cols-.5,dy=(r+.5)/rows-.5;return Math.hypot(dx*1.1,dy)>.28};
 const pool=cells.map((c,i)=>i).filter(ok);hero._cells=cells;if(reduce)return;
 timers.push(setInterval(()=>{for(let n=0;n<3;n++){const c=cells[pool[Math.floor(Math.random()*pool.length)]];c.classList.add('on');setTimeout(()=>c.classList.remove('on'),900+Math.random()*900)}},260));
 timers.push(setInterval(()=>{const c=cells[pool[Math.floor(Math.random()*pool.length)]];c.innerHTML=`<b>${labels[Math.floor(Math.random()*labels.length)]}</b>`;c.classList.add('hot');setTimeout(()=>c.classList.remove('hot'),2200)},1700))}
function wave(hero){(hero._cells||[]).forEach((x,i)=>setTimeout(()=>{x.classList.add('on');setTimeout(()=>x.classList.remove('on'),500)},(i%40)*12))}
function sceneInv(sc,mode,added){const key=mode+added;if(sc._key===key)return;const prev=sc._mode;sc._key=key;sc._mode=mode;const S=SOL[sc.dataset.scene].scene;
 const l=sc.querySelector('.ivl');l.classList.remove('m-hit','m-new','m-low');if(mode!=='none')l.classList.add('m-'+mode);if(l.classList.contains('added')!==added)moveLayout(l.querySelectorAll('.ir:not(.nw)'),()=>l.classList.toggle('added',added),650);
 if((mode==='hit'||mode==='low')&&prev!==mode){l.classList.remove('sw');void l.offsetWidth;l.classList.add('sw')}
 clearTimeout(sc._scroll);sc._scroll=setTimeout(()=>{const first=l.querySelector(mode==='hit'?'.is-hit':mode==='low'?'.is-low':mode==='new'?'.nw':'.nope');const y=first&&first.offsetTop+first.offsetHeight>l.clientHeight?first.offsetTop-10:0;l.scrollTo({top:Math.max(0,y),behavior:reduce?'auto':'smooth'})},mode==='new'?650:250);
 const f=sc.querySelector('.ivf'),fl=f.querySelector('.fl');const txt={none:'All items',hit:'Search: '+S.hit,new:'1 draft to review',low:'Low stock'}[mode];
 if(fl.textContent!==txt){fl.classList.add('out');clearTimeout(f._t);f._t=setTimeout(()=>{fl.textContent=txt;fl.classList.remove('out');f.classList.toggle('act',mode==='hit'||mode==='new');f.classList.toggle('amber',mode==='low')},180)}
 const c=sc.querySelector('.ivc'),to=298+(added?1:0),from=parseInt(c.textContent)||298;if(reduce){c.textContent=to+' items';return}if(from!==to){cancelAnimationFrame(c._r);const t0=performance.now();const tick=t=>{const k=cl((t-t0)/500);c.textContent=Math.round(from+(to-from)*ease(k))+' items';if(k<1)c._r=requestAnimationFrame(tick)};c._r=requestAnimationFrame(tick)}}
const prog=el=>cl((scrollY-el.offsetTop)/(el.offsetHeight-innerHeight));
/* rail v3: cached geometry, transform tied 1:1 to scroll (no extra easing loop, no layout reads per frame) */
function railSize(r){const tr=r.querySelector('.track');const cards=[...tr.children];const pad=parseFloat(getComputedStyle(tr).paddingLeft)||28;
 const last=cards[cards.length-1];const max=Math.max(0,last.offsetLeft+last.offsetWidth+pad-innerWidth);
 r._geo={max,cards,mid:cards.map(c=>c.offsetLeft+c.offsetWidth/2),bar:r.querySelector('.rprog .bar i'),names:[...r.querySelectorAll('.rprog .nm span')],tr};
 const h=Math.round(innerHeight*1.25+max*1.1);if(r._h!==h){r._h=h;r.style.height=h+'px'}r._geo.top=r.offsetTop;r._geo.height=r.offsetHeight;r._geo.sticky=r.querySelector('.rs');}
function railFrame(r){if(reduce){r.querySelector('.rs').classList.add('in');r.querySelectorAll('.scard').forEach(c=>c.classList.add('act'));return;}if(!r._geo)railSize(r);const g=r._geo;const rs=g.sticky;
 if(!r._in&&g.top-scrollY<innerHeight*.75){r._in=1;rs.classList.add('in')}
 const p=cl((scrollY-g.top-innerHeight*.1)/(g.height-innerHeight*1.25));const x=Math.round(-g.max*p*100)/100;
 if(r._x!==x){r._x=x;g.tr.style.transform=`translate3d(${x}px,0,0)`;g.bar.style.transform=`scaleX(${p.toFixed(4)})`}
 let ai=0,bd=1e9;g.mid.forEach((m,i)=>{const d=Math.abs(m+x-innerWidth/2);if(d<bd){bd=d;ai=i}});
 const act=r._in&&bd<innerWidth*.34?ai:-1;if(r._a!==act){r._a=act;g.cards.forEach((c,i)=>c.classList.toggle('act',i===act))}
 if(r._n!==ai){r._n=ai;g.names.forEach((e,i)=>e.classList.toggle('on',i===ai))}}
life.listen(window,'resize',()=>root.querySelectorAll('[data-rail]').forEach(r=>{r._geo=null;railSize(r);railFrame(r)}));
function chapSet(c,i,first){const k=ORDER[i],S=SOL[k],sc=S.scene;c.style.setProperty('--tint',TINT[k]);
 c.querySelectorAll('.cnav a').forEach((a,j)=>a.classList.toggle('on',j===i));
 const ct=c.querySelector('[data-ct]');const put=()=>{ct.innerHTML=`<small>${S.t}</small><h2>${S.h}</h2><p>${S.blurb}</p><a href="${ROUTES['/'+k]}">Explore ${S.t.toLowerCase()} ${ic('arrow')}</a>`;ct.classList.remove('out')};
 if(first)put();else{ct.classList.add('out');clearTimeout(c._t1);c._t1=setTimeout(put,230)}
 c.querySelector('[data-rw]').textContent=S.win;
 const names=[];S.items.forEach(x=>{if(names.length<9)names.push(x)});[{n:'Zip ties',q:200,loc:'Drawer 4'},{n:'Hex key set',q:6,loc:'Tool wall'}].forEach(x=>{if(names.length<9&&!names.some(y=>y.n===x.n))names.push(x)});
 const bx=c.querySelector('.bins2');bx.classList.remove('hl');const bins=[...bx.children];
 (c._bins||[]).forEach(clearTimeout);c._bins=[];bins.forEach((b,j)=>{b.classList.remove('hit');const x=names[j]||{n:'',q:''};const set=()=>{b.querySelector('span').textContent=x.n;b.querySelector('em').textContent=x.n?((x.q!==''?x.q+' · ':'')+x.loc):'';b.classList.remove('sw')};if(first)set();else{b.classList.add('sw');c._bins.push(setTimeout(set,140+j*30))}});
 const rq=c.querySelector('[data-rq]');rq.innerHTML=`<div class="u">${sc.q[0]}</div><div class="a"><span class="k">${FZ_MARK(13)}</span><div>${sc.a[0]}</div></div>`;
 (c._tm||[]).forEach(clearTimeout);const d=first?150:520;c._tm=[setTimeout(()=>rq.children[0].classList.add('on'),d),setTimeout(()=>rq.children[1].classList.add('on'),d+550),
  setTimeout(()=>{const hi=names.findIndex(x=>x.n===sc.hit);if(hi>=0){bins[hi].classList.add('hit');bx.classList.add('hl')}},d+800)]}
function frame(){root.querySelector('#nav').classList.toggle('sc',scrollY>20);
 root.querySelectorAll('[data-scene]').forEach(sc=>{const p=reduce?1:prog(sc);const S=SOL[sc.dataset.scene].scene;const win=sc.querySelector('.win');const vis=reduce||sc.getBoundingClientRect().top<innerHeight*.8;win.classList.toggle('in',vis);
  const T=[.22,.3,.44,.52,.66,.74];const messages=[...sc.querySelectorAll('.wth .mw')];if(messages.some(m=>m.classList.contains('on')!==(p>=T[+m.dataset.s-1])))moveLayout(messages,()=>messages.forEach(m=>m.classList.toggle('on',p>=T[+m.dataset.s-1])),600);
  sc.querySelector('.wchat').classList.toggle('started',p>=T[0]);
  let tx='',ti=-1,full=false;[[.12,.22,0],[.36,.44,1],[.58,.66,2]].forEach(([a,b,i])=>{if(p>=a&&p<b){const t=S.q[i];const k=cl((p-a)/(b-a-.03));tx=t.slice(0,Math.round(t.length*k));ti=i;full=k>=1}});
  const em=sc.querySelector('.wcomp em'),wc=sc.querySelector('.wcomp');em.textContent=tx||'Ask about your inventory...';em.style.color=tx?'#fff':'#6C6C71';wc.classList.toggle('typing',!!tx);wc.classList.toggle('ready',full);
  sc.querySelectorAll('.wsug span').forEach((e,i)=>e.classList.toggle('pick',ti===0&&i===0&&tx.length>3));
  const st=p<.36?0:p<.58?1:2;const key=vis?st:-1;if(sc._st!==key){sc._st=key;const C=['Ask in plain words.','Add by describing.','Know what is running low.'][Math.max(0,st)];const zt=sc.querySelector('.zt');zt.innerHTML=`<h3>${C}</h3>`;const e=zt.querySelector('h3');split(e);if(vis)requestAnimationFrame(()=>requestAnimationFrame(()=>e.classList.add('in')))}
  sc.querySelectorAll('.zbar i').forEach((b,i)=>b.style.setProperty('--f',cl((p-[.1,.36,.58][i])/([.36,.58,.86][i]-[.1,.36,.58][i]))));
  sceneInv(sc,p>=T[1]&&p<T[2]?'hit':p>=T[3]&&p<T[4]?'new':p>=T[5]?'low':'none',p>=T[3])});
 root.querySelectorAll('[data-chap]').forEach(c=>{const p=reduce?0:prog(c);const n=ORDER.length;const f=p*n;const i=Math.min(n-1,Math.floor(f));if(c._i!==i){const first=c._i===undefined;c._i=i;chapSet(c,i,first)}c.querySelectorAll('.cnav a i').forEach((e,j)=>e.style.setProperty('--f',j<i?1:j===i?cl(f-i):0))});
 root.querySelectorAll('[data-rail]').forEach(railFrame);
 root.querySelectorAll('[data-words]').forEach(w=>{const p=reduce?1:cl((scrollY+innerHeight*.75-w.offsetTop)/(w.offsetHeight*.75));const sp=[...w.querySelectorAll('.big .w>span')];const n=sp.length;sp.forEach((s,i)=>{const k=cl(p*n*1.15-i);const o=(.1+.9*k).toFixed(3),y=((1-k)*12).toFixed(1);if(s._o===o)return;s._o=o;s.style.opacity=o;s.style.transform=k>=1?'none':`translate3d(0,${y}px,0)`});const bg=w.querySelector('.wsbg');if(bg)bg.style.setProperty('--wz',(1.12-p*.08).toFixed(3));const a=w.querySelector('.act');const ak=cl((p-.82)/.12);a.style.opacity=ak;a.style.transform=`translateY(${(1-ak)*16}px)`});
 root.querySelectorAll('.ws .eb').forEach(e=>{const r=e.getBoundingClientRect();e.style.opacity=reduce||r.top<innerHeight*.9?1:0})}

const hero=root.querySelector('[data-hero]');
const labels=key.startsWith('sol:')?SOL[key.slice(4)].labels:SOL.robotics.labels.concat(SOL.workshops.labels.slice(0,2),SOL.home.labels.slice(0,1));
bins(hero,labels);
root.querySelectorAll('[data-rail]').forEach(railSize);
root.querySelectorAll('.nl>a').forEach(a=>a.classList.toggle('on',a.dataset.r===key||(a.dataset.r==='solutions'&&key.startsWith('sol:'))));
life.listen(root,'landing-chat-open',()=>{if(!reduce)wave(hero)});
life.listen(root,'click',e=>{const a=e.target.closest('a,button');if(!a)return;
 if(a.dataset.menu){root.querySelector('#mnav').classList.toggle('on',a.dataset.menu==='open');}
 if(a.hasAttribute('data-faq')){const open=a.parentNode.classList.toggle('open');a.setAttribute('aria-expanded',String(open));}
 if(a.hasAttribute('data-chapter-start')){e.preventDefault();root.querySelector('[data-chap]').scrollIntoView({behavior:reduce?'auto':'smooth'});}
 if(a.dataset.ck){e.preventDefault();const j=ORDER.indexOf(a.dataset.ck),c=root.querySelector('[data-chap]');if(reduce){chapSet(c,j,true)}else window.scrollTo({top:c.offsetTop+(c.offsetHeight-innerHeight)*(j+.5)/ORDER.length,behavior:'smooth'});}
});
life.listen(window,'keydown',e=>{if(e.key==='Escape')root.querySelector('#mnav').classList.remove('on')});
io=new IntersectionObserver(es=>es.forEach(x=>{if(x.isIntersecting){x.target.classList.add('in');io.unobserve(x.target)}}),{threshold:.12});root.querySelectorAll('.rv').forEach(e=>reduce?e.classList.add('in'):io.observe(e));splitAll();frame();
life.dispose(()=>{io?.disconnect();tio?.disconnect()});
let lastY=-1;function frameNow(){if(scrollY===lastY)return;lastY=scrollY;frame()}life.listen(window,'scroll',frameNow,{passive:true});
let rz;life.listen(window,'resize',()=>{clearTimeout(rz);rz=setTimeout(()=>{clearT();bins(hero,labels);root.querySelectorAll('[data-rail]').forEach(railSize);frame()},200)});
(function(){if(reduce)return;let target=scrollY,cur=scrollY,running=false,lastT=0,own=0;
 const maxY=()=>document.documentElement.scrollHeight-innerHeight;
 const canScroll=(el,dy)=>{for(;el&&el!==document.body&&el!==document.documentElement;el=el.parentElement){const s=getComputedStyle(el);if(/(auto|scroll)/.test(s.overflowY)&&el.scrollHeight>el.clientHeight+1){if(dy>0&&el.scrollTop+el.clientHeight<el.scrollHeight-1)return true;if(dy<0&&el.scrollTop>0)return true}}return false};
 life.listen(window,'wheel',e=>{if(e.ctrlKey||root.querySelector('#mnav').classList.contains('on'))return;
  let dy=e.deltaY*(e.deltaMode===1?16:e.deltaMode===2?innerHeight:1);if(Math.abs(e.deltaX)>Math.abs(dy))return;if(canScroll(e.target,dy))return;e.preventDefault();
  if(!running){target=cur=scrollY}
  // keep a small amount of lag so a new scroll always moves the page right away
  if(Math.sign(dy)!==Math.sign(target-cur)&&Math.abs(target-cur)>1)target=cur;
  target=Math.max(0,Math.min(maxY(),target+dy));
  if(!running){running=true;lastT=performance.now();requestAnimationFrame(step)}},{passive:false});
 function step(t){const dt=Math.min(64,t-lastT||16.7);lastT=t;const d=target-cur;
  const a=1-Math.pow(1-0.11,dt/16.7);cur+=d*a;if(Math.abs(d)<.5){cur=target;running=false}
  own++;window.scrollTo(0,cur);frameNow();if(running)requestAnimationFrame(step)}
 life.listen(window,'scroll',()=>{if(own){own--;return}if(!running){target=cur=scrollY}else if(Math.abs(scrollY-Math.round(cur))>2){running=false;target=cur=scrollY}},{passive:true});
 life.listen(window,'hashchange',()=>{running=false;target=cur=0});
 life.listen(window,'keydown',e=>{if(!/input|textarea/i.test(e.target.tagName)){running=false;target=cur=scrollY}});
 life.listen(window,'mousedown',()=>{if(running){running=false;target=cur=scrollY}});
 life.listen(window,'resize',()=>{target=Math.min(target,maxY())});
})();

return ()=>{life.destroy();root.querySelectorAll('[data-scene]').forEach(el=>{delete el._key;delete el._mode;delete el._st});root.querySelectorAll('[data-chap]').forEach(el=>{delete el._i});};
}
