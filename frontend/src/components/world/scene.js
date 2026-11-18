import { storageGroups } from './storage-groups';
// Model makers, room textures, sample scenes and pixel shader ported from the supplied prototype.
// Only this module imports the World renderer version; existing 3D pages retain theirs.
import * as THREE from 'three-world';
import { OrbitControls } from 'three-world/addons/controls/OrbitControls.js';
import * as BGU from 'three-world/addons/utils/BufferGeometryUtils.js';

export function createWorldScene(root, callbacks) {
  const listeners = [];
  const listen = (target, event, handler, options) => {
    target.addEventListener(event, handler, options);
    listeners.push(() => target.removeEventListener(event, handler, options));
  };
  let disposed = false, dirty = true;
// ---------- helpers ----------
const $=id=>root.querySelector(`[data-world-id="${id}"]`);
const cl=(x,a=0,b=1)=>Math.max(a,Math.min(b,x)), eo=x=>1-Math.pow(1-cl(x),3), eio=x=>{x=cl(x);return x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2};
const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
let seed=7;const rnd=()=>{seed=(seed*16807)%2147483647;return seed/2147483647};const pick=a=>a[Math.floor(rnd()*a.length)];
// pixel art palette
const C={clay:'#ece7de',clay2:'#cfc9c0',ink:'#2b2f42',wood:'#d9a35e',wood2:'#a8703f',metal:'#a7afc2',steel:'#858ea4',red:'#d8574b',blue:'#4d8fd6',green:'#62b04c',yellow:'#f2c14e',brass:'#e3a93c',dark:'#4a5066',white:'#f5f3ef',lemon:'#f6dc4c',glass:'#a8d8ef',pink:'#f2a5a0',
 leaf:'#56a53f',leaf2:'#82c957',leaf3:'#3d8233',frame:'#535a72',frame2:'#6b7390',pot:'#c9714a',card:'#d4a668',tube:'#f2fbff',paper:'#f3efe6',orange:'#ec8a3a',purple:'#9a7fd1'};
// three light steps, like hand shaded pixel art
const GRAD=(()=>{const t=new THREE.DataTexture(new Uint8Array([110,178,255]),3,1,THREE.RedFormat);t.minFilter=t.magFilter=THREE.NearestFilter;t.generateMipmaps=false;t.needsUpdate=true;return t})();
const mats={};const M=c=>mats[c]||(mats[c]=new THREE.MeshToonMaterial({color:c,gradientMap:GRAD}));
const basics={};const MB=c=>basics[c]||(basics[c]=new THREE.MeshBasicMaterial({color:c}));
function mesh(g,c){const m=new THREE.Mesh(g,typeof c==='string'?M(c):c);m.castShadow=true;m.receiveShadow=true;return m}
const BXC=new Map();function bx(w,h,d){const k=w.toFixed(3)+'|'+h.toFixed(3)+'|'+d.toFixed(3);let g=BXC.get(k);if(!g){g=new THREE.BoxGeometry(w,h,d);BXC.set(k,g)}return g}
function B(w,h,d,c=C.clay,x=0,y=0,z=0){const m=mesh(bx(w,h,d),c);m.position.set(x,y+h/2,z);return m}
function Cy(r,h,c=C.clay,x=0,y=0,z=0,seg=12,r2){const m=mesh(new THREE.CylinderGeometry(r,r2??r,h,seg),c);m.position.set(x,y+h/2,z);return m}
function To(R,t,c,x=0,y=0,z=0,arc=Math.PI*2){const m=mesh(new THREE.TorusGeometry(R,t,6,16,arc),c);m.position.set(x,y,z);return m}
function S(r,c,x=0,y=0,z=0){const m=mesh(new THREE.SphereGeometry(r,12,8),c);m.position.set(x,y,z);return m}
const ICO=new THREE.IcosahedronGeometry(1,0);
function L(r,c,x=0,y=0,z=0){const m=mesh(ICO,c);m.scale.setScalar(r);m.position.set(x,y,z);m.rotation.set(rnd()*3,rnd()*3,rnd()*3);return m}
function G(...ch){const g=new THREE.Group();ch.forEach(c=>c&&g.add(c));return g}
function at(o,x=0,y=0,z=0,ry=0){o.position.set(x,y,z);o.rotation.y=ry;return o}
function leafy(r,x=0,y=0,z=0){return G(L(r,C.leaf,x,y,z),L(r*.75,C.leaf2,x+r*.55,y+r*.25,z+r*.2),L(r*.7,C.leaf3,x-r*.5,y+r*.15,z-r*.35),L(r*.6,C.leaf2,x-r*.1,y+r*.6,z+r*.4))}
function vine(n){const g=G();let x=0,z=0;for(let i=0;i<n;i++){x+=(rnd()-.5)*.07;z+=(rnd()-.5)*.07;g.add(L(.065+rnd()*.045,pick([C.leaf,C.leaf2,C.leaf3]),x,-i*.12,z))}return g}

// ---------- object makers ----------
const mk={
 table:(w=4,d=2,h=1.5,c=C.wood)=>G(B(w,.16,d,c,0,h-.16,0),...[[-1,-1],[1,-1],[-1,1],[1,1]].map(([a,b])=>B(.16,h-.16,.16,c,a*(w/2-.2),0,b*(d/2-.2)))),
 shelf:(w=3,h=3.2,d=1,n=4,c=C.metal)=>{const g=G(B(.1,h,d,c,-w/2,0,0),B(.1,h,d,c,w/2,0,0));for(let i=0;i<n;i++)g.add(B(w,.08,d,c,0,.15+i*(h-.3)/(n-1),0));return g},
 bin:(w=.9,d=.7,h=.45,c=C.blue)=>G(B(w,.05,d,c),B(w,h,.05,c,0,0,d/2),B(w,h,.05,c,0,0,-d/2),B(.05,h,d,c,w/2,0,0),B(.05,h,d,c,-w/2,0,0)),
 drawers:(cols=4,rows=5,c=C.clay)=>{const W=cols*.42+.1,H=rows*.3+.1;const g=G(B(W,H,.7,C.clay2));for(let i=0;i<cols;i++)for(let j=0;j<rows;j++){g.add(B(.36,.24,.06,c,-W/2+.26+i*.42,.08+j*.3,.37));g.add(B(.12,.03,.04,C.ink,-W/2+.26+i*.42,.18+j*.3,.41))}return g},
 screws:()=>{const g=mk.bin(.8,.6,.22,C.white);for(let i=0;i<26;i++){const s=Cy(.025,.16,C.steel,(rnd()-.5)*.6,.06,(rnd()-.5)*.4,8);s.rotation.z=Math.PI/2;s.rotation.y=rnd()*3;g.add(s);g.add(Cy(.045,.04,C.steel,s.position.x+.08,.09,s.position.z,8))}return g},
 robot:()=>{const g=G(B(1.6,.3,1.2,C.dark,0,.35,0),B(1.42,.06,1.02,'#2f7a4a',0,.65,0));[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>{const w=Cy(.32,.24,'#2b2f42',0,0,0,16);w.rotation.x=Math.PI/2;w.position.set(a*.72,.32,b*.66);g.add(w);const h=Cy(.13,.26,C.yellow,0,0,0,10);h.rotation.x=Math.PI/2;h.position.set(a*.72,.32,b*.67);g.add(h)});g.add(B(.42,.22,.32,C.yellow,-.4,.71,.22),B(.3,.12,.26,C.ink,-.35,.71,-.25),B(.12,.04,.12,C.red,.05,.71,-.3),B(.08,.62,.08,C.steel,.45,.71,0),B(.46,.32,.5,'#eef1f6',.45,1.33,0));[-.12,.12].forEach(z=>{const e=Cy(.075,.04,C.ink,0,0,0,10);e.rotation.z=Math.PI/2;e.position.set(.69,1.52,z);g.add(e);const sh=S(.022,'#ffffff',.715,1.55,z-.02);g.add(sh);g.add(B(.02,.05,.08,C.pink,.69,1.4,z*1.55))});g.add(B(.02,.025,.1,C.ink,.69,1.43,0),Cy(.02,.25,C.ink,.45,1.65,0,6),S(.05,C.red,.45,1.92,0));return g},
 servo:()=>G(B(.32,.22,.18,C.dark),Cy(.06,.05,C.white,.08,.22,0,12)),
 battery:(c=C.yellow)=>G(B(.6,.35,.35,c),Cy(.04,.06,C.red,-.15,.35,0,8),Cy(.04,.06,C.ink,.15,.35,0,8)),
 laptop:()=>{const s=B(1.1,.7,.04,C.dark);s.position.set(0,.38,-.38);s.rotation.x=-.25;return G(B(1.1,.05,.8,C.metal),s)},
 spool:(c=C.red)=>G(Cy(.3,.04,C.clay2,0,0,0),Cy(.2,.32,c,0,.04,0),Cy(.3,.04,C.clay2,0,.36,0)),
 gears:()=>{const g=G();[[0,0,.28],[.5,.1,.2],[.2,.45,.16]].forEach(([x,z,r])=>{g.add(Cy(r,.06,C.brass,x,0,z,20));for(let k=0;k<10;k++){const t=B(.07,.06,.07,C.brass);const a=k/10*6.283;t.position.set(x+Math.cos(a)*(r+.02),.03,z+Math.sin(a)*(r+.02));t.rotation.y=-a;g.add(t)}});return g},
 toolbox:(c=C.red)=>{const h=To(.22,.04,C.ink,0,.62,0,Math.PI);return G(B(1.1,.55,.5,c),B(1.12,.05,.52,C.ink,0,.55,0),h)},
 bike:()=>{const g=G();[-.8,.8].forEach(x=>{const w=To(.55,.06,C.ink,x,.6,0);g.add(w)});const f1=B(1.3,.07,.07,C.blue,0,.95,0);g.add(f1);const f2=B(.07,.7,.07,C.blue,-.3,.55,0);f2.rotation.z=.4;g.add(f2);const f3=B(.07,.7,.07,C.blue,.35,.55,0);f3.rotation.z=-.5;g.add(f3);g.add(B(.3,.06,.12,C.ink,-.35,1.2,0));g.add(B(.06,.06,.6,C.ink,.75,1.3,0));return g},
 tires:()=>{const g=G();for(let i=0;i<3;i++){const t=To(.5,.2,C.dark,0,.2+i*.38,0);t.rotation.x=Math.PI/2;g.add(t)}return g},
 coil:(c=C.yellow)=>{const g=G();for(let i=0;i<3;i++){const t=To(.35-i*.03,.04,c,0,.05+i*.06,0);t.rotation.x=Math.PI/2;g.add(t)}g.add(B(.25,.12,.18,C.dark,.45,0,0));return g},
 cans:()=>G(Cy(.25,.45,C.white,0),Cy(.25,.45,C.green,.55,0,.1),Cy(.25,.45,C.blue,.25,.45,.05),Cy(.2,.35,C.red,-.5,0,.15)),
 ladder:()=>{const g=G(B(.08,3,.08,C.metal,-.35,0,0),B(.08,3,.08,C.metal,.35,0,0));for(let i=0;i<6;i++)g.add(B(.7,.06,.06,C.metal,0,.4+i*.45,0));g.rotation.x=-.25;return g},
 tape:()=>{const t=Cy(.16,.12,C.yellow,0,0,0,20);t.rotation.x=Math.PI/2;t.position.y=.16;return G(t,B(.05,.08,.12,C.dark,.15,.02,0))},
 fridge:()=>{const g=G(B(1.6,3.4,1.4,C.white,0,0,0));const inner=B(1.4,3.1,1.2,C.glass,0,.15,.12);g.add(inner);for(let i=0;i<3;i++)g.add(B(1.4,.05,1.1,C.white,0,1.0+i*.75,.15));const door=B(.08,3.3,1.5,C.white);door.position.set(.9,.05+1.65,1.2);door.rotation.y=-1.0;g.add(door);g.add(Cy(.18,.6,C.white,-.35,1.8,.3,16));
   g.add(S(.18,C.lemon,.4,2.7,.2));return g},
 counter:()=>{const g=G(B(4,1.6,1.2,C.clay2),B(4.1,.12,1.3,C.wood,0,1.6,0));for(let i=0;i<4;i++){g.add(B(.92,1.2,.05,C.clay,-1.5+i*1,.15,.61))}const dr=B(.92,.3,.9,C.clay,1.5,1.25,.75);g.add(dr);return g},
 junk:()=>{const g=G(B(.9,.06,.8,C.clay2));for(let i=0;i<5;i++){const b=Cy(.05,.3,i%2?C.yellow:C.ink,-.3+i*.12,.06,-.1,10);b.rotation.z=Math.PI/2;g.add(b)}g.add(B(.18,.24,.1,C.blue,.28,.06,.18));g.add(B(.3,.04,.12,C.red,-.1,.06,.25));return g},
 spices:()=>{const g=G(B(1.6,.06,.4,C.wood),B(1.6,.06,.4,C.wood,0,.5,0),B(1.6,1,.05,C.wood,0,0,-.2));const cs=[C.red,C.yellow,C.green,C.wood2,C.dark,C.white,C.red];for(let r=0;r<2;r++)for(let i=0;i<7;i++)g.add(Cy(.08,.3,cs[(i+r)%7],-.66+i*.22,.06+r*.5,.02,12));return g},
 fruit:()=>{const g=G(Cy(.45,.25,C.white,0,0,0,24,.25));[[0,.1],[.18,-.05],[-.18,0],[.05,-.18],[-.05,.18]].forEach(([x,z])=>g.add(S(.15,C.lemon,x,.35,z)));return g},
 mugs:()=>{const g=G();[[0,0,C.white],[.4,.1,C.blue],[.15,.42,C.red]].forEach(([x,z,c])=>{g.add(Cy(.15,.3,c,x,0,z,16));const h=To(.09,.03,c,x+.16,.15,z,Math.PI);h.rotation.z=-Math.PI/2;g.add(h)});return g},
 toaster:()=>G(B(.7,.45,.4,C.metal),B(.5,.03,.08,C.ink,0,.45,-.08),B(.5,.03,.08,C.ink,0,.45,.08)),
 desk:()=>{const g=mk.table(3.6,1.6,1.5,C.wood);g.add(B(.9,1.1,1.4,C.clay2,1.2,0,0));return g},
 monitor:()=>G(B(.4,.05,.3,C.dark),B(.08,.5,.08,C.dark,0,0,0),B(1.5,.85,.06,C.ink,0,.5,0)),
 keyboard:()=>G(B(1,.05,.32,C.white)),
 cables:()=>{const g=G();[[C.white,0,0],[C.ink,.25,.15],[C.blue,-.2,.2],[C.white,.1,-.2]].forEach(([c,x,z])=>{const t=To(.18,.025,c,x,.03,z);t.rotation.x=Math.PI/2;g.add(t)});g.add(B(.14,.1,.14,C.white,.4,0,-.1));return g},
 headphones:()=>{const g=G();const b=To(.28,.04,C.dark,0,.28,0,Math.PI);g.add(b);const l=Cy(.1,.08,C.dark,-.28,.2,0,16);l.rotation.z=Math.PI/2;g.add(l);const r=l.clone();r.position.x=.28;g.add(r);g.rotation.x=-1.2;return g},
 lamp:()=>{const a=B(.06,.9,.06,C.ink);a.position.set(0,.5,0);a.rotation.z=.4;const s=Cy(.12,.22,C.yellow,0,0,0,16,.25);s.position.set(-.32,1.05,0);s.rotation.z=-.9;return G(Cy(.22,.06,C.ink),a,s)},
 plant:()=>potPlant(1.05),
 books:()=>{const g=G();const cs=[C.red,C.blue,C.white,C.green,C.yellow,C.dark];for(let i=0;i<6;i++){const b=B(.9-(i%3)*.08,.12,.65,cs[i],0,i*.12,0);b.rotation.y=(rnd()-.5)*.3;g.add(b)}return g},
 pens:()=>{const g=G(Cy(.14,.3,C.dark,0,0,0,16));[[C.red,.04,.02],[C.blue,-.04,.03],[C.yellow,0,-.05],[C.ink,.05,-.03]].forEach(([c,x,z])=>{const p=Cy(.018,.45,c,x,.12,z,6);p.rotation.z=(x)*3;g.add(p)});return g},
 earbuds:()=>{const c=Cy(.13,.09,C.white,0,0,0,20);c.scale.set(1,1,.7);return G(c,B(.12,.012,.02,C.steel,0,.09,.08))},
 pegboard:()=>{const g=G(B(3.4,2.2,.08,C.wood));for(let i=0;i<4;i++){g.add(B(.08,.7,.06,C.steel,-1.2+i*.22,.8,.08))}g.add(B(.08,.6,.06,C.wood2,.1,.9,.08));g.add(B(.3,.12,.1,C.dark,.1,1.48,.08));g.add(B(.08,.55,.06,C.red,.55,.9,.08));g.add(B(.08,.55,.06,C.yellow,.75,.9,.08));const s=To(.2,.03,C.dark,1.3,1.25,.08);g.add(s);return g},
 drill:()=>{const g=G(B(.6,.25,.2,C.yellow,0,.55,0),B(.2,.5,.18,C.dark,-.1,.1,0),B(.32,.14,.24,C.dark,-.1,0,0));const ch=Cy(.06,.2,C.steel,0,0,0,10);ch.rotation.z=Math.PI/2;ch.position.set(.4,.67,0);g.add(ch);return g},
 lumber:()=>{const g=G();for(let i=0;i<3;i++)for(let j=0;j<3-i;j++)g.add(B(3,.18,.36,C.wood,0,i*.18,-.4+j*.4+i*.2));return g},
 clamps:()=>{const g=G();for(let i=0;i<3;i++){const x=-.4+i*.4;g.add(B(.06,.6,.06,C.red,x,0,0),B(.25,.06,.06,C.red,x+.1,.54,0),B(.25,.06,.06,C.red,x+.1,.06,0),Cy(.02,.3,C.steel,x+.2,.12,0,6))}return g},
 sawhorse:()=>{const g=G(B(2,.12,.2,C.wood,0,1.1,0));[[-.8,1],[-.8,-1],[.8,1],[.8,-1]].forEach(([x,s])=>{const l=B(.1,1.15,.1,C.wood,x,0,s*.15);l.rotation.x=s*.25;g.add(l)});return g},
 nails:()=>G(Cy(.2,.4,C.glass,0,0,0,16),Cy(.21,.06,C.dark,0,.4,0,16),Cy(.15,.22,C.steel,0,.02,0,12)),
 hexkeys:()=>{const g=G();for(let i=0;i<7;i++){const k=B(.03,.03,.32-i*.02,C.dark,-.12+i*.04,0,0);g.add(k);g.add(B(.03,.1,.03,C.dark,-.12+i*.04,0,.15-i*.01))}return g},
 box:(c=C.wood)=>G(B(.9,.7,.7,c),B(.92,.02,.05,C.wood2,0,.7,0)),
 workbench:()=>{const g=mk.table(4.2,1.8,1.6,C.wood);g.add(B(3.8,.08,1.5,C.wood2,0,.4,0));return g},
 window:()=>G(B(2,1.6,.08,C.glass),B(2.1,.1,.12,C.white,0,1.6,0),B(2.1,.1,.12,C.white,0,-.05,0),B(.08,1.6,.1,C.white,0,0,0)),
};

// ---------- spaces ----------
const SP=[
 {id:'lab',label:'Robotics lab',style:{floor:'tiles',fc:'#d3d6e0',fc2:'#a9aebd',wall:'#b6bccd',cap:'#d6dae6',blocks:1,trim:'#6c728a'},items:[
  {k:'workbench',p:[0,1.8],r:0,n:'Workbench',c:1,place:'Lab · Center',decor:true},
  {k:'drawers',p:[-3.4,-4.6],r:0,n:'Small parts drawers',c:20,u:'drawers',place:'Lab · Back wall',args:[5,6]},
  {k:'screws',p:[-1.2,1.6],r:.2,y:1.6,n:'M3 socket screws',c:64,place:'Lab · Workbench · Tray',ch:'the M3 screws'},
  {k:'robot',p:[2.4,-1.4],r:-.6,n:'Robot chassis',c:1,place:'Lab · Floor · Build area'},
  {k:'servo',p:[1.2,1.5],r:.4,y:1.6,n:'Servo motors',c:6,place:'Lab · Workbench'},
  {k:'battery',p:[-3.4,1.2],r:.3,n:'12V batteries',c:3,place:'Lab · Floor · Charging corner'},
  {k:'laptop',p:[.1,2.2],r:0,y:1.6,n:'Laptop',c:1,place:'Lab · Workbench'},
  {k:'spool',p:[1.9,1.9],r:0,y:1.6,n:'Wire spool',c:2,place:'Lab · Workbench'},
  {k:'gears',p:[-.6,-1.6],r:0,n:'Gears',c:18,place:'Lab · Floor · Gear tray',short:true},
 ]},
 {id:'garage',label:'Garage',style:{floor:'concrete',fc:'#b4b7bf',fc2:'#9fa3ad',wall:'#a5abbd',cap:'#c9cedb',blocks:1,trim:'#5b6277'},items:[
  {k:'shelf',p:[-2.8,-4.55],r:0,n:'Metal shelf',c:1,place:'Garage · Back wall',decor:true},
  {k:'bin',p:[-2.8,-4.55],r:0,y:.23,n:'Storage bins',c:9,place:'Garage · Back wall · Shelf',stack:true},
  {k:'toolbox',p:[1.4,-4.6],y:1.4,r:0,n:'Toolbox',c:1,place:'Garage · Back wall'},
  {k:'bike',p:[2.6,1.4],r:.8,n:'Bike',c:1,place:'Garage · Right side'},
  {k:'tires',p:[-3.6,1.6],r:0,n:'Winter tires',c:4,place:'Garage · Left corner'},
  {k:'coil',p:[-.4,.4],r:0,n:'Extension cord',c:2,place:'Garage · Floor'},
  {k:'cans',p:[.6,-2.2],r:0,n:'Paint cans',c:5,place:'Garage · Back wall · Floor'},
  {k:'ladder',p:[4.1,-3.4],r:-1.57,n:'Ladder',c:1,place:'Garage · Right wall'},
  {k:'tape',p:[-1.6,-1.2],r:.6,n:'Tape measure',c:1,place:'Garage · Floor',ch:'the tape measure'},
 ]},
 {id:'kitchen',label:'Kitchen',style:{floor:'checker',fc:'#efe6d4',fc2:'#a9c3a6',wall:'#e7d7bf',cap:'#f6ecdc',trim:'#c2a988'},items:[
  {k:'fridge',p:[-3.4,-3.3],r:.15,n:'Fridge',c:1,place:'Kitchen · Left wall',decor:true},
  {k:'ketchup',virtual:true,p:[-3.15,-2.95],y:1.95,n:'Ketchup',c:1,place:'Kitchen · Fridge · Middle shelf · lying on its side',ch:'the ketchup'},
  {k:'counter',p:[1,-3.8],r:0,n:'Counter',c:1,place:'Kitchen · Back wall',decor:true},
  {k:'junk',p:[2.5,-2.9],y:1.33,r:0,n:'Junk drawer',c:1,place:'Kitchen · Counter · Right drawer',sub:'AA batteries ×4, 9V battery ×1, tape'},
  {k:'nine',virtual:true,p:[2.78,-2.72],y:1.4,n:'9V battery',c:1,place:'Kitchen · Counter · Junk drawer',ch:'the 9V battery'},
  {k:'spices',p:[-.6,-4.3],y:2.4,r:0,n:'Spices',c:14,place:'Kitchen · Back wall · Rack'},
  {k:'fruit',p:[.4,-3.7],y:1.72,r:0,n:'Lemons',c:5,place:'Kitchen · Counter'},
  {k:'mugs',p:[1.6,-3.8],y:1.72,r:0,n:'Mugs',c:6,place:'Kitchen · Counter',short:true},
  {k:'toaster',p:[-.6,-3.7],y:1.72,r:.1,n:'Toaster',c:1,place:'Kitchen · Counter'},
  {k:'table',p:[1.2,1],r:0,n:'Kitchen table',c:1,place:'Kitchen · Center',args:[3,2,1.5,C.wood],decor:true},
 ]},
 {id:'desk',label:'Desk',style:{floor:'planks',fc:'#c58d5a',fc2:'#9f6a3c',wall:'#d8bdb3',cap:'#eddcd4',trim:'#a98377'},items:[
  {k:'desk',p:[0,-3.2],r:0,n:'Desk',c:1,place:'Desk · Back wall',decor:true},
  {k:'monitor',p:[-.4,-3.5],y:1.5,r:0,n:'Monitor',c:1,place:'Desk · Desktop'},
  {k:'keyboard',p:[-.4,-2.8],y:1.5,r:0,n:'Keyboard',c:1,place:'Desk · Desktop'},
  {k:'cables',p:[1.1,-2.9],y:1.5,r:0,n:'USB-C cables',c:4,place:'Desk · Desktop · Right side'},
  {k:'earbuds',p:[.7,-2.55],y:1.5,r:.5,n:'Earbuds case',c:1,place:'Desk · Desktop · under the cables',ch:'the earbuds'},
  {k:'headphones',p:[-1.5,-2.8],y:1.62,r:.3,n:'Headphones',c:1,place:'Desk · Desktop'},
  {k:'lamp',p:[-1.6,-3.6],y:1.5,r:.6,n:'Desk lamp',c:1,place:'Desk · Desktop'},
  {k:'plant',p:[3.4,-3.4],r:0,n:'Plant',c:1,place:'Desk · Corner'},
  {k:'books',p:[-3,0],r:.2,n:'Textbooks',c:6,place:'Desk · Floor · Left'},
  {k:'pens',p:[.4,-3.6],y:1.5,r:0,n:'Pens',c:12,place:'Desk · Desktop · Cup'},
 ]},
 {id:'workshop',label:'Workshop',style:{floor:'planks',fc:'#d7aa72',fc2:'#b4834b',wall:'#b5c7a5',cap:'#d3e0c6',blocks:1,trim:'#7c9070'},items:[
  {k:'pegboard',p:[0,-4.45],y:1.3,r:0,n:'Pegboard tools',c:9,place:'Workshop · Back wall'},
  {k:'workbench',p:[0,-3.1],r:0,n:'Workbench',c:1,place:'Workshop · Back wall',decor:true},
  {k:'drill',p:[-1,-3.1],y:1.6,r:.4,n:'Cordless drill',c:1,place:'Workshop · Workbench'},
  {k:'hexkeys',p:[1.1,-2.8],y:1.6,r:.3,n:'Hex key set',c:7,place:'Workshop · Workbench · Front',ch:'the hex keys'},
  {k:'nails',p:[1.7,-3.4],y:1.6,r:0,n:'Nails',c:300,place:'Workshop · Workbench · Jar'},
  {k:'lumber',p:[-1.4,1.8],r:0,n:'2×4 boards',c:6,place:'Workshop · Floor'},
  {k:'clamps',p:[2.8,.6],r:-.4,n:'Clamps',c:3,place:'Workshop · Floor',short:true},
  {k:'sawhorse',p:[2,2.6],r:.2,n:'Sawhorse',c:1,place:'Workshop · Floor'},
  {k:'box',p:[-3.6,-1],r:.3,n:'Offcut box',c:1,place:'Workshop · Left wall'},
 ]},
];
const BUILD_IDX=0;const GAP=60;
const spaceCenter=i=>new THREE.Vector3(i*GAP,0,0);

// ---------- renderer: low-res pixel buffer, stepped light, ink outlines ----------
const stage=root.querySelector('[data-world-stage]');
const R=new THREE.WebGLRenderer({antialias:false,alpha:true,powerPreference:'high-performance'});R.setPixelRatio(1);R.shadowMap.enabled=true;R.shadowMap.type=THREE.BasicShadowMap;R.shadowMap.autoUpdate=false;R.outputColorSpace=THREE.SRGBColorSpace;R.setClearColor(0x000000,0);
stage.appendChild(R.domElement);
const scene=new THREE.Scene();
const VIEW_H=16;const cam=new THREE.OrthographicCamera(-8,8,8,-8,1,140);
scene.add(new THREE.HemisphereLight('#f4f7ff','#8d92a2',1.75));
const sun=new THREE.DirectionalLight('#fff4e2',1.9);sun.castShadow=true;sun.shadow.mapSize.set(4096,4096);sun.shadow.bias=-.0005;sun.shadow.normalBias=.03;
Object.assign(sun.shadow.camera,{left:-9,right:9,top:9,bottom:-9,near:1,far:70});scene.add(sun);scene.add(sun.target);

// ---------- pixel textures ----------
let fseed=11;const fr=()=>{fseed=(fseed*16807)%2147483647;return fseed/2147483647};
function tex(w,h,draw,rx=1,ry=rx,near=false){const cv=document.createElement('canvas');cv.width=w;cv.height=h;const g=cv.getContext('2d');draw(g,w,h);const t=new THREE.CanvasTexture(cv);t.colorSpace=THREE.SRGBColorSpace;if(near){t.magFilter=THREE.NearestFilter;t.minFilter=THREE.NearestMipmapNearestFilter}else{t.magFilter=THREE.LinearFilter;t.minFilter=THREE.LinearMipmapLinearFilter;t.anisotropy=8}t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(rx,ry);return t}
function shade(hex,f){const c=new THREE.Color(hex);c.offsetHSL(0,0,f);return '#'+c.getHexString()}
function floorTex(kind,a,b){const lt=shade(a,.06),dk=shade(a,-.07);
 const bevel=(g,x,y,s,c)=>{g.fillStyle=shade(c,.06);g.fillRect(x+3,y+3,s-6,4);g.fillRect(x+3,y+3,4,s-6);g.fillStyle=shade(c,-.07);g.fillRect(x+3,y+s-7,s-6,4);g.fillRect(x+s-7,y+3,4,s-6)};
 if(kind==='tiles')return tex(256,256,g=>{g.fillStyle=a;g.fillRect(0,0,256,256);for(const [x,y] of [[0,0],[128,0],[0,128],[128,128]])bevel(g,x,y,128,a);g.fillStyle=b;for(const v of [0,128]){g.fillRect(v,0,3,256);g.fillRect(0,v,256,3)}},4);
 if(kind==='checker')return tex(256,256,g=>{for(let i=0;i<2;i++)for(let j=0;j<2;j++){const c=(i+j)%2?b:a;g.fillStyle=c;g.fillRect(i*128,j*128,128,128);bevel(g,i*128,j*128,128,c)}g.fillStyle=shade(a,-.14);for(const v of [0,128]){g.fillRect(v,0,3,256);g.fillRect(0,v,256,3)}},5);
 if(kind==='planks')return tex(256,256,g=>{g.fillStyle=a;g.fillRect(0,0,256,256);for(let r=0;r<8;r++){const y=r*32;g.fillStyle=lt;g.fillRect(0,y+3,256,3);g.fillStyle=shade(a,-.035);for(let k=0;k<5;k++)g.fillRect(Math.floor(fr()*230),y+9+Math.floor(fr()*16),20+Math.floor(fr()*40),2);g.fillStyle=b;g.fillRect(0,y,256,3);g.fillRect((r*97+40)%256,y,3,32)}},4);
 return tex(256,256,g=>{g.fillStyle=a;g.fillRect(0,0,256,256);for(let k=0;k<700;k++){g.fillStyle=fr()<.55?shade(a,-.05):lt;g.fillRect(Math.floor(fr()*256),Math.floor(fr()*256),2,2)}g.fillStyle=b;g.fillRect(0,0,256,3);g.fillRect(0,0,3,256)},2)}
// what you see through the windows
const SKY=tex(64,40,(g,w,h)=>{g.imageSmoothingEnabled=false;g.fillStyle='#86c9f0';g.fillRect(0,0,w,h);g.fillStyle='#9fd6f6';g.fillRect(0,12,w,10);g.fillStyle='#bfe6fb';g.fillRect(0,20,w,8);
 g.fillStyle='#ffffff';[[5,6,10],[30,9,12],[50,4,8]].forEach(([x,y,l])=>{g.fillRect(x,y,l,2);g.fillRect(x+2,y-1,l-5,1)});
 g.fillStyle='#7a5536';g.fillRect(44,20,2,12);for(let y=6;y<24;y++)for(let x=36;x<54;x++){if((x-45)**2/62+(y-15)**2/46<1){g.fillStyle=((x*3+y*5)%7===0)?'#86cf5a':(y<11?'#6cbb4a':'#4f9a3c');g.fillRect(x,y,1,1)}}
 for(let x=0;x<w;x++){const top=h-(10+Math.round(4*Math.sin(x*.42)+2*Math.sin(x*1.1+2)));for(let y=top;y<h;y++){const d=y-top;g.fillStyle=d===0?'#8fd65f':d<3?'#63b248':((x*7+y*3)%11===0?'#78c552':'#438f3a');g.fillRect(x,y,1,1)}}},1,1,true);
const skyMat=new THREE.MeshBasicMaterial({map:SKY});
const patchMat=new THREE.MeshBasicMaterial({color:'#fff3cc',transparent:true,opacity:.42,depthWrite:false,side:THREE.DoubleSide});
const wallTex=tex(256,256,g=>{g.fillStyle='#ffffff';g.fillRect(0,0,256,256);g.fillStyle='#ececec';g.fillRect(0,170,256,86);g.fillStyle='#dadada';g.fillRect(0,0,4,170);g.fillRect(0,168,256,4);g.fillStyle='#f6f6f6';g.fillRect(4,0,3,168)},5,1);
const blockTex=tex(256,256,g=>{g.fillStyle='#efefef';g.fillRect(0,0,256,256);for(let r=0;r<8;r++){const y=r*32,o=(r%2)*32;for(let x=-64+o;x<256;x+=64){g.fillStyle='#fbfbfb';g.fillRect(x+3,y+3,58,4);g.fillRect(x+3,y+3,4,26);g.fillStyle='#e0e0e0';g.fillRect(x+3,y+25,58,4);g.fillRect(x+57,y+3,4,26);g.fillStyle='#c6c6c6';g.fillRect(x,y,64,3);g.fillRect(x,y,3,32)}}},4,1.4);
const tileTex=tex(16,16,g=>{g.fillStyle='#ffffff';g.fillRect(0,0,16,16);g.fillStyle='#c4ccd6';g.fillRect(0,0,16,1);g.fillRect(0,8,16,1);g.fillRect(0,0,1,8);g.fillRect(8,8,1,8)},12,3);

// ---------- set dressing (static, merged per room) ----------
function tote(w,h,d,body,lid){return G(B(w,h-.05,d,body),B(w+.03,.05,d+.03,lid,0,h-.05,0),B(w*.42,Math.min(.12,h*.3),.012,C.paper,0,h*.42,d/2+.006))}
function carton(w,h,d){return G(B(w,h,d,C.card),B(w+.006,.012,.12,'#ebc893',0,h,0))}
const TOTES=[['#e4e7ee',C.frame],['#e4e7ee','#8a93ab'],[C.yellow,'#3d4254'],[C.blue,'#2f5f9a'],[C.red,'#8e3a32'],['#cfd3dd','#5b6277']];
function stuff(w,h,d){const t=rnd();if(t<.62){const [b,l]=pick(TOTES);return tote(w,h,d,b,l)}if(t<.86)return carton(w,h*.9,d*.9);return G(Cy(Math.min(w,d)*.3,h*.7,pick([C.red,C.blue,C.yellow,C.white]),0,0,0,10))}
function jar(w,h){const g=G();const n=Math.max(1,Math.floor(w/.22));for(let i=0;i<n;i++){const x=-w/2+.11+i*.22;g.add(Cy(.085,h*.7,pick(['#ead9a6','#c97b4a','#f2e9cf','#8b5a3c','#e4b65a','#9cc27a']),x,0,0,10),Cy(.09,.05,pick([C.red,C.yellow,C.green,C.wood2]),x,h*.7,0,10))}return g}
function rack(w,h,d,lv,opt={}){const g=G();[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>g.add(B(.07,h,.07,opt.post||C.frame,a*(w/2-.035),0,b*(d/2-.035))));
 const step=(h-.16)/(lv-1);for(let i=0;i<lv;i++){const y=.1+i*step;g.add(B(w,.06,d,opt.board||C.frame2,0,y,0));
  if(opt.fill!==false&&i<lv-1){const gap=step-.1;let x=-w/2+.1;for(;;){const kw=.36+rnd()*.34;if(x+kw>w/2-.08)break;const kh=Math.max(.2,gap*(.55+rnd()*.38));const o=(opt.fn||stuff)(kw,kh,d*.78);o.position.set(x+kw/2,y+.06,0);g.add(o);x+=kw+.05+rnd()*.06}}}
 if(opt.top){let x=-w/2+.15;while(x<w/2-.55){const kw=.4+rnd()*.3;const o=stuff(kw,.3+rnd()*.25,d*.8);o.position.set(x+kw/2,.1+(lv-1)*step+.06,0);g.add(o);x+=kw+.12}}
 return g}
function cab(w,h,d,c,rows=3){const f=shade(c,.03);const g=G(B(w,h,d,c));const fh=(h-.1)/rows;for(let r=0;r<rows;r++){g.add(B(w-.1,fh-.06,.03,f,0,.05+r*fh+.03,d/2+.015));g.add(B(Math.min(.36,w*.4),.04,.05,C.frame,0,.05+r*fh+fh-.17,d/2+.04))}return g}
function ucab(w,c){const g=G(B(w,.95,.6,c));const n=Math.max(1,Math.round(w/.6));for(let i=0;i<n;i++){const x=-w/2+(i+.5)*w/n;g.add(B(w/n-.07,.85,.03,shade(c,.03),x,.05,.315),B(.04,.22,.05,C.frame,x+(i%2?-1:1)*(w/n/2-.12),.12,.34))}return g}
function tube(len){return G(B(len,.1,.14,C.frame,0,0,0),B(len-.14,.06,.08,MB(C.tube),0,-.06,.03))}
function potPlant(s=1,pc=C.pot){return G(Cy(.24*s,.4*s,pc,0,0,0,10,.18*s),Cy(.22*s,.03,'#5a3d2c',0,.38*s,0,10),leafy(.36*s,0,.72*s,0),L(.26*s,C.leaf2,.1*s,1.05*s,-.05*s))}
function tallPlant(){const g=G(Cy(.3,.55,C.white,0,0,0,10,.24),Cy(.27,.03,'#5a3d2c',0,.53,0,10));for(let i=0;i<7;i++){const a=i/7*6.283;const l=B(.13,.7+rnd()*.5,.05,pick([C.leaf,C.leaf2,C.leaf3]),Math.cos(a)*.1,.55,Math.sin(a)*.1);l.rotation.set(Math.sin(a)*.4,a,Math.cos(a)*.4);g.add(l)}g.add(leafy(.3,0,1.4,0));return g}
function hangPlant(len=1){const y=-len;const g=G(B(.02,len,.02,C.frame,0,y,0),B(.05,.05,.6,C.frame,0,-.05,-.3),Cy(.28,.3,C.white,0,y-.3,0,10,.2),leafy(.3,0,y+.04,0),leafy(.22,.3,y-.02,.1),leafy(.22,-.28,y-.02,-.1));for(let v=0;v<9;v++){const a=v/9*6.283;const vn=vine(3+Math.floor(rnd()*5));vn.position.set(Math.cos(a)*.34,y-.08,Math.sin(a)*.34);g.add(vn)}return g}
function wshelf(len,fill){const g=G(B(len,.06,.36,C.wood,0,0,0),B(.05,.2,.3,C.frame,-len/2+.2,-.2,0),B(.05,.2,.3,C.frame,len/2-.2,-.2,0));fill&&fill(g,len);return g}
function peg(w,h){const g=G(B(w,h,.05,'#d8ccb0'));const z=.04;
 for(let i=0;i<6;i++){const s=.5-i*.05,x=-w/2+.25+i*.16;g.add(B(.05,s,.03,C.steel,x,h-.18-s,z),B(.14,.07,.03,C.steel,x,h-.25,z))}
 const cs=[C.red,C.yellow,C.blue,C.green,C.orange];for(let i=0;i<5;i++){const x=-w/2+.3+i*.17;g.add(B(.07,.2,.04,cs[i],x,.5,z),B(.025,.28,.025,C.steel,x,.22,z))}
 const hx=w/2-.4;g.add(B(.05,.55,.04,C.wood,hx,.25,z),B(.28,.1,.07,C.dark,hx,.8,z));
 const p1=B(.035,.42,.03,C.red,w/2-.95,.35,z);p1.rotation.z=.12;const p2=B(.035,.42,.03,C.red,w/2-.85,.35,z);p2.rotation.z=-.12;g.add(p1,p2);
 const tp=Cy(.11,.06,C.yellow,w/2-.9,h-.45,z+.02,10);tp.rotation.x=Math.PI/2;g.add(tp);return g}
function stool(){const g=G(Cy(.26,.09,C.dark,0,.92,0,12),Cy(.045,.92,C.steel,0,0,0,6));const r=To(.2,.025,C.steel,0,.35,0);r.rotation.x=Math.PI/2;g.add(r);for(let k=0;k<4;k++){const a=k*Math.PI/2+.4;g.add(at(B(.06,.05,.4,C.dark),Math.sin(a)*.17,0,Math.cos(a)*.17,a))}return g}
function ochair(c=C.dark){const g=G(B(.66,.12,.62,c,0,.62,0),B(.62,.72,.1,c,0,.76,.3),Cy(.04,.55,C.steel,0,.08,0,6));for(let k=0;k<2;k++)g.add(at(B(.72,.05,.07,C.dark,0,.02,0),0,.02,0,k*Math.PI/2+.4));return g}
function kchair(){const g=G(B(.6,.08,.6,C.wood,0,.75,0),B(.6,.7,.08,C.wood,0,.83,.26));[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>g.add(B(.07,.75,.07,C.wood2,a*.26,0,b*.26)));return g}
function printer(){const g=G(B(1,.12,1,C.dark));[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>g.add(B(.07,1,.07,C.dark,a*.46,.12,b*.46)));
 g.add(B(1,.07,.07,C.dark,0,1.08,-.46),B(1,.07,.07,C.dark,0,1.08,.46),B(.07,.07,1,C.dark,-.46,1.08,0),B(.07,.07,1,C.dark,.46,1.08,0),B(.78,.04,.78,C.steel,0,.3,0),B(.86,.05,.07,C.frame2,0,.8,0),B(.14,.16,.14,C.yellow,.1,.66,0),Cy(.13,.22,C.orange,.05,.34,.05,10));
 const sp=Cy(.22,.16,C.purple,.62,.62,0,12);sp.rotation.z=Math.PI/2;g.add(sp);return g}
function scope(){return G(B(.8,.5,.55,'#c9cdd8'),B(.4,.3,.02,MB('#2c5a48'),-.14,.1,.285),B(.3,.025,.02,MB('#7ef0b0'),-.14,.24,.3),B(.07,.07,.04,C.dark,.22,.32,.29),B(.07,.07,.04,C.dark,.22,.16,.29))}
function scr(w=1,h=.6,c='#35507e'){return G(B(.32,.04,.24,C.dark),B(.06,.36,.06,C.dark,0,.02,0),B(w,h,.06,C.dark,0,.35,0),B(w-.08,h-.08,.012,MB(c),0,.39,.036),B((w-.2)*.6,.04,.013,MB('#8fb6ff'),-.1,.6,.04),B((w-.2)*.4,.04,.013,MB('#f2c14e'),-.18,.5,.04))}
function bed(){return G(B(2.1,.32,4,C.wood2),B(2,.3,3.8,C.white,0,.32,.05),B(2.06,.14,2.6,'#c9574a',0,.6,.65),B(2.08,.15,.32,'#efe5d6',0,.6,-.72),B(2.1,1.3,.14,C.wood2,0,0,-1.95),B(.78,.18,.5,C.white,-.46,.62,-1.5),B(.78,.18,.5,'#f2e6c8',.46,.62,-1.5))}
function books(g,x0,x1,y,dm,mh){let x=x0;const cs=[C.red,C.blue,C.yellow,C.green,'#e7e1d6',C.purple,C.orange,'#3d4c74'];while(x<x1-.1){const bw=.07+rnd()*.07,bh=mh*(.62+rnd()*.35);if(rnd()<.1){x+=.16;continue}g.add(B(bw,bh,dm*(.75+rnd()*.2),pick(cs),x+bw/2,y,0));x+=bw+.012}}
function bookshelf(w,h,d,lv=4){const g=G(B(.08,h,d,C.wood2,-w/2+.04,0,0),B(.08,h,d,C.wood2,w/2-.04,0,0),B(w,h,.04,shade(C.wood2,-.05),0,0,-d/2+.02));const st=(h-.1)/lv;
 for(let i=0;i<=lv;i++){g.add(B(w,.06,d,C.wood,0,i*st,0));if(i<lv){if(rnd()<.35){const o=stuff(.5,.3,d*.8);o.position.set(w/2-.4,i*st+.06,0);g.add(o);books(g,-w/2+.1,w/2-.7,i*st+.06,d*.8,st-.14)}else books(g,-w/2+.1,w/2-.1,i*st+.06,d*.8,st-.14)}}return g}
function art(w,h,c1,c2){return G(B(w,h,.05,C.wood2),B(w-.12,h-.12,.02,MB(c1),0,.06,.03),B((w-.12)*.55,(h-.12)*.42,.022,MB(c2),-.04,.08,.036))}
function lampT(){return G(Cy(.1,.05,C.dark,0,0,0,8),Cy(.03,.3,C.dark,0,.05,0,6),Cy(.13,.2,MB('#ffe3a0'),0,.32,0,10,.18))}
function flamp(){return G(Cy(.22,.05,C.dark,0,0,0,10),Cy(.03,1.9,C.dark,0,.05,0,6),Cy(.2,.3,MB('#ffe3a0'),0,1.9,0,10,.3))}
function pouf(){return G(Cy(.5,.42,'#ece3d2',0,0,0,12),Cy(.44,.05,'#f6efe2',0,.42,0,12))}
function rug(w,d,a,b){return G(B(w,.03,d,a),B(w,.035,.14,b,0,0,d/2-.07),B(w,.035,.14,b,0,0,-d/2+.07),B(.14,.035,d,b,w/2-.07,0,0),B(.14,.035,d,b,-w/2+.07,0,0),B(w-.7,.036,.07,b,0,0,d/2-.36),B(w-.7,.036,.07,b,0,0,-d/2+.36))}
function rdoor(w,h){const g=G();const n=9;for(let i=0;i<n;i++)g.add(B(w,h/n-.02,.08,i%2?'#c3c8d4':'#b4bac8',0,i*h/n,0));
 g.add(B(.14,h+.1,.16,C.frame,-w/2-.07,0,0),B(.14,h+.1,.16,C.frame,w/2+.07,0,0),B(w+.28,.3,.2,C.frame,0,h,0),B(.5,.06,.06,C.dark,0,.5,.07));for(let i=0;i<3;i++)g.add(B(w/4,.2,.09,MB('#a8d8ef'),-w/2+w*(i+.5)/3,h*.64,0));return g}
function tchest(){const g=G(B(1.2,1.25,.7,C.red,0,.14,0),B(1.24,.14,.74,'#a9433a',0,1.39,0));for(let r=0;r<5;r++)g.add(B(1.08,.19,.03,'#e36a5d',0,.22+r*.23,.36),B(.5,.03,.05,C.steel,0,.36+r*.23,.38));[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>g.add(B(.12,.14,.12,C.dark,a*.5,0,b*.27)));return g}
function vac(){const g=G(Cy(.36,.62,'#3f7fd0',0,.08,0,12),Cy(.32,.2,C.dark,0,.7,0,12),Cy(.1,.08,C.dark,.25,0,.25,8),Cy(.1,.08,C.dark,-.25,0,.25,8));const h=To(.3,.045,C.dark,.35,.6,0,Math.PI*1.3);h.rotation.y=Math.PI/2;g.add(h);return g}
function lrack(len){const g=G();for(let i=0;i<3;i++){const y=1.0+i*.85;[-len/2+.3,0,len/2-.3].forEach(x=>g.add(B(.08,.06,.55,C.frame,x,y,.27)));for(let k=0;k<3;k++)g.add(B(len-(k%2)*.4,.12,.14,pick([C.wood,shade(C.wood,.05),shade(C.wood,-.06)]),(k%2)*.2,y+.06+(k%2)*.12,.12+k*.15))}return g}
function robotArm(){const w='#eef1f6';const g=G(Cy(.24,.1,C.dark,0,0,0,12),Cy(.15,.25,w,0,.1,0,12));const j1=new THREE.Group();j1.position.set(0,.38,0);j1.rotation.z=-.5;g.add(j1);j1.add(B(.13,.75,.13,w),S(.1,C.dark));const j2=new THREE.Group();j2.position.set(0,.75,0);j2.rotation.z=1.6;j1.add(j2);j2.add(S(.09,C.dark),B(.11,.6,.11,w));const gr=new THREE.Group();gr.position.set(0,.6,0);j2.add(gr);gr.add(B(.16,.08,.16,C.dark),B(.04,.16,.06,C.dark,-.05,.08,0),B(.04,.16,.06,C.dark,.05,.08,0));return g}
function cart(){const g=rack(1.3,1.0,.8,3);[[-1,-1],[1,-1],[-1,1],[1,1]].forEach(([a,b])=>g.add(Cy(.06,.06,C.dark,a*.6,-.06,b*.35,8)));g.position.y=.06;return G(g)}
function cmat(w,d){return G(B(w,.015,d,'#3f8f62'),B(w-.12,.017,.02,'#6cc08f',0,0,d/2-.12),B(.02,.017,d-.12,'#6cc08f',-w/2+.12,0,0))}
function pcb(){return G(B(.5,.03,.34,'#2f7a4a'),B(.1,.04,.1,C.dark,-.1,.03,0),B(.08,.04,.14,C.dark,.12,.03,.05),B(.12,.03,.04,C.yellow,.1,.03,-.12))}
function pad(){return G(B(.55,.1,.3,C.dark),Cy(.05,.08,C.ink,-.14,.1,0,8),Cy(.05,.08,C.ink,.14,.1,0,8),B(.06,.02,.06,C.red,.02,.1,.07))}
function spoolRack(w){const g=G(B(.06,.6,.3,C.dark,-w/2,0,0),B(.06,.6,.3,C.dark,w/2,0,0));const cs=[C.red,C.blue,C.yellow,C.white];const n=Math.floor(w/.24);for(let i=0;i<n;i++){const s2=Cy(.2,.18,cs[i%4],-w/2+.15+i*.24,.3,0,12);s2.rotation.z=Math.PI/2;s2.position.y=.45;g.add(s2)}const rod=Cy(.025,w,C.steel,0,.45,0,6);rod.rotation.z=Math.PI/2;rod.position.y=.45;g.add(rod);return g}
function dlamp(){const g=G(Cy(.14,.05,C.dark,0,0,0,10));const a=B(.05,.6,.05,C.dark,0,0,0);a.position.set(.08,.32,0);a.rotation.z=-.3;g.add(a);const b2=B(.05,.45,.05,C.dark);b2.position.set(.05,.75,0);b2.rotation.z=1.1;g.add(b2);g.add(Cy(.09,.16,C.dark,-.17,.66,0,10,.15));return g}
// a window: frame, the view outside, and sunlight on the floor
function win(g,wall,u,w,y0,y1,cols=2,rows=2){const wg=new THREE.Group();const h=y1-y0;const fc='#e9ecf3';
 wg.add(B(w+.24,.14,.16,fc,0,y1,.05),B(w+.3,.12,.24,fc,0,y0-.12,.09),B(.12,h,.16,fc,-w/2-.06,y0,.05),B(.12,h,.16,fc,w/2+.06,y0,.05));
 for(let c=1;c<cols;c++)wg.add(B(.07,h,.1,fc,-w/2+c*w/cols,y0,.04));for(let r=1;r<rows;r++)wg.add(B(w,.07,.1,fc,0,y0+r*h/rows-.035,.04));
 const pane=new THREE.Mesh(new THREE.PlaneGeometry(w,h),skyMat);pane.position.set(0,y0+h/2,.012);wg.add(pane);
 const k=.85,sx=wall==='back'?-.32:.32;
 for(let c=0;c<cols;c++)for(let r=0;r<rows;r++){const a0=-w/2+c*w/cols+.05,a1=-w/2+(c+1)*w/cols-.05,b0=y0+r*h/rows+.05,b1=y0+(r+1)*h/rows-.05;
  const pts=[[a0+b0*sx,b0*k],[a1+b0*sx,b0*k],[a1+b1*sx,b1*k],[a0+b1*sx,b1*k]];const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.Float32BufferAttribute(pts.flatMap(([x,z])=>[x,.016,z]),3));geo.setIndex([0,2,1,0,3,2]);
  const m=new THREE.Mesh(geo,patchMat);m.userData.decal=true;m.userData.keep=true;wg.add(m)}
 if(wall==='back')wg.position.set(u,0,-5.05);else{wg.position.set(-5.05,0,u);wg.rotation.y=Math.PI/2}
 g.add(wg)}
