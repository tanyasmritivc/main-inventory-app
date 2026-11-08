/* extra part models for the workshop, makerspace and lab pages (same look as the robotics parts) */
export function extraParts(THREE,M,mesh,ext,gearShape,hexShape,materials){
 const mat=(c,met,rough,extra)=>{const m=new THREE.MeshStandardMaterial(Object.assign({color:c,metalness:met,roughness:rough},extra||{}));m.envMapIntensity=.5;return m};
 const C={rose:mat(0xD9668A,0,.45),roseD:mat(0x8E3550,0,.5),amber:mat(0xC9611F,0,.62),gold:mat(0xC9A35A,1,.28),pcb:mat(0x0F5A50,.1,.45),pcbB:mat(0x1D3F7A,.1,.45),chip:mat(0x101012,.2,.4),silver:mat(0xd6d9de,1,.2),
  red:mat(0xB8343A,0,.4),blk:mat(0x141416,0,.55),grey:mat(0x4a4a50,0,.55),white:mat(0xf0f0ee,0,.45),glass:mat(0x111418,.1,.05),kapton:mat(0xC9802F,0,.35,{transparent:true,opacity:.92}),copper:mat(0xC87E52,1,.3),
  ledR:new THREE.MeshPhysicalMaterial({color:0xF2537A,roughness:.15,transmission:0,transparent:true,opacity:.85,emissive:0x5a1020,envMapIntensity:.6})};
 Object.values(C).forEach(m=>materials.add(m));
 const G=()=>new THREE.Group();
 const cyl=(r,h,m,seg=36,r2)=>mesh(new THREE.CylinderGeometry(r2??r,r,h,seg),m);
 const box=(w,h,d,m)=>mesh(new THREE.BoxGeometry(w,h,d),m);
 // twist an extruded profile around its length to make flutes
 function fluted(n,r,len,turns,m){const s=new THREE.Shape();const st=n*16;for(let i=0;i<=st;i++){const a=i/st*Math.PI*2;const k=(i%16)/16;const rr=r*(k<.55?1:.55+.45*Math.abs(Math.cos(k*Math.PI)));i?s.lineTo(Math.cos(a)*rr,Math.sin(a)*rr):s.moveTo(Math.cos(a)*rr,Math.sin(a)*rr)}
  const g=new THREE.ExtrudeGeometry(s,{depth:len,steps:40,bevelEnabled:false});g.center();const p=g.attributes.position;for(let i=0;i<p.count;i++){const z=p.getZ(i),x=p.getX(i),y=p.getY(i);const a=(z/len)*turns*Math.PI*2;p.setXY(i,x*Math.cos(a)-y*Math.sin(a),x*Math.sin(a)+y*Math.cos(a))}g.computeVertexNormals();return mesh(g,m)}
 const ctex=(w,h,draw)=>{const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.encoding=THREE.sRGBEncoding;t.anisotropy=4;return t};
 return {
 /* workshop */
 collet(){const pts=[[0,-.45],[.2,-.45],[.26,-.2],[.26,.05],[.17,.45],[0,.45]].map(([x,y])=>new THREE.Vector2(x,y));const g=G();const b=mesh(new THREE.LatheGeometry(pts,48),M.steel);g.add(b);
  for(let i=0;i<8;i++){const sl=box(.02,.5,.08,C.blk);const a=i/8*Math.PI*2;sl.position.set(Math.cos(a)*.22,(i%2?.18:-.18),Math.sin(a)*.22);sl.rotation.y=-a;g.add(sl)}const bore=cyl(.07,.92,C.blk,24);g.add(bore);return g},
 endmill(){const g=G();const sh=cyl(.1,.8,M.steel,32);sh.position.y=.4;g.add(sh);const f=fluted(4,.1,.75,.7,M.steel);f.rotation.x=Math.PI/2;f.position.y=-.38;g.add(f);return g},
 drill(){const g=G();const sh=cyl(.065,.55,C.gold,28);sh.position.y=.45;g.add(sh);const f=fluted(2,.065,.95,1.6,C.gold);f.rotation.x=Math.PI/2;f.position.y=-.3;g.add(f);const tip=cyl(.0,.12,C.gold,28,.065);tip.position.y=-.84;g.add(tip);return g},
 spool(){const g=G();[-.2,.2].forEach(z=>{const d=cyl(.55,.04,C.blk,56);d.rotation.x=Math.PI/2;d.position.z=z;g.add(d)});const fil=cyl(.44,.36,C.rose,56);fil.rotation.x=Math.PI/2;g.add(fil);
  for(let i=0;i<14;i++){const r=new THREE.Mesh(new THREE.TorusGeometry(.44,.012,6,64),C.roseD);r.position.z=-.17+i*.026;g.add(r)}const hub=cyl(.16,.44,C.grey,32);hub.rotation.x=Math.PI/2;g.add(hub);return g},
 nozzle(){const g=G();const hx=mesh(ext(hexShape(.16),.14,.01),C.gold);hx.rotation.x=Math.PI/2;g.add(hx);const th=cyl(.09,.26,C.gold,24);th.position.y=.2;g.add(th);const tip=cyl(.03,.14,C.gold,24,.12);tip.position.y=-.14;g.add(tip);return g},
 hexkey(){const g=G();const a=mesh(ext(hexShape(.05),1.1,.006),C.blk);a.position.z=0;g.add(a);const b=mesh(ext(hexShape(.05),.38,.006),C.blk);b.rotation.y=Math.PI/2;b.position.set(.17,0,.55);g.add(b);return g},
 bolt(){const g=G();const h=mesh(ext(hexShape(.15),.12,.01),M.steel);h.rotation.x=Math.PI/2;h.position.y=.42;g.add(h);const pts=[new THREE.Vector2(0,-.48)];for(let y=-.48;y<.36;y+=.05)pts.push(new THREE.Vector2(.075,y),new THREE.Vector2(.09,y+.025));pts.push(new THREE.Vector2(0,.36));g.add(mesh(new THREE.LatheGeometry(pts,24),M.steel));return g},
 /* makerspace */
 multimeter(){const g=G();const body=mesh(new THREE.BoxGeometry(.72,1.1,.2),C.amber);g.add(body);const face=box(.6,.98,.03,C.blk);face.position.z=.105;g.add(face);
  const scr=box(.48,.26,.02,C.glass);scr.position.set(0,.28,.125);g.add(scr);const dig=new THREE.Mesh(new THREE.PlaneGeometry(.42,.18),new THREE.MeshBasicMaterial({map:ctex(256,110,(x,w,h)=>{x.fillStyle='#9fb39a';x.fillRect(0,0,w,h);x.fillStyle='#1d2420';x.font='bold 74px monospace';x.textAlign='center';x.fillText('12.04',w/2,84)})}));dig.position.set(0,.28,.137);g.add(dig);
  const dial=cyl(.17,.06,C.grey,36);dial.rotation.x=Math.PI/2;dial.position.set(0,-.12,.13);g.add(dial);const ptr=box(.03,.14,.02,C.white);ptr.position.set(0,-.07,.17);g.add(ptr);
  [-.18,0,.18].forEach((x,i)=>{const j=cyl(.04,.04,i===0?C.red:C.blk,20);j.rotation.x=Math.PI/2;j.position.set(x,-.4,.13);g.add(j)});return g},
 arduino(){const g=G();const tex=ctex(256,180,(x,w,h)=>{x.fillStyle='#0f5a50';x.fillRect(0,0,w,h);x.strokeStyle='rgba(200,230,220,.35)';x.lineWidth=2;for(let i=0;i<14;i++){x.beginPath();x.moveTo(20+i*15,40);x.lineTo(30+i*15,120);x.stroke()}x.fillStyle='rgba(220,240,235,.8)';x.font='bold 18px sans-serif';x.fillText('UNO',190,160)});
  const b=mesh(new THREE.BoxGeometry(1.0,.04,.72),[C.pcb,C.pcb,new THREE.MeshStandardMaterial({map:tex,roughness:.45}),C.pcb,C.pcb,C.pcb]);g.add(b);
  const chip=box(.42,.05,.1,C.chip);chip.position.set(.1,.045,.12);g.add(chip);const usb=box(.2,.12,.18,C.silver);usb.position.set(-.42,.08,-.2);g.add(usb);const jack=box(.18,.14,.14,C.blk);jack.position.set(-.42,.09,.22);g.add(jack);
  [[-.05,-.33],[.1,.33]].forEach(([x,z])=>{const h=box(.62,.1,.05,C.blk);h.position.set(x,.07,z);g.add(h)});return g},
 breadboard(){const tex=ctex(256,170,(x,w,h)=>{x.fillStyle='#f2f1ec';x.fillRect(0,0,w,h);x.fillStyle='#55575c';for(let r=0;r<14;r++)for(let c=0;c<30;c++){if(r===6||r===7)continue;x.fillRect(8+c*8.2,12+r*11,3,3)}x.fillStyle='#d9534f';x.fillRect(6,4,w-12,2);x.fillStyle='#3d6fd1';x.fillRect(6,h-6,w-12,2)});
  return mesh(new THREE.BoxGeometry(1.1,.1,.74),[C.white,C.white,new THREE.MeshStandardMaterial({map:tex,roughness:.5}),C.white,C.white,C.white])},
 iron(){const g=G();const h=cyl(.09,.6,C.blk,28);h.position.y=.3;g.add(h);const grip=cyl(.1,.32,C.rose,28);grip.position.y=.12;g.add(grip);const sh=cyl(.035,.5,M.steel,20);sh.position.y=-.3;g.add(sh);const tip=cyl(.004,.16,C.copper,20,.035);tip.position.y=-.62;g.add(tip);const cb=cyl(.03,.3,C.grey,12);cb.position.y=.75;g.add(cb);return g},
 led(){const g=G();const d=cyl(.1,.16,C.ledR,24);g.add(d);const top=mesh(new THREE.SphereGeometry(.1,24,12,0,Math.PI*2,0,Math.PI/2),C.ledR);top.position.y=.08;g.add(top);const rim=cyl(.115,.03,C.ledR,24);rim.position.y=-.08;g.add(rim);
  [-.035,.035].forEach((x,i)=>{const l=cyl(.008,i?.5:.42,C.silver,8);l.position.set(x,i?-.33:-.29,0);g.add(l)});return g},
 wires(){const g=G();[[C.red,0],[C.blk,.08],[C.rose,.16]].forEach(([m,o])=>{const cv=new THREE.CatmullRomCurve3([new THREE.Vector3(-.6,o,0),new THREE.Vector3(-.2,.3+o,.2),new THREE.Vector3(.2,-.2+o,-.1),new THREE.Vector3(.6,.1+o,.1)]);g.add(mesh(new THREE.TubeGeometry(cv,48,.03,10),m));
  [-.6,.6].forEach(x=>{const e=cyl(.04,.14,C.blk,12);e.position.set(x,(x<0?o:.1+o),x<0?0:.1);e.rotation.z=Math.PI/2;g.add(e)})});return g},
 screwdriver(){const g=G();const h=cyl(.12,.42,C.rose,6);h.position.y=.32;g.add(h);const cap=cyl(.1,.06,C.blk,24);cap.position.y=.55;g.add(cap);const sh=cyl(.035,.6,M.steel,16);sh.position.y=-.18;g.add(sh);const tip=box(.07,.08,.015,M.steel);tip.position.y=-.5;g.add(tip);return g},
 /* lab */
 probe(){const g=G();const body=cyl(.07,.6,C.grey,24);body.position.y=.1;g.add(body);const ring=cyl(.08,.06,C.blk,24);ring.position.y=-.15;g.add(ring);const tip=cyl(.01,.22,M.steel,12,.04);tip.position.y=-.3;g.add(tip);
  const cv=new THREE.CatmullRomCurve3([new THREE.Vector3(0,.4,0),new THREE.Vector3(.1,.7,.1),new THREE.Vector3(.5,.6,-.1),new THREE.Vector3(.7,.2,0)]);g.add(mesh(new THREE.TubeGeometry(cv,40,.03,10),C.blk));const bnc=cyl(.06,.14,M.chrome,24);bnc.position.set(.7,.12,0);g.add(bnc);return g},
 gauge(){const tex=ctex(200,260,(x,w,h)=>{x.fillStyle='#c9802f';x.fillRect(0,0,w,h);x.strokeStyle='#e8c99a';x.lineWidth=5;x.beginPath();let y=40;x.moveTo(40,y);for(let i=0;i<9;i++){x.lineTo(160,y);y+=18;x.lineTo(160,y);x.lineTo(40,y);y+=0}x.stroke();x.fillStyle='#e8c99a';x.fillRect(50,214,40,30);x.fillRect(110,214,40,30)});
  const g=G();g.add(mesh(new THREE.BoxGeometry(.5,.012,.66),[C.kapton,C.kapton,new THREE.MeshStandardMaterial({map:tex,roughness:.3,metalness:.2}),C.kapton,C.kapton,C.kapton]));
  [-.07,.07].forEach(x=>{const w=cyl(.008,.5,C.copper,8);w.rotation.x=Math.PI/2;w.position.set(x,.01,.55);g.add(w)});return g},
 sensor(){const g=G();g.add(box(.6,.04,.44,C.pcbB));const c=box(.16,.05,.16,C.chip);c.position.set(.08,.045,0);g.add(c);const h=box(.05,.1,.36,C.blk);h.position.set(-.25,.07,0);g.add(h);return g},
 bnc(){const g=G();const b=cyl(.09,.3,M.chrome,32);g.add(b);const r=new THREE.Mesh(new THREE.TorusGeometry(.1,.025,10,32),M.chrome);r.rotation.x=Math.PI/2;r.position.y=.08;g.add(r);const pin=cyl(.015,.12,C.gold,10);pin.position.y=.2;g.add(pin);const nut=mesh(ext(hexShape(.13),.06,.006),M.steel);nut.rotation.x=Math.PI/2;nut.position.y=-.12;g.add(nut);return g},
 caliper(){const g=G();const bar=box(1.5,.06,.22,M.steel);g.add(bar);const j1=box(.08,.06,.42,M.steel);j1.position.set(-.71,0,-.3);g.add(j1);const sl=box(.32,.08,.3,M.steel);sl.position.set(-.3,.01,0);g.add(sl);const j2=box(.08,.06,.42,M.steel);j2.position.set(-.42,0,-.3);g.add(j2);
  const tex=ctex(512,40,(x,w,h)=>{x.fillStyle='#d6d9de';x.fillRect(0,0,w,h);x.fillStyle='#333';for(let i=0;i<100;i++){x.fillRect(i*5,0,1,i%10?12:22)}});const sc=new THREE.Mesh(new THREE.PlaneGeometry(1.4,.12),new THREE.MeshBasicMaterial({map:tex}));sc.rotation.x=-Math.PI/2;sc.position.set(.02,.031,.03);g.add(sc);return g},
 banana(){const g=G();const b=cyl(.07,.36,C.red,24);g.add(b);const pin=cyl(.025,.24,C.gold,12);pin.position.y=-.3;g.add(pin);const cv=new THREE.CatmullRomCurve3([new THREE.Vector3(0,.18,0),new THREE.Vector3(0,.5,.1),new THREE.Vector3(.3,.7,0)]);g.add(mesh(new THREE.TubeGeometry(cv,24,.025,8),C.red));return g},
 beaker(){const g=G();const gl=new THREE.MeshPhysicalMaterial({color:0xffffff,roughness:.05,transparent:true,opacity:.22,metalness:0,envMapIntensity:.9,side:THREE.DoubleSide});const w=mesh(new THREE.CylinderGeometry(.3,.3,.7,40,1,true),gl);g.add(w);const bt=mesh(new THREE.CircleGeometry(.3,40),gl);bt.rotation.x=-Math.PI/2;bt.position.y=-.35;g.add(bt);
  const liq=mesh(new THREE.CylinderGeometry(.28,.28,.3,40),new THREE.MeshPhysicalMaterial({color:0xE8789A,transparent:true,opacity:.55,roughness:.1}));liq.position.y=-.19;g.add(liq);for(let i=0;i<4;i++){const m=box(.08,.006,.006,C.white);m.position.set(.27,-.1+i*.1,.1);m.rotation.y=-.3;g.add(m)}return g}
 }};
