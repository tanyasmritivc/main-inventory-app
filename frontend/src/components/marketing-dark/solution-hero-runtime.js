import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { extraParts } from './solution-hero-parts';

export function mountSolutionScene(host,cv,config) {
const context=cv.getContext('webgl2',{alpha:true,antialias:true})||cv.getContext('webgl',{alpha:true,antialias:true});
if(!context){host.dataset.ready='true';return ()=>{delete host.dataset.ready}};
const media=matchMedia('(prefers-reduced-motion: reduce)');
let reduce=media.matches;
const materials=new Set();
const R=new THREE.WebGLRenderer({canvas:cv,context,antialias:true,alpha:true,powerPreference:'high-performance'});
R.setPixelRatio(Math.min(1.5,devicePixelRatio||1));R.outputEncoding=THREE.sRGBEncoding;R.toneMapping=THREE.ACESFilmicToneMapping;R.toneMappingExposure=.95;
R.shadowMap.enabled=true;R.shadowMap.type=THREE.PCFSoftShadowMap;
const S=new THREE.Scene();const pm=new THREE.PMREMGenerator(R);const room=new RoomEnvironment();const environment=pm.fromScene(room,.04);S.environment=environment.texture;room.dispose();pm.dispose();
const cam=new THREE.PerspectiveCamera(30,1,.1,100);
/* light: soft key from the top left, rose rim from behind right, a little amber from the left */
S.add(new THREE.HemisphereLight(0xffffff,0x1a1014,.35));
const key=new THREE.DirectionalLight(0xfff4ec,2.2);key.position.set(-5,9,7);key.castShadow=true;key.shadow.mapSize.set(1024,1024);key.shadow.radius=6;
Object.assign(key.shadow.camera,{left:-9,right:9,top:6,bottom:-6,near:1,far:30});key.shadow.bias=-.0004;S.add(key);
const rim=new THREE.DirectionalLight(0xF08AA6,2.6);rim.position.set(7,4,-6);S.add(rim);
const rim2=new THREE.PointLight(0xE2864F,6,14,2);rim2.position.set(-7,2.5,2);S.add(rim2);
const binGlow=new THREE.PointLight(0xF27AA0,0,5,2);S.add(binGlow);
/* materials */
const M={
 steel:new THREE.MeshStandardMaterial({color:0xc8ccd3,metalness:1,roughness:.3}),
 alu:new THREE.MeshStandardMaterial({color:0xdfe2e7,metalness:1,roughness:.22}),
 black:new THREE.MeshStandardMaterial({color:0x232327,metalness:.85,roughness:.38}),
 oxide:new THREE.MeshStandardMaterial({color:0x2c2c31,metalness:.9,roughness:.42}),
 chrome:new THREE.MeshStandardMaterial({color:0xf2f3f5,metalness:1,roughness:.08}),
 rubber:new THREE.MeshStandardMaterial({color:0x3a3a3f,metalness:0,roughness:.8}),
 plastic:new THREE.MeshStandardMaterial({color:0x17171a,metalness:0,roughness:.45}),
 white:new THREE.MeshStandardMaterial({color:0xeeeeee,metalness:0,roughness:.5}),
 brass:new THREE.MeshStandardMaterial({color:0xc9a35a,metalness:1,roughness:.3})};
Object.values(M).forEach(m=>m.envMapIntensity=.5);M.chrome.envMapIntensity=.8;
const ext=(shape,depth,bevel=.02)=>{const g=new THREE.ExtrudeGeometry(shape,{depth,bevelEnabled:true,bevelThickness:bevel,bevelSize:bevel,bevelSegments:2,curveSegments:28});g.center();return g};
function gearShape(n,ro,rr,hole,round){const s=new THREE.Shape();const steps=n*4;for(let i=0;i<=steps;i++){const a=i/steps*Math.PI*2;const k=i%4;const r=round?rr+(ro-rr)*Math.max(0,Math.sin((i%4)/4*Math.PI)):(k===1||k===2?ro:rr);const x=Math.cos(a)*r,y=Math.sin(a)*r;i?s.lineTo(x,y):s.moveTo(x,y)}
 if(hole){const h=new THREE.Path();h.absarc(0,0,hole,0,Math.PI*2,true);s.holes.push(h)}return s}
function hexShape(r,hole){const s=new THREE.Shape();for(let i=0;i<=6;i++){const a=i/6*Math.PI*2+Math.PI/6;const x=Math.cos(a)*r,y=Math.sin(a)*r;i?s.lineTo(x,y):s.moveTo(x,y)}if(hole){const h=new THREE.Path();h.absarc(0,0,hole,0,Math.PI*2,true);s.holes.push(h)}return s}
const mesh=(g,m)=>{const o=new THREE.Mesh(g,m);o.castShadow=true;o.receiveShadow=true;return o};
const B={
 gear(){const s=gearShape(24,.52,.46,.1);for(let i=0;i<4;i++){const h=new THREE.Path();const a=i/4*Math.PI*2+.4;h.absarc(Math.cos(a)*.27,Math.sin(a)*.27,.075,0,Math.PI*2,true);s.holes.push(h)}return mesh(ext(s,.12),M.steel)},
 sprocket(){const s=gearShape(18,.55,.45,.12,true);for(let i=0;i<5;i++){const h=new THREE.Path();const a=i/5*Math.PI*2;h.absarc(Math.cos(a)*.28,Math.sin(a)*.28,.08,0,Math.PI*2,true);s.holes.push(h)}return mesh(ext(s,.09),M.black)},
 pulley(){const g=new THREE.Group();const band=mesh(ext(gearShape(22,.36,.33,.12),.26,.008),M.alu);g.add(band);
  [-.16,.16].forEach(z=>{const f=mesh(new THREE.CylinderGeometry(.45,.45,.04,48),M.alu);f.rotation.x=Math.PI/2;f.position.z=z;g.add(f)});
  const hub=mesh(new THREE.CylinderGeometry(.22,.22,.26,40),M.alu);hub.rotation.x=Math.PI/2;hub.position.z=.29;g.add(hub);
  const bore=mesh(ext(hexShape(.09),.62,.005),M.black);g.add(bore);return g},
 screw(){const g=new THREE.Group();const pts=[];const L=.9,r=.075,pitch=.05;pts.push(new THREE.Vector2(0,-L));for(let y=-L;y<0;y+=pitch){pts.push(new THREE.Vector2(r*.82,y),new THREE.Vector2(r,y+pitch/2))}pts.push(new THREE.Vector2(r*.85,0),new THREE.Vector2(0,0));
  const sh=mesh(new THREE.LatheGeometry(pts,24),M.oxide);g.add(sh);
  const head=mesh(new THREE.CylinderGeometry(.13,.13,.14,40),M.oxide);head.position.y=.07;g.add(head);
  const sock=mesh(ext(hexShape(.055),.02,.004),M.black);sock.rotation.x=Math.PI/2;sock.position.y=.145;g.add(sock);g.position.y=.35;const w=new THREE.Group();w.add(g);return w},
 nut(){const g=new THREE.Group();g.add(mesh(ext(hexShape(.26,.12),.16,.015),M.steel));const ny=mesh(new THREE.CylinderGeometry(.2,.2,.07,6,1,true),M.black);ny.rotation.x=Math.PI/2;ny.position.z=.11;g.add(ny);return g},
 shaft(){const m=mesh(ext(hexShape(.08),2.0,.01),M.steel);m.rotation.y=Math.PI/2;const g=new THREE.Group();g.add(m);return g},
 bearing(){const g=new THREE.Group();const ring=(ro,ri,h)=>{const pts=[new THREE.Vector2(ri,-h/2),new THREE.Vector2(ro,-h/2),new THREE.Vector2(ro,h/2),new THREE.Vector2(ri,h/2),new THREE.Vector2(ri,-h/2)];const m=mesh(new THREE.LatheGeometry(pts,56),M.chrome);m.rotation.x=Math.PI/2;return m};
  g.add(ring(.5,.42,.22));g.add(ring(.26,.16,.22));const seal=mesh(new THREE.RingGeometry(.26,.42,56),M.black);seal.position.z=.1;g.add(seal);return g},
 wheel(){const g=new THREE.Group();const hub=mesh(new THREE.CylinderGeometry(.24,.24,.32,36),M.black);hub.rotation.x=Math.PI/2;g.add(hub);
  [-.15,.15].forEach(z=>{const p=mesh(ext(gearShape(10,.5,.44,.18,true),.04,.01),M.alu);p.position.z=z;g.add(p)});
  for(let i=0;i<10;i++){const a=i/10*Math.PI*2;const r=mesh(new THREE.CapsuleGeometry(.075,.26,6,14),M.rubber);r.position.set(Math.cos(a)*.47,Math.sin(a)*.47,0);r.rotation.z=a;r.rotateX(Math.PI/4);g.add(r)}return g},
 servo(){const g=new THREE.Group();const body=mesh(new THREE.BoxGeometry(.8,.42,.4,1,1,1),M.plastic);g.add(body);
  const tab=mesh(new THREE.BoxGeometry(1.08,.06,.4),M.plastic);tab.position.y=.08;g.add(tab);
  const hornB=mesh(new THREE.CylinderGeometry(.09,.09,.08,24),M.white);hornB.position.set(-.2,.25,0);g.add(hornB);
  const arm=mesh(new THREE.BoxGeometry(.5,.04,.1),M.white);arm.position.set(-.2,.3,0);g.add(arm);return g},
 channel(){const s=new THREE.Shape();const w=.42,h=.24,t=.035;s.moveTo(-w/2,h/2);s.lineTo(-w/2,-h/2);s.lineTo(w/2,-h/2);s.lineTo(w/2,h/2);s.lineTo(w/2-t,h/2);s.lineTo(w/2-t,-h/2+t);s.lineTo(-w/2+t,-h/2+t);s.lineTo(-w/2+t,h/2);s.closePath();
  const m=mesh(ext(s,2.0,.006),M.alu);m.rotation.y=Math.PI/2;const g=new THREE.Group();g.add(m);return g}};
/* shelf and bins */
Object.assign(B,extraParts(THREE,M,mesh,ext,gearShape,hexShape,materials));
const CFG=JSON.parse(JSON.stringify(config));const BINS=CFG.bins;const HOT=CFG.hot;
const NAMES=CFG.names;
const BW=1.62,BD=1.05,BH=.62,GAP=.26,SY=-1.7;const shelf=new THREE.Group();S.add(shelf);
const binMat=new THREE.MeshPhysicalMaterial({color:0x1a1a1f,metalness:0,roughness:.3,clearcoat:1,clearcoatRoughness:.2,transparent:true,opacity:.5,envMapIntensity:.25});
const edgeMat=new THREE.LineBasicMaterial({color:0xffffff,transparent:true,opacity:.22});
const total=BINS.length*BW+(BINS.length-1)*GAP;
BINS.forEach((b,i)=>{const g=new THREE.Group();const x=-total/2+BW/2+i*(BW+GAP);g.position.set(x,SY,0);b.x=x;
 const t=.035;[[BW,t,BD,0,-BH/2,0],[BW,BH,t,0,0,BD/2],[BW,BH,t,0,0,-BD/2],[t,BH,BD,BW/2,0,0],[t,BH,BD,-BW/2,0,0]].forEach(([w,h,d,px,py,pz])=>{const m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),binMat);m.position.set(px,py,pz);m.receiveShadow=true;g.add(m)});
 const bounds=new THREE.BoxGeometry(BW,BH,BD);const edges=new THREE.EdgesGeometry(bounds);bounds.dispose();const e=new THREE.LineSegments(edges,edgeMat.clone());g.add(e);b.edge=e;b.g=g;b.k=0;shelf.add(g)});