// back wall faces +z at z=-5.05, left wall faces +x at x=-5.05
const DRESS={
 lab:g=>{
  win(g,'back',1.4,4.2,1.85,3.65,3,2);
  g.add(at(tube(2.6),-3.2,3.95,-4.98),at(tube(2.4),-4.98,3.95,-1.8,Math.PI/2),at(tube(2.4),-4.98,3.95,2.4,Math.PI/2));
  for(let k=0;k<7;k++)g.add(at(cab(.98,1.42,.95,'#d6dae3',k%3===1?1:3),-1.55+k*.98,0,-4.57));
  g.add(B(6.95,.09,1.05,C.wood,1.39,1.42,-4.55));const top=1.51;
  g.add(at(scope(),-1.35,top,-4.62),at(scr(1.1,.62),.55,top,-4.7),B(.9,.04,.3,C.white,.55,top,-4.22),at(printer(),3.95,top,-4.6));
  g.add(at(spoolRack(1.05),2.35,top,-4.6),at(dlamp(),-.45,top,-4.55));
  g.add(at(cart(),-3.55,0,4.15),at(robotArm(),-3.7,1.12,4.15,.6),at(tote(.5,.3,.4,C.yellow,'#3d4254'),-3.15,1.12,4.15));
  g.add(at(tote(.8,.5,.7,C.blue,'#2f5f9a'),-1.2,.44,1.8),at(tote(.8,.45,.7,'#e4e7ee',C.frame),-.25,.44,1.8),at(tote(.8,.5,.7,C.yellow,'#3d4254'),1.25,.44,1.8));
  g.add(at(cmat(1.1,.7),-.35,1.6,1.4),at(pcb(),-.4,1.615,1.4,.3),at(pad(),.85,1.6,1.3,-.3));
  g.add(at(wshelf(2.2,s=>{s.add(at(potPlant(.6),-.7,.06,0),at(carton(.5,.34,.3),.1,.06,0),at(tote(.5,.3,.3,C.blue,'#2f5f9a'),.7,.06,0));const v=vine(7);v.position.set(-.82,0,.12);s.add(v)}),-3.4,2.85,-4.86));
  g.add(at(rack(2.4,3.3,.85,5,{top:true}),-4.62,0,-1.75,Math.PI/2));
  g.add(at(cab(2.6,1.1,.7,'#c9ced9',2),-4.69,0,2.35,Math.PI/2),B(.78,.07,2.72,C.wood,-4.66,1.1,2.35),at(peg(2.6,1.5),-5.02,1.75,2.35,Math.PI/2));
  g.add(at(tote(.5,.32,.4,C.red,'#8e3a32'),-4.62,1.17,1.45,Math.PI/2),at(potPlant(.55),-4.62,1.17,3.35),at(scope(),-4.62,1.17,2.4,Math.PI/2));
  g.add(at(tallPlant(),4.55,0,-3.5),at(hangPlant(1.1),-1.2,4.35,-4.5),at(stool(),-1.1,0,3.45),at(stool(),1.2,0,3.5));
 },
 garage:g=>{
  win(g,'back',3.95,1.7,2.0,3.4,2,2);
  g.add(at(rdoor(3.6,3.2),-5.0,0,2.35,Math.PI/2),at(tube(2.4),-1.7,3.95,-4.98),at(tube(2.2),-4.98,3.95,-2.4,Math.PI/2));
  g.add(at(tchest(),-.6,0,-4.67),at(mk.table(2.6,1,1.4,C.wood),1.65,0,-4.55),B(2.4,.06,.85,C.wood2,1.65,.34,-4.55),at(peg(2.6,1.4),1.65,1.65,-5.02));
  g.add(at(carton(.6,.4,.5),1.0,.4,-4.55),at(tote(.6,.35,.5,C.yellow,'#3d4254'),2.2,.4,-4.55));
  g.add(at(rack(2.4,3.0,.8,4,{top:true}),-4.65,0,-2.35,Math.PI/2));
  g.add(B(.12,.012,5,C.yellow,.35,0,2.75),B(.12,.012,5,C.yellow,4.85,0,2.75));
  g.add(at(potPlant(.7),-3.6,3.13,-4.55),at(hangPlant(1),4.95,4.35,-4.5));
  {const v=vine(9);v.position.set(-3.85,3.1,-4.1);g.add(v)}
 },
 kitchen:g=>{
  win(g,'left',.35,2.6,1.6,3.4,2,2);
  {const bs=new THREE.Mesh(bx(4.1,.86,.04),new THREE.MeshToonMaterial({color:'#dfe9ee',map:tileTex,gradientMap:GRAD}));bs.position.set(1,2.15,-5.03);bs.receiveShadow=true;g.add(bs)}
  g.add(at(ucab(2.4,'#f3ede2'),1.75,2.62,-4.75),at(tube(2.2),1.75,3.95,-4.98));
  g.add(at(rack(1.6,3.4,.75,5,{post:C.wood2,board:C.wood,fn:jar,top:true}),4.2,0,-4.67));
  [[.4,-.45,Math.PI],[2.0,-.45,Math.PI],[.4,2.45,0],[2.0,2.45,0]].forEach(([x,z,r])=>g.add(at(kchair(),x,0,z,r)));
  g.add(at(rug(4.4,3.4,'#e6d6b8','#b1453c'),1.2,0,1),at(potPlant(.9),-4.45,0,4.4),at(hangPlant(1.2),-4.5,4.35,2.4,Math.PI/2));
  g.add(Cy(.12,.3,C.blue,1.6,1.5,1.3,10),leafy(.18,1.6,1.9,1.3));
  g.add(at(wshelf(1.8,s=>{for(let i=0;i<4;i++)s.add(Cy(.17,.05,C.white,-.6+i*.4,.06,0,12),Cy(.17,.05,'#e8ecf0',-.6+i*.4,.11,0,12))}),-4.86,2.7,-1.7,Math.PI/2));
 },
 desk:g=>{
  win(g,'left',2.75,2.4,1.85,3.5,2,2);
  g.add(at(bed(),-3.98,0,2.75),at(cab(.85,.75,.7,C.wood,2),-4.68,0,-.05,Math.PI/2),at(lampT(),-4.6,.75,-.05));
  g.add(at(bookshelf(2.2,3.3,.7),-3.75,0,-4.68),at(ochair('#e9e6e0'),0,0,-1.6));
  g.add(at(wshelf(2.6,s=>{books(s,-1.2,-.2,.06,.28,.42);s.add(at(potPlant(.55),.3,.06,0),at(carton(.5,.3,.28),.95,.06,0));const v=vine(7);v.position.set(.42,0,.12);s.add(v)}),0,3.05,-4.86));
  g.add(at(art(.9,1.1,'#7fb0d8','#e9b45a'),2.75,1.9,-5.02),at(art(.8,.65,'#f0c9a8','#6c9a5a'),3.9,2.45,-5.02),at(art(.7,.9,'#a7c6a0','#f1e3c2'),-5.02,2.2,-1.5,Math.PI/2));
  g.add(at(rug(3.6,2.8,'#efe6d6','#c98f6a'),.7,0,1.3),at(pouf(),2.75,0,1.9),at(flamp(),4.55,0,-1.5),at(hangPlant(1),4.6,4.35,-4.55));
 },
 workshop:g=>{
  win(g,'back',3.75,1.9,1.9,3.5,2,2);
  g.add(at(tube(2.6),0,3.95,-4.98),at(tube(2.2),-4.98,3.95,-2.45,Math.PI/2),at(tube(2.2),-4.98,3.95,2.5,Math.PI/2));
  g.add(at(cab(1.8,1.25,.8,'#8d95ab',4),-4.0,0,-4.62),B(1.9,.08,.9,C.dark,-4.0,1.25,-4.62),at(tote(.6,.35,.5,C.yellow,'#3d4254'),-4.4,1.33,-4.62),at(potPlant(.6),-3.5,1.33,-4.62));
  g.add(at(rack(2.2,3.0,.85,4,{top:true}),-4.62,0,-2.45,Math.PI/2),at(lrack(3.6),-5.05,0,2.5,Math.PI/2));
  g.add(at(vac(),4.35,0,-2.9),at(tallPlant(),4.55,0,-4.5),at(stool(),1.3,0,-1.5),at(hangPlant(1.1),2.5,4.35,-4.5));
 },
 build:g=>{win(g,'back',2.3,2.6,1.9,3.5,2,2);g.add(at(tube(2.4),-4.98,3.95,0,Math.PI/2),at(tube(2.2),-2,3.95,-4.98))},
};
// merge the static set into a few meshes per room so it stays fast
function bake(g){g.updateMatrixWorld(true);const inv=g.matrixWorld.clone().invert();const bins=new Map();const kill=[];
 g.traverse(o=>{if(!o.isMesh||o.userData.keep)return;let geo=o.geometry.index?o.geometry.toNonIndexed():o.geometry.clone();for(const k of Object.keys(geo.attributes))if(!['position','normal','uv'].includes(k))geo.deleteAttribute(k);
  geo.applyMatrix4(new THREE.Matrix4().multiplyMatrices(inv,o.matrixWorld));const key=o.material.uuid+'|'+(o.castShadow?1:0)+(o.userData.noEdge?1:0);
  if(!bins.has(key))bins.set(key,{mat:o.material,cast:o.castShadow,noEdge:o.userData.noEdge,list:[]});bins.get(key).list.push(geo);kill.push(o)});
 kill.forEach(o=>{o.parent.remove(o);if(o.geometry!==ICO&&![...BXC.values()].includes(o.geometry))o.geometry.dispose()});
 bins.forEach(v=>{const m=new THREE.Mesh(BGU.mergeGeometries(v.list,false),v.mat);m.castShadow=v.cast;m.receiveShadow=true;m.userData.noEdge=v.noEdge;g.add(m);v.list.forEach(geometry=>geometry.dispose())})}

