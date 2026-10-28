"use client";
import { useEffect, useRef, type ReactNode, type RefObject } from "react";
const curve="cubic-bezier(.32,.72,0,1)";
const clamp=(v:number)=>Math.max(0,Math.min(1,v));
/** One scheduler for scroll, typing, audience rotation and price interpolation.
 * CSS loops pause offscreen; no per-frame React updates. Server output stays readable. */
export function useScrollFrame(root:RefObject<HTMLDivElement|null>,page:string){
 useEffect(()=>{
  const el=root.current;if(!el)return;
  const reduced=window.matchMedia?.("(prefers-reduced-motion: reduce)") ?? {matches:true,addEventListener:()=>{},removeEventListener:()=>{}};
  let frame=0,dirty=true,disposed=false;const animations=new Set<Animation>();
  const visible=new Set<Element>();const seen=new Set<Element>();
  const stacks=Array.from(el.querySelectorAll<HTMLElement>("[data-stack]"));
  const pipelines=Array.from(el.querySelectorAll<HTMLElement>(".pages-pipeline"));
  const research=Array.from(el.querySelectorAll<HTMLElement>("[data-scroll-words] span"));
  const typed=Array.from(el.querySelectorAll<HTMLElement>("[data-type]"));
  const rotations=Array.from(el.querySelectorAll<HTMLElement>("[data-rotate]"));
  const nav=el.querySelector<HTMLElement>(".nav");
  const mainNav=el.querySelector<HTMLElement>('.menu');
  const active=el.querySelector<HTMLAnchorElement>(`.menu a[href="/${page}"]`);
  active?.setAttribute("aria-current","page");
  const counts=new Map<HTMLElement,{target:number;from:number;value:number;start:number}>();
  const phases=new Map<Element,number>();
  const play=(node:Element,keyframes:Keyframe[],options:KeyframeAnimationOptions)=>{
   if(!node.animate)return;const animation=node.animate(keyframes,options);animations.add(animation);animation.onfinish=()=>animations.delete(animation);
  };
  const observer=typeof IntersectionObserver!=="undefined"?new IntersectionObserver(entries=>{
   entries.forEach(({target,isIntersecting})=>{
    target.setAttribute("data-visible",String(isIntersecting));if(isIntersecting)visible.add(target);else visible.delete(target);
    if(isIntersecting&&!seen.has(target)&&!reduced.matches){seen.add(target);if(target.hasAttribute("data-reveal"))play(target,[{opacity:0,transform:"translateY(18px)",filter:"blur(6px)"},{opacity:1,transform:"none",filter:"blur(0)"}],{duration:800,easing:curve});}
   });dirty=true;
  },{rootMargin:"0px 0px -8% 0px",threshold:0}):null;
  el.querySelectorAll("[data-loop],[data-reveal],.public-intro,.plans-intro").forEach(n=>observer?.observe(n));
  const isVisible=(n:Element)=>{const section=n.closest("[data-loop]");return !section||visible.has(section);};
  const reset=()=>{
   animations.forEach(a=>a.cancel());animations.clear();
   stacks.forEach(n=>{n.style.removeProperty("transform");n.style.removeProperty("filter");});
   research.forEach(n=>{n.style.opacity="1";n.style.filter="none";});
   typed.forEach(n=>{n.textContent=n.dataset.type||"";});
   pipelines.forEach(n=>n.style.setProperty("--progress","1"));
   el.querySelectorAll<HTMLElement>("[data-count]").forEach(n=>{n.textContent=Number(n.dataset.count).toLocaleString("en-US");});
   rotations.forEach(n=>{n.style.removeProperty("width");Array.from(n.children).forEach((child,i)=>{const c=child as HTMLElement;c.style.opacity=i===0?"1":"0";c.style.position=i===0?"relative":"absolute";c.style.transform="none";c.style.left=i===0?"0":"18px";});});
  };
  const enter=()=>{
   if(reduced.matches)return;
   el.querySelectorAll(".blur-word").forEach((n,i)=>play(n,[{opacity:0,filter:"blur(10px)",transform:"translateY(.35em)"},{opacity:1,filter:"blur(0)",transform:"translateY(0)"}],{duration:950,delay:i*85,easing:curve,fill:"backwards"}));
   el.querySelectorAll(".public-intro>p,.public-intro>.public-actions,.plans-intro>p").forEach((n,i)=>play(n,[{opacity:0,transform:"translateY(12px)"},{opacity:1,transform:"none"}],{duration:800,delay:400+i*100,easing:curve,fill:"backwards"}));
  };
  const tick=(now:number)=>{
   if(disposed||document.hidden)return;
   if(dirty){dirty=false;
    nav?.classList.toggle("solid",window.scrollY>8);
    if(active&&mainNav){mainNav.style.setProperty("--pill-left",`${active.offsetLeft}px`);mainNav.style.setProperty("--pill-width",`${active.offsetWidth}px`);}
    if(!reduced.matches){
     stacks.forEach((n,i)=>{const next=stacks[i+1];const p=next?clamp((window.innerHeight-next.getBoundingClientRect().top)/(window.innerHeight-130)):0;n.style.transform=window.innerWidth>=900?`scale(${1-p*.035})`:"none";n.style.filter=window.innerWidth>=900?`brightness(${1-p*.06})`:"none";});
     pipelines.forEach(n=>{const p=clamp((window.innerHeight*.86-n.getBoundingClientRect().top)/(window.innerHeight*.55));n.style.setProperty("--progress",String(p));n.querySelectorAll("li").forEach((li,i,arr)=>li.classList.toggle("node-active",p>=i/Math.max(1,arr.length-1)));});
     const r=el.querySelector("[data-scroll-words]")?.getBoundingClientRect();if(r)research.forEach((n,i)=>{const p=clamp(((window.innerHeight*.9-r.top)/(window.innerHeight*.65))*1.6-i/research.length);n.style.opacity=String(.14+p*.86);n.style.filter=`blur(${(1-p)*3}px)`;});
    }
   }
   if(!reduced.matches){
    typed.forEach(n=>{if(!isVisible(n))return;const text=n.dataset.type||"";const phase=Math.floor(now/85)%110;const next=text.slice(0,Math.min(text.length,phase));if(n.textContent!==next)n.textContent=next;const card=n.closest<HTMLElement>("[data-chat]");if(card){card.dataset.chatStage=phase<text.length?"typing":phase<text.length+12?"waiting":"answer";}});
    rotations.forEach(n=>{if(!isVisible(n))return;const index=Math.floor(now/2600)%n.children.length;if(phases.get(n)===index)return;phases.set(n,index);Array.from(n.children).forEach((child,i)=>{const c=child as HTMLElement;c.style.position="absolute";c.style.left="18px";c.style.opacity=i===index?"1":"0";c.style.transform=i===index?"translateY(0)":"translateY(-12px)";if(i===index)n.style.width=`${c.scrollWidth+36}px`;});n.dataset.tone=String(index);});
    el.querySelectorAll<HTMLElement>("[data-count]").forEach(n=>{const target=Number(n.dataset.count);if(!isVisible(n)){n.textContent=target.toLocaleString("en-US");counts.delete(n);return;}let c=counts.get(n);if(!c){counts.set(n,{target,from:target,value:target,start:now});return;}if(c.target!==target){c={target,from:c.value,value:c.value,start:now};counts.set(n,c);}const p=clamp((now-c.start)/650);c.value=c.from+(c.target-c.from)*(1-(1-p)**3);n.textContent=(p===1?target:Math.round(c.value*100)/100).toLocaleString("en-US",{maximumFractionDigits:2});});
   }
   if(!reduced.matches)frame=requestAnimationFrame(tick);
  };
  const schedule=()=>{dirty=true;if(reduced.matches){nav?.classList.toggle("solid",window.scrollY>8);return;}if(!frame&&!document.hidden)frame=requestAnimationFrame(tick);};
  const visibility=()=>{cancelAnimationFrame(frame);frame=0;if(!document.hidden)schedule();};
  const preference=()=>{cancelAnimationFrame(frame);frame=0;reset();schedule();};
  const pointer=(e:PointerEvent)=>{if(reduced.matches)return;const card=(e.target as Element).closest<HTMLElement>("[data-spotlight]");if(card){const rect=card.getBoundingClientRect();card.style.setProperty("--mx",`${e.clientX-rect.left}px`);card.style.setProperty("--my",`${e.clientY-rect.top}px`);}};
  const focus=(e:FocusEvent)=>{const block=(e.target as Element).closest<HTMLElement>("[data-stack]");if(block)block.style.zIndex="20";};
  const blur=()=>stacks.forEach(n=>n.style.removeProperty("z-index"));
  window.addEventListener("scroll",schedule,{passive:true});window.addEventListener("resize",schedule);document.addEventListener("visibilitychange",visibility);reduced.addEventListener("change",preference);el.addEventListener("pointermove",pointer);el.addEventListener("focusin",focus);el.addEventListener("focusout",blur);
  if(reduced.matches)reset();else enter();frame=requestAnimationFrame(tick);
  return()=>{disposed=true;cancelAnimationFrame(frame);observer?.disconnect();animations.forEach(a=>a.cancel());window.removeEventListener("scroll",schedule);window.removeEventListener("resize",schedule);document.removeEventListener("visibilitychange",visibility);reduced.removeEventListener("change",preference);el.removeEventListener("pointermove",pointer);el.removeEventListener("focusin",focus);el.removeEventListener("focusout",blur);};
 },[root,page]);
}
export function PagesMotion({children,className,page}:{children:ReactNode;className:string;page:string}){const root=useRef<HTMLDivElement>(null);useScrollFrame(root,page);return <div ref={root} className={className} data-page={page}>{children}</div>;}