const plank=new THREE.Mesh(new THREE.BoxGeometry(total+1.2,.12,BD+.5),new THREE.MeshStandardMaterial({color:0x121214,roughness:.6,metalness:.2}));plank.position.set(0,SY-BH/2-.07,0);plank.receiveShadow=true;shelf.add(plank);
const floor=new THREE.Mesh(new THREE.PlaneGeometry(40,20),new THREE.ShadowMaterial({opacity:.45}));floor.rotation.x=-Math.PI/2;floor.position.y=SY-BH/2-.14;floor.receiveShadow=true;S.add(floor);
/* the rose scan: a thin glowing sheet that sweeps across */
const scanMat=new THREE.MeshBasicMaterial({color:0xF58AAE,transparent:true,opacity:0,blending:THREE.AdditiveBlending,depthWrite:false,side:THREE.DoubleSide});
const scanG=new THREE.Group();const sheet=new THREE.Mesh(new THREE.PlaneGeometry(.04,6.2),scanMat);const halo=new THREE.Mesh(new THREE.PlaneGeometry(.9,6.2),new THREE.MeshBasicMaterial({color:0xF58AAE,transparent:true,opacity:0,blending:THREE.AdditiveBlending,depthWrite:false}));
sheet.position.y=.6;halo.position.set(-.45,.6,0);scanG.add(sheet,halo);scanG.rotation.y=0;S.add(scanG);
const scanLight=new THREE.PointLight(0xF58AAE,0,4,2);scanG.add(scanLight);scanLight.position.set(0,1.6,1.2);
/* parts */
const TYPES=CFG.types;const LONG=CFG.long||[];const SMALL=CFG.small||[];const UP=CFG.upright||[];
let sd=7;const rnd=()=>(sd=(sd*16807)%2147483647)/2147483647;
const P=[];const placed=[];
TYPES.forEach(t=>{const o=B[t]();const bi=BINS.findIndex(b=>b.t.includes(t));const b=BINS[bi];const slot=b.k++;
 let x,y,z,tries=0;do{x=-6+rnd()*12;y=.15+rnd()*2.1;z=-1.2+rnd()*2.4;tries++}while(tries<120&&placed.some(p=>Math.hypot(p[0]-x,(p[1]-y)*1.4)<1.45));placed.push([x,y]);
 const sc=1.22*(LONG.includes(t)?.85:SMALL.includes(t)?1.15:1)*((CFG.size||{})[t]||1);o.scale.setScalar(sc);
 const q0=new THREE.Quaternion().setFromEuler(new THREE.Euler(rnd()*6.28,rnd()*6.28,rnd()*6.28));
 const spin=new THREE.Vector3(rnd()-.5,rnd()-.5,rnd()-.5).normalize();
 // resting place inside the bin, lying down
 const bx=b.x+(-.42+(slot%3)*.42)*(BINS[bi].t.some(x=>LONG.includes(x))?0:1),bz=(-.18+Math.floor(slot/3)*.36),by=SY-BH/2+.2+(slot%2)*.05;
 const rest=new THREE.Quaternion().setFromEuler(new THREE.Euler(UP.includes(t)?Math.PI/2:(CFG.flat||[]).includes(t)?0:-Math.PI/2+.25,(slot*.7)%1.2,0));
 P.push({t,o,bi,home:new THREE.Vector3(x,y,z),bin:new THREE.Vector3(bx,by+(LONG.includes(t)?slot*.12:0),bz),q0,spin,rest,sc,d:rnd()*.5,ph:rnd()*6.28,lab:null});S.add(o)});