// ---------- build world ----------
const pickables=[];const spaceGroups=[];
function makeRoom(sp,i,opt={}){const st=sp.style;const g=new THREE.Group();g.position.copy(spaceCenter(i));const WH=4.4;
 const fm=opt.floorMat||new THREE.MeshToonMaterial({color:'#ffffff',map:floorTex(st.floor,st.fc,st.fc2),gradientMap:GRAD});
 const wm=opt.wallMat||new THREE.MeshToonMaterial({color:st.wall,map:st.blocks?blockTex:wallTex,gradientMap:GRAD}),cm=opt.capMat||M(st.cap),tm=opt.trimMat||M(st.trim);
 g.add(B(10.95,.9,10.95,'#3a3f55',-.125,-.96,-.125),B(10.85,.06,10.85,fm,-.125,-.06,-.125));
 g.add(B(10.85,WH,.5,wm,-.125,0,-5.3),B(.5,WH,10.35,wm,-5.3,0,.125),B(10.85,.1,.56,cm,-.125,WH,-5.3),B(.56,.1,10.35,cm,-5.3,WH,.125));
 g.add(B(10.35,.24,.06,tm,.125,0,-5.02),B(.06,.24,10.1,tm,-5.02,0,.25));
 (DRESS[sp.id]||DRESS.build)(g);bake(g);return g}
