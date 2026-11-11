import {homeLife} from './home-life';
const cl=(v,a=0,b=1)=>Math.min(b,Math.max(a,v)),L=(a,b,t)=>a+(b-a)*t,ss=(a,b,x)=>{const t=cl((x-a)/(b-a));return t*t*(3-2*t)},eo=t=>1-Math.pow(1-t,3);
const $=id=>document.getElementById(id);
// Math, sample grid and timeline are ported from landing-readable.html.
export function mountHeader(){const life=homeLife();const nav=$('x-nav');let pY=scrollY,acc=0;const onS=()=>{const y=scrollY,d=y-pY;pY=y;nav.classList.toggle('sc',y>10);if(y<80){nav.classList.remove('hid');acc=0;return}acc=(Math.sign(d)===Math.sign(acc)?acc:0)+d;if(acc>24)nav.classList.add('hid');else if(acc<-12)nav.classList.remove('hid')};life.on(window,'scroll',onS,{passive:true});onS();life.on(nav,'focusin',()=>nav.classList.remove('hid'));
return ()=>life.close();}
export function mountTour(){const life=homeLife(),RM=matchMedia('(prefers-reduced-motion: reduce)').matches,Q=(s,r=document)=>[...r.querySelectorAll(s)];
const stage=$('x-stage'),sc=$('x-scale');let S=1;
function fit(){S=stage.clientWidth/1160;sc.style.transform=`scale(${S})`}life.on(window,'resize',fit);fit();
// ---------- product tour ----------
const app=$('app'),cur=$('cur'),pscan=$('pscan');let tm=[],paused=false;
const at=(ms,f)=>tm.push(life.timeout(f,ms));
function pos(el,dx=.5,dy=.5){const a=app.getBoundingClientRect(),r=el.getBoundingClientRect();return[(r.left-a.left)/S+r.width/S*dx,(r.top-a.top)/S+r.height/S*dy]}
function move(el,dx,dy){const [x,y]=pos(el,dx,dy);cur.style.left=(x-4)+'px';cur.style.top=(y-3)+'px'}
function click(){cur.classList.add('dn');life.timeout(()=>cur.classList.remove('dn'),160)}
function type(el,txt,ms,done){let n=0;el.classList.add('ty');(function t(){n++;el.innerHTML=txt.slice(0,n)+'<i></i>';if(n<txt.length)at(ms,t);else done&&done()})()}
function reset(){tm.forEach(life.clear);tm=[];['m1','m2','m3','rv','toast','dd','att','snd'].forEach(id=>$(id).classList.remove('on'));
 Q('.it,.pin').forEach(e=>e.classList.remove('on'));$('aph').className='ph';$('aph').textContent='Ask about your inventory...';$('spt').textContent='Choose a Space';$('lhc').textContent='Finding objects…';$('ddw').classList.remove('hl');pscan.getAnimations().forEach(a=>a.cancel());
 $('m1').style.top='22px';$('rv').style.top='80px'}
function finalState(){reset();$('m2').classList.add('on');$('m3').classList.add('on');$('toast').classList.remove('on')}
let tok=0;
const pending=new Set();
const wait=(ms,t)=>new Promise((res,rej)=>{pending.add(rej);tm.push(life.timeout(()=>{pending.delete(rej);t===tok?res():rej('x')},ms))});
function stop(){tok++;tm.forEach(life.clear);tm=[];pending.forEach(reject=>reject('x'));pending.clear();pscan.getAnimations().forEach(a=>a.cancel())}
life.dispose(stop);
function typeP(el,txt,ms,t){return new Promise(async(res,rej)=>{el.classList.add('ty');try{for(let n=1;n<=txt.length;n++){el.innerHTML=txt.slice(0,n)+'<i></i>';await wait(ms,t)}res()}catch(e){rej(e)}})}
async function tour(){reset();const t=++tok,ph=$('aph');
 try{
  await wait(300,t);move($('apl'));await wait(1000,t);click();$('att').classList.add('on');
  await wait(400,t);move($('aph'),.3,.5);await wait(700,t);click();
  await typeP(ph,'Add everything on this bench',42,t);$('snd').classList.add('on');move($('snd'));await wait(900,t);click();
  $('m1').classList.add('on');$('att').classList.remove('on');$('snd').classList.remove('on');ph.className='ph';ph.textContent='Ask about your inventory...';
  await wait(500,t);$('rv').classList.add('on');$('pscan').animate([{top:'-60px'},{top:'100%'}],{duration:1800,easing:'cubic-bezier(.45,0,.2,1)'});
  const its=Q('.it'),pins=Q('.pin');await wait(600,t);
  for(let k=0;k<its.length;k++){its[k].classList.add('on');pins[k]&&pins[k].classList.add('on');$('lhc').textContent=`${k+1} of 6 selected · Not saved yet`;await wait(330,t)}
  await wait(500,t);move($('spb'));await wait(1000,t);click();$('spb').classList.add('pr');life.timeout(()=>$('spb').classList.remove('pr'),150);$('dd').classList.add('on');
  await wait(700,t);move($('ddw'),.4,.5);await wait(900,t);$('ddw').classList.add('hl');click();
  await wait(350,t);$('dd').classList.remove('on');$('spt').textContent='Save 6 items to Workbench';move($('spb'));
  await wait(1000,t);click();$('spb').classList.add('pr');life.timeout(()=>$('spb').classList.remove('pr'),150);
  await wait(300,t);$('rv').classList.remove('on');$('m1').classList.remove('on');$('toast').classList.add('on');
  await wait(900,t);move($('aph'),.3,.5);await wait(900,t);click();$('toast').classList.remove('on');
  await typeP(ph,'Where are the washers?',48,t);$('snd').classList.add('on');move($('snd'));await wait(800,t);click();
  $('m2').classList.add('on');$('snd').classList.remove('on');ph.className='ph';ph.textContent='Ask about your inventory...';
  await wait(800,t);$('m3').classList.add('on');await wait(800,t);move($('aph'),.85,1.6);
  await wait(6500,t);if(!paused&&visible&&!document.hidden)tour();
 }catch(e){}}
const pp=$('x-pp');
function setPP(){$('x-ppt').textContent=paused?'Play':'Pause';$('x-ppi').innerHTML=paused?'<path d="M7 5l12 7-12 7z"/>':'<path d="M7 5h3v14H7zM14 5h3v14h-3z"/>'}
life.on(pp,'click',()=>{if(RM)return;paused=!paused;setPP();if(paused){stop();finalState()}else if(visible&&!document.hidden)tour()});
life.on(document,'keydown',e=>{if(e.key==='Escape'&&!paused){paused=true;setPP();stop();finalState()}});
let visible=false;
const resume=()=>{if(RM||paused||!visible||document.hidden)stop();else tour()};
if(RM){paused=true;setPP();finalState()}
life.observer(es=>{visible=es[0].isIntersecting&&es[0].intersectionRatio>=.3;resume()},{threshold:[0,.3]}).observe(stage);
life.on(document,'visibilitychange',resume);
life.dispose(()=>Q('.it,.pin,.msg').forEach(e=>e.classList.remove('on')));

return ()=>life.close();}
export function mountScroll(){const life=homeLife(),RM=matchMedia('(prefers-reduced-motion: reduce)').matches,fine=matchMedia('(pointer:fine)').matches;// ---- smooth, eased scrolling (wheel and trackpad on desktop) ----
let tgt=scrollY,cur=scrollY;const maxY=()=>document.documentElement.scrollHeight-innerHeight;
if(!RM&&fine){
 life.on(window,'wheel',e=>{if(e.ctrlKey||Math.abs(e.deltaX)>Math.abs(e.deltaY))return;e.preventDefault();const d=e.deltaY*(e.deltaMode===1?16:e.deltaMode===2?innerHeight:1);tgt=cl(tgt+d,0,maxY())},{passive:false});
 life.on(window,'scroll',()=>{if(Math.abs(scrollY-cur)>3){tgt=cur=scrollY}},{passive:true});
 life.on(window,'keydown',e=>{const k={ArrowDown:80,ArrowUp:-80,PageDown:innerHeight*.9,PageUp:-innerHeight*.9,' ':e.shiftKey?-innerHeight*.9:innerHeight*.9,Home:-1e9,End:1e9}[e.key];if(k===undefined||e.target.closest('input,textarea,select,button,a,[contenteditable=true]'))return;e.preventDefault();tgt=cl(tgt+k,0,maxY())});
 document.querySelectorAll('a[href^="#"]').forEach(a=>life.on(a,'click',e=>{const href=a.getAttribute('href');if(href==='#')return;const el=document.getElementById(href.slice(1));if(!el)return;e.preventDefault();history.replaceState(null,'',href);tgt=cl(el.getBoundingClientRect().top+scrollY-60,0,maxY())}));
}
// ---- headline word reveal ----
document.querySelectorAll('.landing-home .x-h2').forEach(h=>{const original=h.innerHTML;life.dispose(()=>{h.innerHTML=original;h.classList.remove('on')});const sp=h.querySelector('span');const wrap=n=>{n.childNodes.forEach(c=>{if(c.nodeType===3){const f=document.createDocumentFragment();c.textContent.split(/(\s+)/).forEach((w,i)=>{if(/^\s+$/.test(w)||!w){f.appendChild(document.createTextNode(w));return}const e=document.createElement('span');e.className='wd';e.textContent=w;f.appendChild(e)});n.replaceChild(f,c)}})};wrap(h);if(sp)wrap(sp);
 [...h.querySelectorAll('.wd')].forEach((w,i)=>w.style.transitionDelay=(i*35)+'ms')});
const rio=life.observer(es=>es.forEach(e=>{if(e.isIntersecting){e.target.classList.add('on');rio.unobserve(e.target)}}),{threshold:.4});document.querySelectorAll('.x-h2').forEach(h=>rio.observe(h));
if(RM)document.querySelectorAll('.x-h2').forEach(h=>h.classList.add('on'));

let last=-1;function frame(){if(!RM&&fine){const d=tgt-cur;if(Math.abs(d)>.5){cur+=d*.16;window.scrollTo(0,cur)}else if(cur!==tgt){cur=tgt;window.scrollTo(0,cur)}}
 const y=scrollY;if(last!==y){last=y;const k=RM?1:eo(cl(y/520));$('x-stage').style.transform=`rotateX(${(1-k)*16}deg) scale(${.93+.07*k}) translateY(${(1-k)*-12}px)`}if(!document.hidden)life.raf(frame)}
life.on(document,'visibilitychange',()=>{if(!document.hidden)life.raf(frame)});life.raf(frame);
const mq=document.querySelector('.landing-home .mqr');life.observer(es=>{mq.style.animationPlayState=es[0].isIntersecting?'running':'paused'}).observe(mq);
return ()=>life.close();}
export function mountBackground(){const life=homeLife();// ---- background: the mark's petals drift apart into bins and come back ----
const bg=$('x-bg'),g=bg.getContext('2d'),MK=new Path2D('M12 24A12 12 0 0 1 24 12L40.5 12A5 5 0 0 1 45.5 17L45.5 38.5A4.5 4.5 0 0 0 50 43A4.5 4.5 0 0 0 54.5 38.5L54.5 17A5 5 0 0 1 59.5 12L76 12A12 12 0 0 1 88 24L88 40.5A5 5 0 0 1 83 45.5L61.5 45.5A4.5 4.5 0 0 0 57 50A4.5 4.5 0 0 0 61.5 54.5L83 54.5A5 5 0 0 1 88 59.5L88 76A12 12 0 0 1 76 88L59.5 88A5 5 0 0 1 54.5 83L54.5 61.5A4.5 4.5 0 0 0 50 57A4.5 4.5 0 0 0 45.5 61.5L45.5 83A5 5 0 0 1 40.5 88L24 88A12 12 0 0 1 12 76L12 59.5A5 5 0 0 1 17 54.5L38.5 54.5A4.5 4.5 0 0 0 43 50A4.5 4.5 0 0 0 38.5 45.5L17 45.5A5 5 0 0 1 12 40.5Z');let W=0,H=0;
function bsize(){const d=1;W=innerWidth;H=innerHeight;bg.width=W*d;bg.height=H*d;g.setTransform(d,0,0,d,0,0)}life.on(window,'resize',bsize);bsize();
const QD=[[0,0,-1,-1],[50,0,1,-1],[0,50,-1,1],[50,50,1,1]];
function drawBg(p,t){g.clearRect(0,0,W,H);const mob=W<700,apart=ss(.1,.32,p)*(1-ss(.7,.9,p)),grid=ss(.32,.55,p)*(1-ss(.7,.9,p));
 const sz=L(mob?W*1.1:Math.min(W*.6,H*1.05),mob?W*.8:Math.min(W*.4,H*.68),ss(.1,.5,p)),cx=L(W*.82,W*.74,ss(.1,.5,p)),cy=L(H*.55,H*.5,ss(.1,.5,p)),rot=L(-.22,0,ss(.05,.55,p))+L(0,-.18,ss(.7,.95,p))+.02*Math.sin(t*.3);
 g.save();g.globalAlpha=mob?.1:.13;g.translate(cx,cy);g.rotate(rot);g.scale(sz/100,sz/100);g.translate(-50,-50);
 for(const [qx,qy,dx,dy] of QD){const gap=apart*14+grid*10,sp=dx*dy*apart*.35*(1-grid);g.save();g.translate(dx*gap,dy*gap);g.translate(qx+25,qy+25);g.rotate(sp);g.translate(-qx-25,-qy-25);g.beginPath();g.rect(qx-1,qy-1,52,52);g.clip();
  const lg=g.createLinearGradient(qx,qy,qx+50,qy+50);lg.addColorStop(0,'#E5E5E8');lg.addColorStop(.5,'#6E6E73');lg.addColorStop(1,'#1A1A1C');g.fillStyle=lg;g.fill(MK);g.lineWidth=.35;g.strokeStyle='rgba(255,255,255,.6)';g.stroke(MK);g.restore()}
 g.restore()}

let last=-1,dirty=true;life.on(window,'resize',()=>{dirty=true});
function frame(){const y=scrollY;if(y!==last||dirty){last=y;dirty=false;const max=document.documentElement.scrollHeight-innerHeight;const r=$('pm').getBoundingClientRect(),f=$('fa-card').getBoundingClientRect();const hidden=(r.top<innerHeight*.6&&r.bottom>innerHeight*.4)||(f.top<innerHeight*.7&&f.bottom>innerHeight*.3);bg.style.opacity=hidden?'0':'1';if(!hidden)drawBg(max>0?y/max:0,0)}if(!document.hidden)life.raf(frame)}
life.on(document,'visibilitychange',()=>{if(!document.hidden){dirty=true;life.raf(frame)}});life.raf(frame);life.dispose(()=>{bg.width=bg.height=0});
return ()=>life.close();}
export function mountPinned(){const life=homeLife(),RM=matchMedia('(prefers-reduced-motion: reduce)').matches;// ---- pinned section: photo -> particles -> parts list ----
const pmS=$('pm'),pc=$('pmc'),pg=pc.getContext('2d'),rows=[...document.querySelectorAll('.pm-r')];
let PW=0,PH=0,PTS=[],ready=false,dirty=true;
const BOX=[['Extension springs',14,12,24,57,37],['Timing pulleys',11,14,44,62,59],['Socket head screws',120,58,57,96,96],['Compression springs',36,0,2,22,30],['Sprocket',1,70,33,82,45],['Pinion gears',3,40,62,52,86]];
const NX=60,NY=80,AR=4/3;
const img=new Image();img.onload=()=>{const c=document.createElement('canvas');c.width=NX;c.height=NY;const x=c.getContext('2d');x.drawImage(img,0,0,NX,NY);const d=x.getImageData(0,0,NX,NY).data;
 for(let j=0;j<NY;j++)for(let i=0;i<NX;i++){const k=(j*NX+i)*4,cr=d[k],cg=d[k+1],cb=d[k+2],l=Math.round(.3*cr+.59*cg+.11*cb),u=(i+.5)/NX*100,v=(j+.5)/NY*100;let b=-1;
  BOX.forEach((B,bi)=>{if(b<0&&u>=B[2]&&u<=B[4]&&v>=B[3]&&v<=B[5])b=bi});PTS.push({u,v,l,cr,cg,cb,b,r:Math.random()})}
 ready=true;dirty=true};img.src='/landing/bins-md.jpg';
function psize(){const d=Math.min(1.5,devicePixelRatio||1);PW=pc.clientWidth;PH=pc.clientHeight;pc.width=PW*d;pc.height=PH*d;pg.setTransform(d,0,0,d,0,0)}life.on(window,'resize',psize);psize();
function drawPm(p,t){pg.clearRect(0,0,PW,PH);if(!ready)return;const mob=PW<700;
 let ph=mob?Math.min(PH*.56,(PW-32)*AR):Math.min(PH*.8,780),pw=ph/AR;const px=mob?(PW-pw)/2:PW-pw-Math.max(40,(PW-1160)/2)-40,py=mob?PH-ph-28:(PH-ph)/2;
 const cs=pw/NX,sep=ss(.18,.42,p),lst=ss(.45,.78,p),txt=ss(.72,.92,p),scan=ss(.02,.2,p);
 const LW=mob?pw:Math.max(pw,420),rowH=Math.min(ph/6.4,62),th=rowH*.78,lx=mob?px:px+pw-LW,ly=py+(ph-rowH*6)/2;
 for(const q of PTS){let x=px+q.u/100*pw,y=py+q.v/100*ph,a=1,s=cs*.82,l=q.l;
  if(q.b<0){a=1-sep*.88-lst*.12;y+=sep*(10+q.r*30);x+=(q.r-.5)*sep*20;if(a<=.01)continue}
  else{const B=BOX[q.b],k=eo(cl((lst-q.r*.25)/.75));if(k>0){const nu=(q.u-B[2])/(B[4]-B[2]),nv=(q.v-B[3])/(B[5]-B[3]);const tx=lx+nu*th,ty=ly+q.b*rowH+(rowH-th)/2+nv*th;x=L(x,tx,k);y=L(y,ty,k);s=L(cs*.82,th/Math.max(8,Math.sqrt(PTS.length/60)),k)}
   l=1+sep*.12}
  const f=q.b<0?1:l;pg.fillStyle=`rgba(${Math.min(255,q.cr*f)|0},${Math.min(255,q.cg*f)|0},${Math.min(255,q.cb*f)|0},${a})`;pg.fillRect(x-s/2,y-s/2,s,s)}
 // scan line
 if(scan>0&&scan<1){const sy=py+scan*ph;const gr=pg.createLinearGradient(0,sy-50,0,sy);gr.addColorStop(0,'rgba(255,255,255,0)');gr.addColorStop(1,'rgba(255,255,255,.35)');pg.fillStyle=gr;pg.fillRect(px,sy-50,pw,50);pg.fillStyle='rgba(255,255,255,.9)';pg.fillRect(px,sy,pw,1.2)}
 // frame corners
 const fa=1-lst;if(fa>0){pg.strokeStyle=`rgba(255,255,255,${.5*fa})`;pg.lineWidth=1.5;const c=18;[[px,py,1,1],[px+pw,py,-1,1],[px,py+ph,1,-1],[px+pw,py+ph,-1,-1]].forEach(([x,y,dx,dy])=>{pg.beginPath();pg.moveTo(x+dx*c,y);pg.lineTo(x,y);pg.lineTo(x,y+dy*c);pg.stroke()})}
 // boxes + labels while separating
 pg.font=`500 11px ${getComputedStyle(pc).getPropertyValue('--font-geist-mono')},monospace`;
 const ba=sep*(1-lst);if(ba>.01)BOX.forEach((B,i)=>{const x=px+B[2]/100*pw,y=py+B[3]/100*ph,w=(B[4]-B[2])/100*pw,h=(B[5]-B[3])/100*ph;pg.strokeStyle=`rgba(255,255,255,${.85*ba})`;pg.lineWidth=1.2;pg.strokeRect(x,y,w,h);
  const lab=B[0].toLowerCase().replace(/ /g,'_')+' '+(0.95-i*.012).toFixed(2),tw=pg.measureText(lab).width+12;const lx0=Math.min(x,px+pw-tw);pg.fillStyle=`rgba(245,245,246,${ba})`;pg.fillRect(lx0,y-18,tw,17);pg.fillStyle=`rgba(0,0,0,${ba})`;pg.fillText(lab,lx0+6,y-6)});
 // list text
 if(txt>0){BOX.forEach((B,i)=>{const y=ly+i*rowH,k=cl(txt*1.6-i*.12);if(k<=0)return;pg.globalAlpha=k;pg.fillStyle='#F5F5F6';pg.font=`400 16px ${getComputedStyle(pc).getPropertyValue('--font-app-inter')},sans-serif`;pg.fillText(B[0],lx+th+18,y+rowH/2+5);
  pg.font=`500 13px ${getComputedStyle(pc).getPropertyValue('--font-geist-mono')},monospace`;const n=Math.round(B[1]*k),nt='× '+n;pg.fillStyle='#A1A1A6';pg.fillText(nt,lx+LW-pg.measureText(nt).width,y+rowH/2+5);
  pg.fillStyle='rgba(255,255,255,.08)';pg.fillRect(lx+th+18,y+rowH-1,LW-th-18,1);pg.globalAlpha=1})}
 // copy state
 const ph2=p<.36?0:p<.7?1:2;rows.forEach((r,i)=>{r.classList.toggle('on',i===ph2);r.querySelector('i').style.width=(i<ph2?100:i===ph2?(ph2===0?cl(p/.36):ph2===1?cl((p-.36)/.34):cl((p-.7)/.3))*100:0)+'%'});}

let last=-1;life.on(window,'resize',()=>{dirty=true});
function frame(){const y=scrollY;if(y!==last||dirty){last=y;const r=pmS.getBoundingClientRect();if(r.top<innerHeight&&r.bottom>0){drawPm(RM?1:cl(-r.top/(r.height-innerHeight)),0);dirty=false}}
 if(!document.hidden)life.raf(frame)}life.on(document,'visibilitychange',()=>{if(!document.hidden){dirty=true;life.raf(frame)}});life.raf(frame);
life.dispose(()=>{img.onload=null;img.src='';PTS=[];pc.width=pc.height=0});
return ()=>life.close();}
export function mountFounders(){const life=homeLife();const RM=matchMedia('(prefers-reduced-motion: reduce)').matches,card=document.getElementById('fa-card'),pass=document.getElementById('fa-pass'),sh=document.getElementById('fa-sheen'),cv=document.getElementById('fa-dots'),g=cv.getContext('2d');
let scheduled=false;let W=0,H=0,mx=0,my=0,tx=0,ty=0,vis=false;
function size(){const d=Math.min(2,devicePixelRatio||1);W=cv.clientWidth;H=cv.clientHeight;cv.width=W*d;cv.height=H*d;g.setTransform(d,0,0,d,0,0)}life.on(window,'resize',size);size();
life.on(card,'pointermove',e=>{const r=card.getBoundingClientRect();tx=(e.clientX-r.left)/r.width-.5;ty=(e.clientY-r.top)/r.height-.5});life.on(card,'pointerleave',()=>{tx=0;ty=0});
life.observer(es=>{vis=es[0].isIntersecting;if(vis&&!scheduled){scheduled=true;life.raf(f)}}).observe(card);
const t0=performance.now();
function f(now){scheduled=false;if(!vis||document.hidden)return;const t=RM?0:(now-t0)/1000;mx+=(tx-mx)*.08;my+=(ty-my)*.08;
 const r=card.getBoundingClientRect(),p=Math.min(1,Math.max(0,1-(r.top+r.height/2)/innerHeight*1));
 const rx=RM?0:14-p*10+my*-10,ry=RM?0:-20+p*12+mx*16,rz=RM?0:4-p*4;pass.style.transform=`rotateX(${rx}deg) rotateY(${ry}deg) rotateZ(${rz}deg)`;
 const sp=RM?0:((t*.18)%1.6)-.3;sh.style.transform=`translateX(${(sp-.5)*120+mx*30}%)`;
 g.clearRect(0,0,W,H);const cx=W*(W<700?.5:.72),cy=H*(W<700?.78:.5),gap=22;
 for(let y=gap/2;y<H;y+=gap)for(let x=gap/2;x<W;x+=gap){const d=Math.hypot(x-cx,(y-cy)*1.2),w=Math.sin(d*.035-t*1.6);const a=Math.max(0,(1-d/(W*.55)))*(.08+.14*(w*.5+.5));if(a<.01)continue;g.fillStyle=`rgba(255,255,255,${a})`;const s=1+.6*(w*.5+.5);g.fillRect(x-s/2,y-s/2,s,s)}
 if(!RM){scheduled=true;life.raf(f)}}
life.on(document,'visibilitychange',()=>{if(!document.hidden&&vis&&!scheduled){scheduled=true;life.raf(f)}});
life.dispose(()=>{cv.width=cv.height=0});
return ()=>life.close();}