/* HTML overlays: part names during the scan, bin names and counts, question and answer */
const ov=host.querySelector('[data-overlays]');
P.forEach(p=>{const e=document.createElement('span');e.className='sh-name';e.textContent=NAMES[p.t];ov.appendChild(e);p.lab=e});
BINS.forEach(b=>{const e=document.createElement('span');e.className='sh-bin';e.innerHTML=`<b>${b.n}</b><i>00</i>`;ov.appendChild(e);b.lab=e;b.cnt=P.filter(p=>p.bi===BINS.indexOf(b)).length});
const q=host.querySelector('[data-question]'),qt=host.querySelector('[data-question-text]'),ans=host.querySelector('[data-answer]');const QTXT=CFG.q;ans.textContent=CFG.ans;
const cl=(x,a=0,b=1)=>Math.min(b,Math.max(a,x)),pr=(t,s,d)=>cl((t-s)/d);const ioC=x=>x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2,oE=x=>x>=1?1:1-Math.pow(2,-10*x);
let W=1,H=1,NARROW=false,XS=1,YS=1,LY=.3;const v=new THREE.Vector3();
function toScreen(p){v.copy(p).project(cam);return [(v.x+1)/2*W,(1-v.y)/2*H]}
function size(){const r=host.getBoundingClientRect();W=Math.max(1,r.width);H=Math.max(1,r.height);R.setSize(W,H,false);cam.aspect=W/H;
 // keep the whole shelf in view on any width
 NARROW=W<600;XS=NARROW?.8:1;YS=NARROW?2.1:1;LY=NARROW?1.0:.3;const need=total+(NARROW?.3:1.6);const fovH=2*Math.atan(Math.tan(cam.fov*Math.PI/360)*cam.aspect);const dist=Math.max(13,(need/2)/Math.tan(fovH/2)+2.2);
 cam.position.set(0,1.25,dist);cam.lookAt(0,LY,0);cam.updateProjectionMatrix()}