function makeItem(it){
  let o;
  if(it.k==='ketchup'||it.k==='nine'){o=it.k==='ketchup'?Cy(.13,.5,C.red,0,0,0,14):mk.battery(C.dark);if(it.k==='ketchup'){o.rotation.z=Math.PI/2}else{o.scale.setScalar(.38)};const w=new THREE.Group();w.add(o);o=w}
  else o=(mk[it.k])(...(it.args||[]));
  return o}
function placeItem(group,it,spIdx){
  let o=makeItem(it);
  o.position.set(it.p[0],it.y||0,it.p[1]);o.rotation.y=it.r||0;
  if(it.stack){const g=new THREE.Group();for(let lv=0;lv<3;lv++)for(let k=0;k<3;k++){const b=mk.bin(.85,.75,.45,[C.blue,C.yellow,C.red][(lv+k)%3]);b.position.set(-1+k*1,[0,.97,1.93][lv],0);g.add(b)}g.position.copy(o.position);o=g}
  o.userData.item={...it,space:SP[spIdx]?.label||'Your space'};
  group.add(o);if(!it.decor||it.k!=='table')pickables.push(o);return o}
// Rooms are populated from canonical API records below, one active room at a time.
// build slot, with its own recolourable materials
// ---------- room styles for your own space ----------
const THEMES=[
 {n:'Lab grey',f:['tiles','#cfd2dd','#a9aebd'],w:['blocks','#b6bccd'],cap:'#d6dae6',trim:'#6c728a'},
 {n:'Garage',f:['concrete','#bfc2ca','#a2a6b0'],w:['blocks','#a5abbd'],cap:'#c9cedb',trim:'#5b6277'},
 {n:'Vanilla',f:['checker','#f3ebdb','#e2cdb0'],w:['panels','#efe2cc'],cap:'#f8efe0',trim:'#c9ad8a'},
 {n:'Rosewood',f:['planks','#d39a64','#a8703f'],w:['panels','#e3c4bb'],cap:'#f0ddd6',trim:'#a98377'},
 {n:'Sage',f:['planks','#dcb07a','#b4834b'],w:['blocks','#b5c7a5'],cap:'#d3e0c6',trim:'#7c9070'},
 {n:'Strawberry milk',f:['checker','#fbe3e6','#f4c0c8'],w:['stripes','#fff1ef','#f8d3d8'],cap:'#fff8f6',trim:'#e08a98'},
 {n:'Matcha latte',f:['planks','#e8d2ae','#c9a774'],w:['dots','#c9dcb7','#eef5e4'],cap:'#e3eed8',trim:'#8fae78'},
 {n:'Lavender',f:['tiles','#ece5f7','#cbbde3'],w:['stars','#cdbdea','#f7f1ff'],cap:'#e6dcf7',trim:'#9b86c6',lv:2},
 {n:'Peach fizz',f:['terrazzo','#fde3cf','#f2a98a'],w:['gingham','#ffe8d9','#f9bfa0'],cap:'#fff2e8',trim:'#e38c69',lv:2},
 {n:'Cotton sky',f:['tiles','#e2f0fb','#b9d7ef'],w:['clouds','#a9d4f2','#ffffff'],cap:'#d7ebfa',trim:'#6fa3cf',lv:3},
 {n:'Lemonade',f:['checker','#fff7d6','#f6df84'],w:['stripes','#fffbe9','#f9e7a0'],cap:'#fffdf3',trim:'#e0b94a',lv:3},
 {n:'Mint choc',f:['planks','#9b6b4a','#6f4a32'],w:['hearts','#c6ecd9','#f4fffa'],cap:'#e1f6ec',trim:'#5e9f84',lv:4},
 {n:'Bubblegum',f:['terrazzo','#ffe0ef','#ff9cc6'],w:['dots','#ffb8d6','#fff0f7'],cap:'#ffd6e8',trim:'#e96fa3',lv:4},
 {n:'Night owl',f:['planks','#5b5f7e','#454862'],w:['stars','#3d4266','#f6e7a6'],cap:'#555b85',trim:'#2b2f4a',lv:5},
 {n:'Cabin',f:['planks','#b97f4f','#8e5c36'],w:['wood','#c99363','#a8703f'],cap:'#e0b58a',trim:'#7a4f2e',lv:5},
 {n:'Cherry blossom',f:['planks','#f0dcc6','#d4b391'],w:['hearts','#fff3f6','#f6c2d0'],cap:'#fffafb',trim:'#d98ca2',lv:6},
];
const FLOORS=THEMES;
function wallPat(kind,a,b){
 const W=(rx,ry,draw)=>tex(256,256,g=>{g.fillStyle=a;g.fillRect(0,0,256,256);draw(g)},rx,ry);
 if(kind==='blocks')return W(4,1.4,g=>{for(let r=0;r<8;r++){const y=r*32,o=(r%2)*32;for(let x=-64+o;x<256;x+=64){g.fillStyle=shade(a,.04);g.fillRect(x+3,y+3,58,4);g.fillRect(x+3,y+3,4,26);g.fillStyle=shade(a,-.04);g.fillRect(x+3,y+25,58,4);g.fillRect(x+57,y+3,4,26);g.fillStyle=shade(a,-.1);g.fillRect(x,y,64,3);g.fillRect(x,y,3,32)}}});
 if(kind==='panels')return W(5,1,g=>{g.fillStyle=shade(a,-.07);g.fillRect(0,0,4,256);g.fillStyle=shade(a,.04);g.fillRect(4,0,3,256)});
 if(kind==='wood')return W(10,1,g=>{g.fillStyle=b;g.fillRect(0,0,6,256);g.fillStyle=shade(a,.05);g.fillRect(6,0,4,256);g.fillStyle=shade(a,-.04);for(let k=0;k<6;k++)g.fillRect(40+fr()*170,fr()*230,3,26)});
 if(kind==='stripes')return W(9,1,g=>{g.fillStyle=b;g.fillRect(128,0,128,256);g.fillStyle=shade(b,-.04);g.fillRect(128,0,6,256);g.fillRect(250,0,6,256)});
 if(kind==='dots')return W(8,3,g=>{g.fillStyle=b;for(const [x,y] of [[64,64],[192,192],[192,64],[64,192]]){if((x+y)%256===0||true){g.beginPath();g.arc(x+((y/128|0)%2)*0,y,22,0,6.283);g.fill()}}});
 if(kind==='stars')return W(8,3,g=>{g.fillStyle=b;const st=(x,y,s)=>{g.fillRect(x-s,y-s/4,s*2,s/2);g.fillRect(x-s/4,y-s,s/2,s*2);g.fillRect(x-s/2,y-s/2,s,s)};st(64,70,26);st(190,190,18);st(200,52,10);st(70,200,10)});
 if(kind==='gingham')return W(10,4,g=>{g.globalAlpha=.55;g.fillStyle=b;g.fillRect(0,0,128,256);g.fillRect(0,0,256,128);g.globalAlpha=1});
 if(kind==='clouds')return W(5,2,g=>{g.fillStyle=b;const cl2=(x,y,s)=>{[[0,0,1],[-.9,.25,.75],[.9,.25,.75],[-.4,-.45,.7],[.45,-.35,.65]].forEach(([dx,dy,r])=>{g.beginPath();g.arc(x+dx*s,y+dy*s,r*s,0,6.283);g.fill()});g.fillRect(x-1.6*s,y+.25*s,3.2*s,.75*s)};cl2(80,90,34);cl2(196,196,22)});
 if(kind==='hearts')return W(8,3,g=>{g.fillStyle=b;const h=(x,y,s)=>{g.beginPath();g.moveTo(x,y+s*.9);g.bezierCurveTo(x-s*1.3,y,x-s*.6,y-s*.9,x,y-s*.3);g.bezierCurveTo(x+s*.6,y-s*.9,x+s*1.3,y,x,y+s*.9);g.fill()};h(64,70,30);h(192,196,30)});
 return W(1,1,()=>{})}
