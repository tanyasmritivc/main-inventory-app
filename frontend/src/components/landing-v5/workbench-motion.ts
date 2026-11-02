const objects: [string,number,[number,number,number,number]][] = [
 ['black wheels',3,[0,660,152,905]],['stacked bins',1,[10,380,362,662]],['brass gears',4,[400,505,572,592]],['hex screws',20,[495,385,615,492]],['socket head screws',12,[530,715,765,865]],['gearbox housing',4,[855,770,1290,945]],['battery charger',1,[765,425,1200,660]],['lock washers',60,[1370,830,1600,965]],['bagged parts',3,[150,578,425,805]],['duct tape',1,[575,535,772,650]],
];
const examples=['Garage workbench: charger, gearbox, socket screws','Parts drawer: 48 bearings, 60 washers, M4 screws','Kitchen pantry: rice, pasta, olive oil'];
/** Decorative sample animation. Active time freezes while off screen. */
export function startWorkbenchMotion(hero:HTMLElement,input:HTMLTextAreaElement,focused:()=>boolean){
 const host=hero.querySelector<HTMLElement>('.wb-boxes')!,center=hero.querySelector<HTMLElement>('.wb-center')!;
 const media=matchMedia('(prefers-reduced-motion: reduce)');
 let boxes:HTMLElement[]=[],frame=0,elapsed=0,previous=0,visible=true,disposed=false;
 function place(){
  const h=hero.getBoundingClientRect(),c=center.getBoundingClientRect(),W=h.width,H=h.height;if(!W||!H)return;
  const k=Math.max(W/1600,H/1200)*1.04,ox=(W-1600*k)*.5,oy=(H-1200*k)*.72;
  const safe={l:c.left-h.left-24,r:c.right-h.left+24,t:c.top-h.top-16,b:c.bottom-h.top+4};
  host.replaceChildren();boxes=[];
  for(const [name,count,[x1,y1,x2,y2]] of objects){
   const l=Math.max(28,ox+x1*k),r=Math.min(W-28,ox+x2*k),b=Math.min(H-28,oy+y2*k);let t=Math.max(196,oy+y1*k);
   if((t+b)/2>safe.b&&l<safe.r&&r>safe.l)t=Math.max(t,safe.b+14);
   const w=r-l,height=b-t;if(w<60||height<50)continue;
   const overlap=Math.max(0,Math.min(r,safe.r)-Math.max(l,safe.l))*Math.max(0,Math.min(b,safe.b)-Math.max(t,safe.t-60));
   if(overlap>w*height*.45)continue;
   const box=document.createElement('div');box.className='wb-box';Object.assign(box.style,{left:`${l}px`,top:`${t}px`,width:`${w}px`,height:`${height}px`});
   const label=document.createElement('em');label.textContent=`${name} · ${count}`;if(t>safe.b-60&&t<safe.b+34)label.className='wb-label-below';
   box.append(label);host.append(box);
   if(label.getBoundingClientRect().right>h.right-28){label.style.left='auto';label.style.right='-1.5px';}
   if(label.getBoundingClientRect().bottom>h.bottom-28){label.style.top='auto';label.style.bottom='4px';}
   const lr=label.getBoundingClientRect();if(lr.right>c.left&&lr.left<c.right&&lr.bottom>c.top&&lr.top<c.bottom){box.remove();continue;}boxes.push(box);
  }
 }
 function tick(time:number){
  if(disposed)return;if(previous)elapsed+=time-previous;previous=time;
  const latest=Math.floor((elapsed-1200)/1500);
  boxes.forEach((box,i)=>{const occurrence=latest-((latest-i)%boxes.length+boxes.length)%boxes.length;box.classList.toggle('on',occurrence>=0&&elapsed-(1200+occurrence*1500)<2900);});
  if(media.matches)input.placeholder='Describe your inventory';
  else if(!focused()&&!input.value&&elapsed>=1200){
   let phase=(elapsed-1200)%examples.reduce((n,s)=>n+s.length*38+2700,0);
   for(const text of examples){const total=text.length*38+2700;if(phase>=total){phase-=total;continue;}
    const typing=text.length*28,length=phase<typing?Math.floor(phase/28)+1:phase<typing+2400?text.length:Math.max(0,text.length-Math.floor((phase-typing-2400)/10));input.placeholder=text.slice(0,length)||' ';break;
   }
  }frame=requestAnimationFrame(tick);
 }
 function sync(){cancelAnimationFrame(frame);previous=0;const active=visible&&!document.hidden&&!disposed;hero.dataset.active=String(active);if(media.matches)input.placeholder='Describe your inventory';if(active)frame=requestAnimationFrame(tick);}
 const observer=typeof IntersectionObserver==='undefined'?null:new IntersectionObserver(entries=>{visible=entries[0].isIntersecting;sync();});observer?.observe(hero);
 const resize=typeof ResizeObserver==='undefined'?null:new ResizeObserver(place);resize?.observe(hero);resize?.observe(center);
 window.addEventListener('resize',place);document.addEventListener('visibilitychange',sync);media.addEventListener?.('change',sync);place();sync();document.fonts?.ready.then(()=>{if(!disposed)place();});
 return()=>{disposed=true;cancelAnimationFrame(frame);observer?.disconnect();resize?.disconnect();window.removeEventListener('resize',place);document.removeEventListener('visibilitychange',sync);media.removeEventListener?.('change',sync);host.replaceChildren();};
}