let mx=0,my=0;const pointer=e=>{if(e.pointerType!=='touch'){mx=e.clientX/innerWidth-.5;my=e.clientY/innerHeight-.5}};
const qa=new THREE.Quaternion(),qb=new THREE.Quaternion();
function frame(t){
 const scan=pr(t,1.4,2.2),file=t<8.6?pr(t,3.7,1.6):1-pr(t,10.1,1.6),hit=t>=6.6&&t<10.1;
 const sx=-8+scan*16;scanG.position.x=sx;const sOn=scan>0&&scan<1?Math.sin(scan*Math.PI):0;scanMat.opacity=.85*sOn;halo.material.opacity=.12*sOn;scanLight.intensity=8*sOn;
 P.forEach((p,i)=>{const k=ioC(cl(file*1.35-p.d*.35));
  const fx=p.home.x*XS+Math.sin(t*.5+p.ph)*.12,fy=(p.home.y+.2)*YS-.2+Math.cos(t*.45+p.ph)*.14,fz=p.home.z;
  p.o.position.set(fx+(p.bin.x-fx)*k,fy+(p.bin.y-fy)*k+Math.sin(k*Math.PI)*1.1,fz+(p.bin.z-fz)*k);
  qa.setFromAxisAngle(p.spin,(reduce?0:t*.35)+p.ph).premultiply(p.q0);p.o.quaternion.slerpQuaternions(qa,p.rest,k);p.o.scale.setScalar(p.sc*(1-.5*k));
  // name tag while the scan passes, before filing
  const seen=sx>fx-.2&&t<4.3&&k<.02;const a=seen?cl((sx-fx)/1.2)*(1-pr(t,3.8,.5)):0;const [x,y]=toScreen(p.o.position);
  p.lab.style.opacity=a.toFixed(3);p.lab.style.transform=`translate(${x}px,${y-46}px) translate(-50%,0)`});
 BINS.forEach((b,i)=>{const hot=hit&&i===HOT;const pulse=hot?(.6+.4*Math.sin(t*5)):0;b.edge.material.opacity=hot?.75+.25*pulse:.22;b.edge.material.color.set(hot?0xF58AAE:0xffffff);
  const [x,y]=toScreen(new THREE.Vector3(b.x,SY-BH/2-.2,BD/2));b.lab.style.transform=`translate(${x}px,${y+8}px) translate(-50%,0)`;b.lab.classList.toggle('hot',hot);
  b.lab.querySelector('i').textContent=String(Math.round(b.cnt*cl((file-.35)/.65))).padStart(2,'0')});
 binGlow.position.set(BINS[HOT].x,SY+.9,.6);binGlow.intensity=hit?22*(.7+.3*Math.sin(t*5)):0;
 const typed=Math.round(QTXT.length*cl((t-5.6)/1));qt.textContent=QTXT.slice(0,typed)||'​';q.classList.toggle('on',t>5.5&&t<10.1);
 const [ax,ay]=toScreen(new THREE.Vector3(BINS[HOT].x,SY+BH/2+.5,0));const aw=ans.offsetWidth||140;const axc=Math.min(W-aw/2-12,Math.max(aw/2+12,ax));ans.style.transform=`translate(${axc}px,${ay-30}px) translate(-50%,0)`;ans.classList.toggle('on',hit&&t>6.9);
 // gentle parallax
 if(!reduce){cam.position.x+=((mx*1.2)-cam.position.x)*.05;cam.lookAt(0,LY-my*.3,0)}
 R.render(S,cam)}