function floorTexX(kind,a,b){if(kind!=='terrazzo')return floorTex(kind,a,b);return tex(256,256,g=>{g.fillStyle=a;g.fillRect(0,0,256,256);const cs=[b,shade(b,.12),'#ffffff',shade(a,-.12)];for(let k=0;k<150;k++){g.fillStyle=cs[k%4];const s=4+fr()*9;g.save();g.translate(fr()*256,fr()*256);g.rotate(fr()*3);g.fillRect(-s/2,-s/3,s,s*.66);g.restore()}},3)}
const THEME_TEX={};function themeTex(i){const t=THEMES[i];if(!THEME_TEX[i])THEME_TEX[i]=[floorTexX(t.f[0],t.f[1],t.f[2]),wallPat(t.w[0],t.w[1],t.w[2]||t.w[1])];return THEME_TEX[i]}
const THEME_PREV={};function themePrev(i){if(THEME_PREV[i])return THEME_PREV[i];const [ft,wt]=themeTex(i);const cv=document.createElement('canvas');cv.width=120;cv.height=90;const g=cv.getContext('2d');
 g.drawImage(wt.image,0,0,256,256,0,0,120,58);g.drawImage(ft.image,0,0,256,256,0,58,120,120);g.fillStyle=THEMES[i].trim;g.fillRect(0,54,120,5);g.fillStyle=THEMES[i].cap;g.fillRect(0,0,120,4);return THEME_PREV[i]=cv.toDataURL()}
const roomMats=[new THREE.MeshToonMaterial({color:'#ffffff',map:themeTex(0)[0],gradientMap:GRAD}),new THREE.MeshToonMaterial({color:'#ffffff',map:themeTex(0)[1],gradientMap:GRAD}),new THREE.MeshToonMaterial({color:THEMES[0].cap,gradientMap:GRAD}),new THREE.MeshToonMaterial({color:THEMES[0].trim,gradientMap:GRAD})];
const buildRoom=makeRoom({id:'build',style:{trim:'#6c728a'}},BUILD_IDX,{floorMat:roomMats[0],wallMat:roomMats[1],capMat:roomMats[2],trimMat:roomMats[3]});scene.add(buildRoom);
// cute pieces
function beanbag(){const b=S(.55,'#f5b8c9',0,.3,0);b.scale.set(1,.55,1);return G(b,S(.28,'#f9cbd7',.05,.5,-.12))}
function rrug(){return G(Cy(1.1,.03,'#f6d6e0',0,0,0,28),Cy(.8,.035,'#fdf1f4',0,0,0,28),Cy(.45,.04,'#f6d6e0',0,0,0,28))}
function heartRug(){const s=new THREE.Shape();s.moveTo(0,-.9);s.bezierCurveTo(-.2,-.6,-1.1,-.2,-1.1,.35);s.bezierCurveTo(-1.1,.85,-.5,1.05,0,.6);s.bezierCurveTo(.5,1.05,1.1,.85,1.1,.35);s.bezierCurveTo(1.1,-.2,.2,-.6,0,-.9);const g=new THREE.ExtrudeGeometry(s,{depth:.04,bevelEnabled:false,curveSegments:16});g.rotateX(-Math.PI/2);return G(mesh(g,'#f4a3b8'))}
function bear(c='#c89366'){return G(S(.28,c,0,.28,0),S(.21,c,0,.66,0),S(.08,c,-.15,.84,0),S(.08,c,.15,.84,0),S(.09,'#f3dcc0',0,.62,.17),S(.025,C.ink,0,.66,.26),S(.025,C.ink,-.08,.73,.18),S(.025,C.ink,.08,.73,.18),S(.09,c,-.24,.3,.14),S(.09,c,.24,.3,.14),S(.1,c,-.13,.08,.18),S(.1,c,.13,.08,.18),S(.06,'#f6b6c4',0,.44,.24))}
function catPet(){const o='#f0a35a';const body=S(.32,o,0,.24,0);body.scale.set(1.3,.72,1);const g=G(body,S(.2,o,.38,.32,.08),S(.08,'#fff4e6',.54,.28,.08));[-.08,.08].forEach(z=>{const e=mesh(new THREE.ConeGeometry(.07,.14,4),o);e.position.set(.38,.53,.08+z);g.add(e);g.add(B(.012,.012,.06,C.ink,.575,.34,.08+z*1.1))});const t=To(.22,.05,o,-.25,.08,.15,Math.PI);t.rotation.x=Math.PI/2;g.add(t);return g}
function duck(){const b=S(.15,C.yellow,0,.14,0);b.scale.set(1.25,.85,1);return G(b,S(.1,C.yellow,.1,.32,0),B(.09,.035,.07,C.orange,.22,.29,0),S(.018,C.ink,.17,.36,.05),S(.018,C.ink,.17,.36,-.05))}
function mlamp(){const cap=mesh(new THREE.SphereGeometry(.24,14,8,0,Math.PI*2,0,Math.PI/2),C.red);cap.position.y=.28;const g=G(Cy(.09,.28,'#fff6ea',0,0,0,10),cap);[[0,.5,0],[.13,.43,.1],[-.12,.44,.1],[.08,.42,-.15]].forEach(([x,y,z])=>g.add(S(.035,'#ffffff',x,y,z)));return g}
function vase(){const g=G(Cy(.1,.26,'#bfe3f0',0,0,0,10,.07));[[0,.48,0,'#f6a5c0'],[.08,.42,.05,'#fff2a8'],[-.07,.44,-.03,'#ffffff'],[.03,.4,-.08,'#f6a5c0']].forEach(([x,y,z,c])=>{g.add(B(.015,y-.22,.015,C.leaf,x*.6,.22,z*.6),S(.06,c,x,y,z))});return g}
function cactus(){return G(Cy(.15,.18,'#e9a07a',0,0,0,10,.12),Cy(.07,.42,'#5aa04a',0,.18,0,8),B(.12,.06,.06,'#5aa04a',.08,.36,0),Cy(.045,.14,'#5aa04a',.15,.36,0,8),S(.035,'#f6a5c0',0,.62,0))}
function cloudLamp(){const m=MB('#fff8ec');return G(Cy(.03,.25,C.dark,0,0,0,6),S(.17,m,0,.36,0),S(.13,m,-.17,.32,0),S(.13,m,.17,.32,0),S(.11,m,.07,.48,0))}
function pshelf(){return rack(1.6,1.6,.6,3,{post:'#f3c6d1',board:'#fbe3e8',fn:(w,h,d)=>tote(w,h,d,pick(['#cfe8f7','#fbd3dd','#fdf0c4','#d8f0dc','#e6dcf7']),'#ffffff')})}
const buildGroup=new THREE.Group();buildGroup.position.copy(spaceCenter(BUILD_IDX));scene.add(buildGroup);
// grid overlay for build
const bgc=document.createElement('canvas');bgc.width=bgc.height=160;{const g=bgc.getContext('2d');g.clearRect(0,0,160,160);g.fillStyle='rgba(30,34,52,.35)';for(let k=0;k<=10;k++){g.fillRect(k*16,0,1,160);g.fillRect(0,k*16,160,1)}}
const bgt=new THREE.CanvasTexture(bgc);bgt.magFilter=THREE.NearestFilter;const buildGrid=new THREE.Mesh(new THREE.PlaneGeometry(10,10),new THREE.MeshBasicMaterial({map:bgt,transparent:true,depthWrite:false}));buildGrid.rotation.x=-Math.PI/2;buildGrid.position.set(BUILD_IDX*GAP,.02,0);buildGrid.userData.decal=true;buildGrid.visible=false;scene.add(buildGrid);

// ---------- outline post ----------
const post=new THREE.ShaderMaterial({uniforms:{tC:{value:null},tN:{value:null},tD:{value:null},res:{value:new THREE.Vector2()},off:{value:new THREE.Vector2()},px:{value:3},th:{value:2},span:{value:139},ink:{value:new THREE.Color('#23263a')}},
 vertexShader:`varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.,1.);}`,
 fragmentShader:`uniform sampler2D tC,tN,tD;uniform vec2 res,off;uniform float span,px,th;uniform vec3 ink;varying vec2 vUv;vec2 U;
 vec3 srgb(vec3 c){c=clamp(c,0.,1.);return mix(c*12.92,1.055*pow(c,vec3(1./2.4))-.055,step(.0031308,c));}
 float sil(vec2 o,float dc){float rn=texture2D(tD,U+o).x;if(rn>.99999)return 1.;float dn=rn*span;float dp=texture2D(tD,U-o).x*span;return step(.1,dn-max(dc+(dc-dp),dc));}
 void main(){U=(floor((gl_FragCoord.xy-off)/px)+.5)/res;float r=texture2D(tD,U).x;if(r>.99999){gl_FragColor=vec4(0.);return;}vec2 p=1./res;float dc=r*span;vec3 col=srgb(texture2D(tC,U).rgb);
  float e=0.;for(int k=1;k<=3;k++){float f=float(k);if(f>th)break;e=max(e,max(max(sil(vec2(p.x*f,0.),dc),sil(vec2(-p.x*f,0.),dc)),max(sil(vec2(0.,p.y*f),dc),sil(vec2(0.,-p.y*f),dc))));}
  vec4 n4=texture2D(tN,U);float hi=0.,dk=0.;
  if(n4.a>.5){vec3 nc=n4.rgb*2.-1.;for(int k=0;k<4;k++){vec2 o=k==0?vec2(p.x,0.):k==1?vec2(-p.x,0.):k==2?vec2(0.,p.y):vec2(0.,-p.y);
   vec4 nn=texture2D(tN,U+o);if(nn.a<.5)continue;if(abs(texture2D(tD,U+o).x*span-dc)>.3)continue;vec3 n2=nn.rgb*2.-1.;if(dot(n2,nc)>.72)continue;
   float dy=nc.y-n2.y;if(dy>.35)hi=1.;else if(dy<-.35)dk=1.;else if(k==0||k==2)dk=1.;}}
  col=mix(col,vec3(1.),.3*hi*(1.-dk));col=mix(col,ink,.6*dk);col=mix(col,ink,e);gl_FragColor=vec4(col,1.);}`,depthTest:false,depthWrite:false});