let visible=false,disposed=false,presented=false,raf=0,last=0,elapsed=0;
function tick(now){
 raf=0;if(disposed||!visible||document.hidden)return;
 if(last)elapsed+=Math.min(now-last,100);last=now;
 frame(reduce?9.6:(elapsed/1000)%12);
 if(!presented){presented=true;host.dataset.ready='true'}
 if(!reduce)raf=requestAnimationFrame(tick);
}
function resume(){cancelAnimationFrame(raf);raf=0;last=0;if(!disposed&&visible&&!document.hidden)raf=requestAnimationFrame(tick)}
function resize(){size();resume()}
function motion(){reduce=media.matches;resume()}
const observer=new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;resume()});
const resizeObserver=new ResizeObserver(resize);
size();observer.observe(host);resizeObserver.observe(host);
window.addEventListener('pointermove',pointer,{passive:true});
window.addEventListener('resize',resize);
document.addEventListener('visibilitychange',resume);
media.addEventListener('change',motion);
return ()=>{
 disposed=true;cancelAnimationFrame(raf);observer.disconnect();resizeObserver.disconnect();
 delete host.dataset.ready;
 window.removeEventListener('pointermove',pointer);window.removeEventListener('resize',resize);
 document.removeEventListener('visibilitychange',resume);media.removeEventListener('change',motion);
 const geometries=new Set(),textures=new Set();Object.values(M).forEach(m=>materials.add(m));materials.add(edgeMat);materials.add(binMat);
 S.traverse(o=>{if(o.geometry)geometries.add(o.geometry);if(o.material)(Array.isArray(o.material)?o.material:[o.material]).forEach(m=>materials.add(m));if(o.shadow)o.shadow.dispose()});
 materials.forEach(m=>{Object.values(m).forEach(v=>{if(v?.isTexture)textures.add(v)});m.dispose()});
 geometries.forEach(g=>g.dispose());textures.forEach(t=>t.dispose());environment.dispose();
 R.renderLists.dispose();R.dispose();R.forceContextLoss();ov.replaceChildren();
};
}