const pScene=new THREE.Scene();pScene.add(new THREE.Mesh(new THREE.PlaneGeometry(2,2),post));const pCam=new THREE.OrthographicCamera(-1,1,1,-1,0,1);
const nMat=new THREE.ShaderMaterial({vertexShader:`varying vec3 vN;void main(){vN=normalize(mat3(modelMatrix)*normal);gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,fragmentShader:`varying vec3 vN;void main(){gl_FragColor=vec4(normalize(vN)*.5+.5,1.);}`});
const nFlat=new THREE.ShaderMaterial({vertexShader:`void main(){gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,fragmentShader:`void main(){gl_FragColor=vec4(.5,1.,.5,0.);}`});
// depth colormap for scanned item
const depthMat=new THREE.ShaderMaterial({uniforms:{uMin:{value:10},uMax:{value:20}},vertexShader:`varying float vz;void main(){vec4 mv=modelViewMatrix*vec4(position,1.);vz=-mv.z;gl_Position=projectionMatrix*mv;}`,
 fragmentShader:`uniform float uMin,uMax;varying float vz;vec3 turbo(float t){t=clamp(t,0.,1.);return clamp(vec3(.13572+t*(4.6153-t*(42.66-t*(132.13-t*(152.95-t*59.29)))),.0914+t*(2.194+t*(4.843-t*(14.19-t*(4.276+t*2.8297)))),.1067+t*(12.64-t*(60.58-t*(110.36-t*(89.9-t*27.35))))),0.,1.);}
 void main(){vec3 c=turbo(1.-(vz-uMin)/(uMax-uMin));c=floor(c*6.+.5)/6.;gl_FragColor=vec4(pow(c,vec3(2.2)),1.);}`});
const swap=[];
function renderAll(){R.shadowMap.needsUpdate=true;R.setRenderTarget(rtC);R.setClearColor(0,0);R.clear();R.render(scene,cam);
 scene.traverse(o=>{if(!o.isMesh||!o.visible)return;if(o.userData.decal){o.visible=false;swap.push([o,null])}else{swap.push([o,o.material]);o.material=o.userData.noEdge?nFlat:nMat}});
 R.shadowMap.needsUpdate=false;R.setRenderTarget(rtN);R.setClearColor(0x808080,0);R.clear();R.render(scene,cam);
 for(const [o,m] of swap){if(m)o.material=m;else o.visible=true}swap.length=0;
 R.setRenderTarget(null);R.setClearColor(0,0);R.clear();R.render(pScene,pCam)}

// ---------- camera: isometric, orthographic ----------
const DIR=new THREE.Vector3(1,.8165,1).normalize();
const BASIS=(()=>{const c=new THREE.OrthographicCamera();c.position.copy(DIR);c.lookAt(0,0,0);c.updateMatrixWorld();return [new THREE.Vector3().setFromMatrixColumn(c.matrixWorld,0),new THREE.Vector3().setFromMatrixColumn(c.matrixWorld,1)]})();
let roomW=15,roomH=12;const fitShift=new THREE.Vector3();
{let x0=1e9,x1=-1e9,y0=1e9,y1=-1e9;for(const x of [-5.7,5.35])for(const y of [-.96,4.5])for(const z of [-5.7,5.35]){const p=new THREE.Vector3(x,y,z);const a=p.dot(BASIS[0]),b=p.dot(BASIS[1]);x0=Math.min(x0,a);x1=Math.max(x1,a);y0=Math.min(y0,b);y1=Math.max(y1,b)}
 roomW=x1-x0;roomH=y1-y0;fitShift.copy(BASIS[0]).multiplyScalar((x0+x1)/2).addScaledVector(BASIS[1],(y0+y1)/2)}
const controls=new OrbitControls(cam,R.domElement);controls.enableDamping=true;controls.dampingFactor=.1;controls.enableRotate=false;controls.enablePan=true;controls.screenSpacePanning=true;controls.mouseButtons={LEFT:THREE.MOUSE.PAN,MIDDLE:THREE.MOUSE.DOLLY,RIGHT:THREE.MOUSE.PAN};controls.touches={ONE:THREE.TOUCH.PAN,TWO:THREE.TOUCH.DOLLY_PAN};controls.zoomSpeed=.8;
let camAnim=null,fitZ=1,zoomGoal=1,Pd=3,cssW=root.clientWidth,cssH=root.clientHeight,rtC=null,rtN=null;
function flyTo(i,instant){const tgt=spaceCenter(i).add(fitShift);const pos=tgt.clone().addScaledVector(DIR,60);zoomGoal=fitZ;
 if(instant||reduce){controls.target.copy(tgt);cam.position.copy(pos);cam.zoom=fitZ;cam.updateProjectionMatrix();controls.update();return}
 camAnim={t0:performance.now(),d:900,fromT:controls.target.clone(),toT:tgt,fromP:cam.position.clone(),toP:pos,fromZ:cam.zoom}}
listen(R.domElement,'wheel',()=>{zoomGoal=null},{passive:true});
{const tp=new Set();listen(R.domElement,'pointerdown',e=>{tp.add(e.pointerId);if(tp.size>1)zoomGoal=null});listen(window,'pointerup',e=>tp.delete(e.pointerId));listen(window,'pointercancel',e=>tp.delete(e.pointerId))}
function sunFollow(){const c=controls.target;sun.position.set(c.x+5,22,c.z+13);sun.target.position.set(c.x,0,c.z);sun.target.updateMatrixWorld()}

const CATS=[['cute','Cute'],['furniture','Furniture'],['storage','Storage'],['robotics','Robotics'],['tools','Tools'],['home','Home'],['garage','Garage']];
const PIECES={
 workbench:{n:'Workbench',cat:'furniture',make:()=>mk.workbench(),c:1,surf:1.6},
 desk:{n:'Desk',cat:'furniture',make:()=>mk.desk(),c:1,surf:1.5},
 table:{n:'Table',cat:'furniture',make:()=>mk.table(3,2,1.5,C.wood),c:1,surf:1.5},
 counter:{n:'Counter',cat:'furniture',make:()=>mk.counter(),c:1,surf:1.72},
 shelf:{n:'Shelf of bins',cat:'furniture',make:()=>{const g=mk.shelf(2.6,3,.9,4);for(let lv=0;lv<3;lv++)g.add(at(mk.bin(.7,.6,.35,[C.blue,C.yellow,C.red][lv]),-.6+lv*.6,.2+lv*.95,0));return g},c:9,u:'bins'},
 drawers:{n:'Parts drawers',cat:'furniture',make:()=>mk.drawers(4,5),c:20,u:'drawers',surf:1.6},
 sawhorse:{n:'Sawhorse',cat:'furniture',make:()=>mk.sawhorse(),c:1,surf:1.22},
 pegboard:{n:'Pegboard',cat:'furniture',make:()=>mk.pegboard(),c:9,u:'tools'},
 fridge:{n:'Fridge',cat:'furniture',make:()=>mk.fridge(),c:1},
 ladder:{n:'Ladder',cat:'furniture',make:()=>mk.ladder(),c:1},
 bin:{n:'Bin of screws',cat:'storage',make:()=>mk.screws(),c:64,small:true},
 emptybin:{n:'Bin',cat:'storage',make:()=>mk.bin(),c:1,small:true},
 box:{n:'Box',cat:'storage',make:()=>mk.box(),c:1,small:true,surf:.72},
 toolbox:{n:'Toolbox',cat:'storage',make:()=>mk.toolbox(),c:1,small:true,surf:.6},
 spices:{n:'Spice rack',cat:'storage',make:()=>mk.spices(),c:14,u:'jars',small:true},
 cans:{n:'Paint cans',cat:'storage',make:()=>mk.cans(),c:4,small:true},
 robot:{n:'Robot',cat:'robotics',make:()=>mk.robot(),c:1},
 servo:{n:'Servo',cat:'robotics',make:()=>mk.servo(),c:1,small:true},
 battery:{n:'Battery',cat:'robotics',make:()=>mk.battery(),c:1,small:true},
 laptop:{n:'Laptop',cat:'robotics',make:()=>mk.laptop(),c:1,small:true},
 spool:{n:'Wire spool',cat:'robotics',make:()=>mk.spool(),c:1,small:true},
 gears:{n:'Gears',cat:'robotics',make:()=>mk.gears(),c:3,small:true},
 drill:{n:'Drill',cat:'tools',make:()=>mk.drill(),c:1,small:true},
 clamps:{n:'Clamps',cat:'tools',make:()=>mk.clamps(),c:3,small:true},
 hexkeys:{n:'Hex keys',cat:'tools',make:()=>mk.hexkeys(),c:7,small:true},
 tape:{n:'Tape measure',cat:'tools',make:()=>mk.tape(),c:1,small:true},
 nails:{n:'Jar of nails',cat:'tools',make:()=>mk.nails(),c:300,small:true},
 lumber:{n:'Boards',cat:'tools',make:()=>mk.lumber(),c:6},
 plant:{n:'Plant',cat:'home',make:()=>mk.plant(),c:1,small:true},
 lamp:{n:'Lamp',cat:'home',make:()=>mk.lamp(),c:1,small:true},
 monitor:{n:'Monitor',cat:'home',make:()=>mk.monitor(),c:1,small:true},
 keyboard:{n:'Keyboard',cat:'home',make:()=>mk.keyboard(),c:1,small:true},
 cables:{n:'Cables',cat:'home',make:()=>mk.cables(),c:4,small:true},
 headphones:{n:'Headphones',cat:'home',make:()=>mk.headphones(),c:1,small:true},
 earbuds:{n:'Earbuds',cat:'home',make:()=>mk.earbuds(),c:1,small:true},
 books:{n:'Books',cat:'home',make:()=>mk.books(),c:6,small:true},
 pens:{n:'Pen cup',cat:'home',make:()=>mk.pens(),c:4,small:true},
 mugs:{n:'Mugs',cat:'home',make:()=>mk.mugs(),c:3,small:true},
 fruit:{n:'Lemons',cat:'home',make:()=>mk.fruit(),c:5,small:true},
 toaster:{n:'Toaster',cat:'home',make:()=>mk.toaster(),c:1,small:true},
 bike:{n:'Bike',cat:'garage',make:()=>mk.bike(),c:1},
 tires:{n:'Tires',cat:'garage',make:()=>mk.tires(),c:3},
 coil:{n:'Extension cord',cat:'garage',make:()=>mk.coil(),c:1,small:true},
 beanbag:{n:'Bean bag',cat:'cute',make:beanbag,c:1},
 rrug:{n:'Round rug',cat:'cute',make:rrug,c:1},
 hrug:{n:'Heart rug',cat:'cute',make:heartRug,c:1},
 bear:{n:'Teddy bear',cat:'cute',make:()=>bear(),c:1,small:true},
 cat:{n:'Sleepy cat',cat:'cute',make:catPet,c:1,small:true},
 duck:{n:'Rubber duck',cat:'cute',make:duck,c:1,small:true},
 mlamp:{n:'Mushroom lamp',cat:'cute',make:mlamp,c:1,small:true},
 vase:{n:'Flowers',cat:'cute',make:vase,c:1,small:true},
 cactus:{n:'Cactus',cat:'cute',make:cactus,c:1,small:true},
 cloud:{n:'Cloud lamp',cat:'cute',make:cloudLamp,c:1,small:true},
 pshelf:{n:'Pastel shelf',cat:'cute',make:pshelf,c:6,u:'bins',surf:1.66},
 printer:{n:'3D printer',cat:'robotics',make:()=>printer(),c:1,small:true},
 arm:{n:'Robot arm cart',cat:'robotics',make:()=>{const g=cart();g.add(at(robotArm(),-.1,1.06,0,.6));return g},c:1},
 rug:{n:'Rug',cat:'home',make:()=>rug(3,2.2,'#e6d6b8','#b1453c'),c:1},
 tallplant:{n:'Big plant',cat:'home',make:()=>tallPlant(),c:1},
};
const KW=[[/screw|bolt|nut|washer|nail/i,'screws'],[/gear|sprocket|pulley/i,'gears'],[/batter/i,'battery'],[/servo|motor/i,'servo'],[/wire|cable|cord|usb/i,'cables'],[/drill|driver/i,'drill'],[/wrench|hex|allen|key/i,'hexkeys'],[/tape/i,'tape'],[/laptop|computer|tablet/i,'laptop'],[/plant/i,'plant'],[/book|notebook/i,'books'],[/mug|cup/i,'mugs'],[/pen|pencil|marker/i,'pens'],[/headphone/i,'headphones'],[/clamp/i,'clamps'],[/spool|filament|solder/i,'spool'],[/lemon|fruit|apple|orange/i,'fruit'],[/paint|spray/i,'cans'],[/toolbox/i,'toolbox']];
// React owns UI, auth, inventory mutations and confirmed persistence.
let visibleItems = new Set();
let current = null, layout = null, build = false, placing = null, ghost = null, generation = 0;
let selected = null, down = null, drag = null, scanState = null, raf = 0;
let roomShell = buildRoom, muted = false, audioContext = null;
const undoStack = [], redoStack = [], objects = [], textures = new Set(), pops = [];
const ray = new THREE.Raycaster(), pointer = new THREE.Vector2();
const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
const snap = value => Math.round(value * 4) / 4;
const ring = new THREE.Mesh(new THREE.RingGeometry(.92, 1, 48), new THREE.MeshBasicMaterial({ color: '#9a4b2c', transparent: true, opacity: .9, side: THREE.DoubleSide }));
ring.rotation.x = -Math.PI / 2; ring.visible = false; ring.userData.noEdge = true; buildGroup.add(ring);
const copy = value => structuredClone(value);
const canonicalKey = item => current.public ? item.id : 'item:' + item.id;

function disposeTree(tree) {
  const sharedGeometry = new Set([...BXC.values(), ICO]);
  const sharedMaterial = new Set([...Object.values(mats), ...Object.values(basics), ...roomMats, skyMat, patchMat]);
  tree.traverse(object => {
    if (object.geometry && !sharedGeometry.has(object.geometry)) object.geometry.dispose();
    for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
      if (!material || sharedMaterial.has(material)) continue;
      if(material.map && ![SKY,wallTex,blockTex,tileTex,bgt,...Object.values(THEME_TEX).flat()].includes(material.map)){material.map.dispose();textures.delete(material.map);}
      material.dispose();
    }
  });
}
function sound(kind) {
  if (muted || disposed) return;
  try {
    audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
    const at = audioContext.currentTime, oscillator = audioContext.createOscillator(), gain = audioContext.createGain();
    oscillator.connect(gain); gain.connect(audioContext.destination);
    const notes = { place: [520, 880, .16, .09], drop: [260, 170, .12, .1], rot: [700, 760, .06, .05], del: [420, 180, .18, .08], undo: [600, 420, .12, .06], lift: [380, 520, .08, .05], tick: [900, 900, .04, .03] };
    const [from, to, duration, volume] = notes[kind] || notes.tick;
    oscillator.type = kind === 'drop' ? 'triangle' : 'sine';
    oscillator.frequency.setValueAtTime(from, at); oscillator.frequency.exponentialRampToValueAtTime(to, at + duration);
    gain.gain.setValueAtTime(volume, at); gain.gain.exponentialRampToValueAtTime(.0001, at + duration + .05);
    oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
    oscillator.start(at); oscillator.stop(at + duration + .08);
  } catch { /* Sound is optional; rendering and confirmed saves still work. */ }
}
function labelModel(item, kind) {
  const model = kind ? mk[kind]() : mk.box();
  if (!kind) {
    const canvas = document.createElement('canvas'); canvas.width = 256; canvas.height = 128;
    const ctx = canvas.getContext('2d'); ctx.fillStyle = '#fff8e9'; ctx.fillRect(0, 0, 256, 128);
    ctx.fillStyle = '#151515'; ctx.font = '20px sans-serif'; ctx.fillText(item.name.slice(0, 22), 10, 100);
    const texture = new THREE.CanvasTexture(canvas); texture.magFilter = THREE.NearestFilter; textures.add(texture);
    const sticker = new THREE.Mesh(new THREE.PlaneGeometry(.78, .4), new THREE.MeshBasicMaterial({ map: texture }));
    sticker.position.set(0, .38, .508); sticker.userData.decal = true; sticker.userData.keep = true; model.add(sticker);
    if (item.photo) {
      const image = new Image();
      const roomGeneration = generation;
      image.crossOrigin = 'anonymous';
      image.onload = () => {
        if (disposed || generation !== roomGeneration) return;
        ctx.drawImage(image, 8, 5, 240, 70); texture.needsUpdate = true; dirty = true;
      };
      image.onerror = () => { /* The actual inventory label remains visible. */ };
      image.src = item.photo;
    }
  }
  return model;
}
function addObject(model, key, kind, record, item, type) {
  bake(model);
  model.position.set(record.x, record.y || 0, record.z);
  model.rotation.y = -(record.r || 0) * Math.PI / 180;
  model.userData = { key, kind, record, item, type, target: model.position.clone(), rotation: model.rotation.y };
  buildGroup.add(model); objects.push(model); return model;
}
function clearScan() {
  if (scanState) for (const [mesh, material] of scanState.meshes) mesh.material = material;
  scanState = null; callbacks.onScanFrame?.(null); dirty = true;
}
function objectBounds(object) {
  // Labels are clickable UI, never a storage surface or a rider's physical bounds.
  const badge = object.userData.storageBadge;
  if (badge) object.remove(badge);
  const box = new THREE.Box3().setFromObject(object);
  if (badge) object.add(badge);
  return box;
}
function setSelection(object) {
  selected = object; ring.visible = !!object;
  if (object) {
    const size = objectBounds(object).getSize(new THREE.Vector3());
    ring.scale.setScalar(Math.max(size.x, size.z) / 2 + .2);
  }
  callbacks.onSelect?.(object ? { id: object.userData.key, kind: object.userData.kind,
    name: object.userData.item?.name || PIECES[object.userData.type]?.n || 'Storage area', t: object.userData.type } : null);
  dirty = true;
}
function paint(index) {
  const theme = THEMES[index] || THEMES[0], [floor, wall] = themeTex(THEMES.indexOf(theme));
  roomMats[0].map = floor; roomMats[1].map = wall; roomMats[2].color.set(theme.cap); roomMats[3].color.set(theme.trim);
  roomMats.forEach(material => { material.needsUpdate = true; }); dirty = true;
}
function rebuild() {
  generation++;
  pops.length = 0;
  clearScan(); setSelection(null);
  for (const object of [...buildGroup.children]) if (object !== ring) { buildGroup.remove(object); disposeTree(object); }
  objects.length = 0; ghost = null; placing = null;
  if (roomShell) { scene.remove(roomShell); disposeTree(roomShell); }
  const sample = current.sample && SP.find(s => s.id === current.sample);
  roomShell = sample ? makeRoom(sample, 0) : makeRoom({ id: 'build', style: { trim: '#6c728a' } }, 0,
    { floorMat: roomMats[0], wallMat: roomMats[1], capMat: roomMats[2], trimMat: roomMats[3] });
  scene.add(roomShell); paint(layout.floor || 0);
  if (sample) {
    sample.items.forEach((source, index) => {
      const item = { id: `sample:${sample.id}:${index}`, name: source.n, quantity: source.c, location: source.place, running_low: !!source.short };
      const position = { x: source.p[0], z: source.p[1], y: source.y || 0, r: -(source.r || 0) * 180 / Math.PI };
      const model = makeItem(source);
      addObject(model, item.id, source.decor ? 'piece' : 'item', position, item, source.k);
    });
  } else {
    layout.pieces.forEach(piece => { if (PIECES[piece.t]) addObject(PIECES[piece.t].make(), piece.id, 'piece', piece, null, piece.t); });
    if (current.public) for (const storage of current.storage || []) {
      const position = layout.places[storage.id]; if (!position) continue;
      const type = storage.kind === 'shelf' ? 'shelf' : storage.kind === 'drawer' || storage.kind === 'cabinet' ? 'drawers' : storage.kind === 'bin' ? 'emptybin' : 'box';
      addObject(PIECES[type].make(), storage.id, 'area', position, { id: storage.id, name: storage.name || 'Storage area' }, type);
    }
    current.storage_areas.forEach(area => {
      const position = layout.places['area:' + area.id]; if (!position) return;
      const type = area.kind === 'shelf' ? 'shelf' : area.kind === 'drawer' || area.kind === 'cabinet' ? 'drawers' : 'box';
      addObject(PIECES[type].make(), 'area:' + area.id, 'area', position, { id: area.id, name: area.name }, type);
    });
    current.bins.forEach(bin => {
      const position = layout.places['bin:' + bin.id]; if (position) addObject(mk.bin(), 'bin:' + bin.id, 'bin', position, { id: bin.id, name: bin.name }, 'emptybin');
    });
    if (!current.public) for (const group of storageGroups(current)) {
      const object = objects.find(o => o.userData.key === group.key);
      if (!object) continue;
      const canvas = document.createElement('canvas'); canvas.width = 512; canvas.height = 80;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#efeeea'; ctx.fillRect(0, 0, 512, 80);
      ctx.strokeStyle = '#151515'; ctx.lineWidth = 8; ctx.strokeRect(0, 0, 512, 80);
      ctx.fillStyle = '#151515'; ctx.font = 'bold 26px monospace'; ctx.textAlign = 'center';
      const label = group.name.length > 23 ? group.name.slice(0, 22) + '…' : group.name;
      ctx.fillText(label + ' · ' + group.items.length + (current.capped ? '+' : ''), 256, 49, 480);
      const texture = new THREE.CanvasTexture(canvas); texture.magFilter = THREE.NearestFilter;
      const badge = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, depthTest: false }));
      const height = objectBounds(object).getSize(new THREE.Vector3()).y;
      badge.position.y = height + .35; badge.scale.set(2.8, .44, 1); badge.renderOrder = 20; object.add(badge); object.userData.storageBadge = badge;
    }
    const displayed = current.public ? current.items : current.items.filter(item => visibleItems.has(item.id));
    const sizeLimit = displayed.length === 1 ? 1.1 : current.items.length > 80 ? .34 : current.items.length > 25 ? .55 : 1.1;
    displayed.forEach(item => {
      const position = layout.places[canonicalKey(item)]; if (!position) return;
      const kind = KW.find(([pattern]) => pattern.test(item.name))?.[1];
      const model = labelModel(item, kind), size = new THREE.Box3().setFromObject(model).getSize(new THREE.Vector3());
      model.scale.setScalar(Math.min(1, sizeLimit / Math.max(size.x, size.z, .1)));
      addObject(model, canonicalKey(item), 'item', position, item, kind || 'box');
    });
  }
  dirty = true;
}
function changed(added = []) { callbacks.onLayout?.(copy(layout), added); dirty = true; }
function historyPush() { undoStack.push(copy(layout)); if (undoStack.length > 80) undoStack.shift(); redoStack.length = 0; }
function undo() { if (!build || !undoStack.length) return; redoStack.push(copy(layout)); layout = undoStack.pop(); rebuild(); changed(); sound('undo'); }
function redo() { if (!build || !redoStack.length) return; undoStack.push(copy(layout)); layout = redoStack.pop(); rebuild(); changed(); sound('undo'); }
function setRay(event) {
  const rect = R.domElement.getBoundingClientRect(); pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1); ray.setFromCamera(pointer, cam);
}
function hit(event) {
  setRay(event); const hits = ray.intersectObjects(objects, true); if (!hits.length) return null;
  let object = hits[0].object; while (object && !objects.includes(object)) object = object.parent; return object;
}
function floor(event) { setRay(event); const result = new THREE.Vector3(); return ray.ray.intersectPlane(plane, result) ? result : null; }
function surface(position, self, excluded = []) {
  let y = 0;
  for (const object of objects) {
    if (object === self || excluded.includes(object)) continue;
    const data = object.userData, height = PIECES[data.type]?.surf;
    if (!height && data.kind !== 'area' && data.kind !== 'bin') continue;
    const box = objectBounds(object);
    if (position.x > box.min.x + .08 && position.x < box.max.x - .08 && position.z > box.min.z + .08 && position.z < box.max.z - .08) y = Math.max(y, box.max.y);
  }
  return Math.min(4.8, y);
}
function setPlacing(type) {
  if (ghost) { buildGroup.remove(ghost); disposeTree(ghost); ghost = null; }
  placing = build && PIECES[type] ? type : null; setSelection(null);
  if (placing) {
    ghost = PIECES[type].make(); ghost.traverse(object => { if (object.isMesh) { object.material = new THREE.MeshLambertMaterial({ color: '#8fb0cf', transparent: true, opacity: .6 }); object.castShadow = false; } });
    ghost.userData.rotation = 0; buildGroup.add(ghost); R.domElement.style.cursor = 'crosshair';
  } else R.domElement.style.cursor = '';
  dirty = true;
}
function place(event) {
  const location = floor(event); if (!location || !placing) return;
  if(layout.pieces.length>=300){callbacks.onError?.('This room has reached its 300-piece limit. Remove a decoration first.');return;}
  historyPush(); const piece = { id: crypto.randomUUID(), t: placing, x: snap(cl(location.x, -4.6, 4.6)), z: snap(cl(location.z, -4.6, 4.6)), r: ghost.userData.rotation || 0, y: 0 };
  piece.y = PIECES[placing].small ? surface(piece, null) : 0;
  layout.pieces.push(piece); rebuild(); const object = objects.find(o => o.userData.key === piece.id); setSelection(object); pop(object); changed([piece.id]); sound('place');
}
function pop(object) { if (!reduce && object) pops.push({ object, start: performance.now(), scale: object.scale.clone() }); }
function scan(object) {
  if (!object || object.userData.kind !== 'item') return;
  if (!current.sample && !current.public && (visibleItems.size !== 1 || !visibleItems.has(object.userData.item.id))) {
    const id = object.userData.item.id; visibleItems = new Set([id]); rebuild();
    object = objects.find(o => o.userData.kind === 'item' && o.userData.item.id === id);
    if (!object) return;
  }
  clearScan(); const meshes = []; object.traverse(mesh => { if (mesh.isMesh) meshes.push([mesh, mesh.material]); });
  const box = objectBounds(object), center = box.getCenter(new THREE.Vector3()), radius = box.getSize(new THREE.Vector3()).length() / 2;
  const distance = cam.position.distanceTo(center); depthMat.uniforms.uMin.value = distance - radius; depthMat.uniforms.uMax.value = distance + radius;
  scanState = { object, meshes, start: performance.now(), top: new THREE.Vector3(center.x, box.max.y, center.z) };
  callbacks.onScan?.(object.userData.item); dirty = true;
}
listen(R.domElement, 'pointerdown', event => {
  down = { x: event.clientX, y: event.clientY }; sound('tick');
  if (!build || placing) return;
  const object = hit(event); if (!object) return;
  controls.enabled = false; setSelection(object);
  const position = floor(event) || object.position;
  const box = objectBounds(object);
  const riders = objects.filter(o => o !== object && o.position.x >= box.min.x && o.position.x <= box.max.x && o.position.z >= box.min.z && o.position.z <= box.max.z && Math.abs(o.position.y - box.max.y) < .25);
  drag = { object, start: copy(layout), moved: false, offsetX: object.position.x - position.x, offsetZ: object.position.z - position.z, riders };
}, { capture: true });
listen(window, 'pointermove', event => {
  if (!build) return;
  if (ghost && event.target === R.domElement) { const p = floor(event); if (p) { ghost.position.set(snap(cl(p.x, -4.6, 4.6)), PIECES[placing].small ? surface(p, null) : 0, snap(cl(p.z, -4.6, 4.6))); dirty = true; } }
  if (!drag || !down) return;
  if (!drag.moved && Math.hypot(event.clientX - down.x, event.clientY - down.y) > 5) { drag.moved = true; sound('lift'); }
  if (!drag.moved) return;
  const p = floor(event); if (!p) return;
  const record = drag.object.userData.record;
  const x = snap(cl(p.x + drag.offsetX, -4.6, 4.6)), z = snap(cl(p.z + drag.offsetZ, -4.6, 4.6));
  const dx = x - record.x, dz = z - record.z;
  record.x = x; record.z = z;
  record.y = drag.object.userData.kind === 'item' || PIECES[drag.object.userData.type]?.small ? surface(record, drag.object, drag.riders) : 0;
  drag.object.position.set(record.x, record.y + (reduce ? 0 : .2), record.z);
  for (const rider of drag.riders) { const value = rider.userData.record; value.x = cl(value.x + dx, -4.8, 4.8); value.z = cl(value.z + dz, -4.8, 4.8); rider.position.set(value.x, value.y, value.z); }
  dirty = true;
});
listen(window, 'pointerup', event => {
  if (drag) {
    const moving = drag; drag = null; controls.enabled = true; down = null;
    if (!moving.moved) return;
    undoStack.push(moving.start); redoStack.length = 0;
    const data = moving.object.userData; moving.object.position.y = data.record.y || 0;
    if (data.kind === 'item') {
      const storage = objects.filter(o => o.userData.kind === 'bin' || o.userData.kind === 'area')
        .find(o => Math.hypot(o.position.x - moving.object.position.x, o.position.z - moving.object.position.z) < .8);
      const destination = storage ? { kind: storage.userData.kind, id: storage.userData.item.id, name: storage.userData.item.name } : null;
      const item = data.item;
      const different = destination ? (destination.kind === 'bin' ? item.bin_id !== destination.id || item.area_id : item.area_id !== destination.id || item.bin_id) : item.bin_id || item.area_id;
      if (different) { callbacks.onMove?.(item, destination, copy(layout), copy(moving.start)); dirty = true; return; }
    }
    changed(); sound('drop'); return;
  }
  if (!down) return;
  const moved = Math.hypot(event.clientX - down.x, event.clientY - down.y); down = null;
  if (moved > 7 || event.target !== R.domElement) return;
  if (build) { if (placing) place(event); else setSelection(hit(event)); }
  else { const object = hit(event); if (object?.userData.kind === 'item') { if (callbacks.onTap?.(object.userData.item) !== false) scan(object); } else if (object && !current.public && ['bin', 'area'].includes(object.userData.kind)) callbacks.onStorage?.(object.userData.key); }
});
listen(window, 'pointercancel', () => { if (drag) { layout = drag.start; drag = null; controls.enabled = true; rebuild(); } down = null; });
function rotate(direction) {
  if (!build) return;
  if (ghost) { ghost.userData.rotation = ((ghost.userData.rotation || 0) + direction * 45 + 360) % 360; ghost.rotation.y = -ghost.userData.rotation * Math.PI / 180; }
  else if (selected) { historyPush(); const record = selected.userData.record; record.r = ((record.r || 0) + direction * 45 + 360) % 360; selected.rotation.y = -record.r * Math.PI / 180; changed(); }
  sound('rot'); dirty = true;
}
function duplicate() {
  if (!build || selected?.userData.kind !== 'piece' || layout.pieces.length >= 300) return;
  historyPush(); const piece = { ...selected.userData.record, id: crypto.randomUUID() };
  piece.x = cl(piece.x + .75, -4.6, 4.6); piece.z = cl(piece.z + .75, -4.6, 4.6); layout.pieces.push(piece);
  rebuild(); const object = objects.find(o => o.userData.key === piece.id); setSelection(object); pop(object); changed([piece.id]); sound('place');
}
function remove() {
  if (!build || selected?.userData.kind !== 'piece') return;
  historyPush(); layout.pieces = layout.pieces.filter(p => p.id !== selected.userData.key); rebuild(); changed(); sound('del');
}
listen(root, 'keydown', event => {
  if (!build || /INPUT|TEXTAREA|SELECT/.test(event.target.tagName) || event.target.closest('[role=dialog]')) return;
  if (event.key === 'Escape') { setPlacing(null); setSelection(null); }
  else if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') { event.preventDefault(); if (event.shiftKey) redo(); else undo(); }
  else if (event.key.toLowerCase() === 'r') rotate(event.shiftKey ? -1 : 1);
  else if (event.key.toLowerCase() === 'd') duplicate();
  else if (event.key === 'Delete' || event.key === 'Backspace') { event.preventDefault(); remove(); }
});

function sizeAll() {
  const w = Math.max(1, Math.round(root.clientWidth)), h = Math.max(1, Math.round(root.clientHeight)), dpr = Math.min(devicePixelRatio || 1, 3);
  const compact = root.getAttribute('data-layout') === 'compact';
  const side = compact ? ((w > 600 || h <= 520) && root.hasAttribute('data-side') ? (root.querySelector('.world-purpose,.world-contents,.card:not(.world-dialog),.bbar')?.getBoundingClientRect().width || 280) + 20 : 0) : h <= 520 && w >= 600 && build ? 300 : 0, ppu = Math.min((w - side - 24) / roomW, h * .74 / roomH);
  Pd = Math.max(1, Math.round(roomW * ppu * dpr / 820));
  cssW = w; cssH = h; const DW = Math.round(w * dpr), DH = Math.round(h * dpr);
  const W = Math.ceil(DW / Pd), H = Math.ceil(DH / Pd);
  R.setSize(DW, DH, false); R.domElement.style.width = w + 'px'; R.domElement.style.height = h + 'px';
  post.uniforms.px.value = Pd; post.uniforms.th.value = Math.max(1, Math.min(3, Math.round(2 * dpr / Pd))); post.uniforms.off.value.set(0, DH - H * Pd);
  cam.left = -VIEW_H * (W / H) / 2; cam.right = -cam.left; cam.top = VIEW_H / 2; cam.bottom = -VIEW_H / 2;
  if (rtC) { rtC.depthTexture?.dispose(); rtC.dispose(); rtN.dispose(); }
  const options = { minFilter: THREE.NearestFilter, magFilter: THREE.NearestFilter };
  rtC = new THREE.WebGLRenderTarget(W, H, { ...options, depthTexture: new THREE.DepthTexture(W, H) }); rtN = new THREE.WebGLRenderTarget(W, H, options);
  post.uniforms.tC.value = rtC.texture; post.uniforms.tD.value = rtC.depthTexture; post.uniforms.tN.value = rtN.texture; post.uniforms.res.value.set(W, H); post.uniforms.span.value = cam.far - cam.near;
  const top = root.querySelector('[data-world-top]')?.offsetHeight || 110;
  const bottom = root.querySelector('[data-world-bottom]')?.offsetHeight || 80;
  root.style.setProperty('--tb', Math.round(top) + 'px');
  if (compact) root.style.setProperty('--bb', Math.round(bottom) + 'px');
  fitZ = Math.min(Math.max(120, w - side - 28) / roomW, Math.max(120, h - top - bottom - 18) / roomH) * VIEW_H / h;
  controls.minZoom = fitZ * .75; controls.maxZoom = fitZ * 3.2;
  if (zoomGoal != null) zoomGoal = fitZ;
  cam.setViewOffset(w, h, Math.round(side / 2), Math.round((bottom - top) / 2), w, h);
  cam.updateProjectionMatrix(); dirty = true;
}
function updateScan(now) {
  if (!scanState) return false;
  const time = reduce ? 3 : (now - scanState.start) / 1000;
  for (const [mesh, material] of scanState.meshes) mesh.material = time >= .55 && time < 1.6 ? depthMat : material;
  const box = new THREE.Box3().setFromObject(scanState.object), points = [];
  for (const x of [box.min.x, box.max.x]) for (const y of [box.min.y, box.max.y]) for (const z of [box.min.z, box.max.z]) points.push(new THREE.Vector3(x, y, z).project(cam));
  const xs = points.map(p => (p.x + 1) / 2 * cssW), ys = points.map(p => (1 - p.y) / 2 * cssH), top = scanState.top.clone().project(cam);
  callbacks.onScanFrame?.({ phase: time < .55 ? 0 : time < 1.25 ? 1 : time < 1.65 ? 2 : 3,
    x: (top.x + 1) / 2 * cssW, y: (1 - top.y) / 2 * cssH,
    box: { left: Math.min(...xs) - 10, top: Math.min(...ys) - 10, width: Math.max(...xs) - Math.min(...xs) + 20, height: Math.max(...ys) - Math.min(...ys) + 20 },
    brackets: time < 2.6 });
  return time < 2.6;
}
function frame(now) {
  if (disposed || document.hidden) { raf = 0; return; }
  raf = requestAnimationFrame(frame);
  if (camAnim) { const p = eio((now - camAnim.t0) / camAnim.d); controls.target.lerpVectors(camAnim.fromT, camAnim.toT, p); cam.position.lerpVectors(camAnim.fromP, camAnim.toP, p); cam.zoom = camAnim.fromZ + (fitZ - camAnim.fromZ) * p; cam.updateProjectionMatrix(); if (p >= 1) camAnim = null; dirty = true; }
  else if (zoomGoal != null && Math.abs(cam.zoom - zoomGoal) > .0005) { cam.zoom += (zoomGoal - cam.zoom) * (reduce ? 1 : .2); cam.updateProjectionMatrix(); dirty = true; }
  controls.update();
  for (let i = pops.length - 1; i >= 0; i--) {
    const entry = pops[i], t = cl((now - entry.start) / 420), scale = t === 1 ? 1 : 1 + Math.sin(t * Math.PI) * .22;
    entry.object.scale.copy(entry.scale).multiplyScalar(scale); dirty = true;
    if (t === 1) pops.splice(i, 1);
  }
  if (selected && ring.visible) ring.position.set(selected.position.x, (selected.userData.record.y || 0) + .02, selected.position.z);
  if (scanState && (dirty || now - scanState.start < 2700)) { if (updateScan(now)) dirty = true; }
  if (dirty) { sunFollow(); renderAll(); dirty = false; }
}
controls.addEventListener('change', () => { dirty = true; });
const observer = new ResizeObserver(sizeAll); observer.observe(root);
const panelObserver = new MutationObserver(() => { if (!disposed) sizeAll(); });
if (root.getAttribute('data-layout') === 'compact') panelObserver.observe(root, { attributes: true, attributeFilter: ['data-side'] });
for (const element of root.querySelectorAll('[data-world-top],[data-world-bottom]')) observer.observe(element);
listen(document, 'visibilitychange', () => { if (document.hidden) { cancelAnimationFrame(raf); raf = 0; } else if (!raf) { dirty = true; raf = requestAnimationFrame(frame); } });
sizeAll(); flyTo(0, true); raf = requestAnimationFrame(frame);

function catalog() {
  const renderer = new THREE.WebGLRenderer({ antialias: false, alpha: true, preserveDrawingBuffer: true });
  renderer.setSize(120, 100); renderer.setPixelRatio(1); renderer.outputColorSpace = THREE.SRGBColorSpace;
  const thumbnail = make => {
    const scene2 = new THREE.Scene(); scene2.add(new THREE.HemisphereLight('#f4f7ff', '#8d92a2', 1.75));
    const light = new THREE.DirectionalLight('#fff4e2', 1.9); light.position.set(5, 22, 13); scene2.add(light);
    const object = make(); scene2.add(object); const box = objectBounds(object), center = box.getCenter(new THREE.Vector3()), radius = box.getSize(new THREE.Vector3()).length() / 2;
    const camera = new THREE.OrthographicCamera(-radius * 1.2, radius * 1.2, radius, -radius, .1, 100); camera.position.copy(center).addScaledVector(DIR, 30); camera.lookAt(center);
    renderer.render(scene2, camera); const result = renderer.domElement.toDataURL('image/png'); disposeTree(object); return result;
  };
  try {
    return { categories: CATS, pieces: Object.entries(PIECES).map(([id, piece]) => ({ id, name: piece.n, category: piece.cat, image: thumbnail(piece.make) })),
      themes: THEMES.map((theme, id) => ({ id, name: theme.n, level: theme.lv || 1, image: themePrev(id) })),
      bolt: thumbnail(() => { const object = mk.robot(); object.rotation.y = -.6; return object; }), samples: SP.map(s => ({ id: s.id, name: s.label })) };
  } finally { renderer.dispose(); renderer.forceContextLoss(); }
}
try{callbacks.onReady?.(catalog())}catch{callbacks.onReady?.({categories:CATS,pieces:Object.entries(PIECES).map(([id,p])=>({id,name:p.n,category:p.cat,image:''})),themes:THEMES.map((t,id)=>({id,name:t.n,level:t.lv||1,image:themePrev(id)})),bolt:'',samples:SP.map(s=>({id:s.id,name:s.label}))})}
return {
  load(room, value) { if (disposed) return; current = room; visibleItems = new Set(); layout = copy(value); undoStack.length = redoStack.length = 0; rebuild(); sizeAll(); flyTo(0, true); },
  setMode(value) { build = !!value && !!current?.can_edit && !current?.public && !current?.sample; buildGrid.visible = build; setPlacing(null); clearScan(); setSelection(null); sizeAll(); if (root.getAttribute('data-layout') === 'compact') requestAnimationFrame(() => { if (!disposed) sizeAll(); }); },
  setPlacing, rotate, duplicate, remove, undo, redo, clearScan,
  focusItems(ids, storageKey) { if (!current || current.sample || current.public) return; visibleItems = new Set(ids.slice(0, 12)); rebuild(); if (storageKey) setSelection(objects.find(o => o.userData.key === storageKey) || null); },
  scan(id) { if (current && !current.public && !current.sample && !visibleItems.has(id)) { visibleItems = new Set([id]); rebuild(); } scan(objects.find(o => o.userData.item?.id === id)); },
  pop(id) { pop(objects.find(o => o.userData.item?.id === id)); },
  setFloor(index) { if (!build) return; historyPush(); layout.floor = index; paint(index); changed(); },
  setMuted(value) { muted = value; },
  dispose() {
    if (disposed) return; disposed = true; cancelAnimationFrame(raf); observer.disconnect(); panelObserver.disconnect(); listeners.forEach(remove => remove()); controls.dispose();
    clearScan(); disposeTree(scene); disposeTree(pScene);
    BXC.forEach(geometry => geometry.dispose()); ICO.dispose(); Object.values(mats).forEach(m => m.dispose()); Object.values(basics).forEach(m => m.dispose()); roomMats.forEach(m => m.dispose());
    const texturesToDispose = new Set([GRAD, SKY, wallTex, blockTex, tileTex, bgt, ...textures, ...Object.values(THEME_TEX).flat()]); texturesToDispose.forEach(t => t.dispose());
    post.dispose(); nMat.dispose(); nFlat.dispose(); depthMat.dispose(); skyMat.dispose(); patchMat.dispose(); ring.geometry.dispose(); ring.material.dispose();
    rtC?.depthTexture?.dispose(); rtC?.dispose(); rtN?.dispose(); sun.shadow.map?.dispose(); R.dispose(); R.forceContextLoss(); R.domElement.remove(); void audioContext?.close();
  },
};
}
