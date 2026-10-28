"use client";
import { useEffect, useRef, useState } from "react";
import { audiences } from "./audiences-data";

export function Audiences() {
 const [current,setCurrent]=useState(0),[fading,setFading]=useState(false);
 const section=useRef<HTMLElement>(null),auto=useRef(true),index=useRef(0),pending=useRef<ReturnType<typeof setTimeout>|null>(null);
 function select(i:number){
  if(i===index.current)return; index.current=i;
  if(pending.current)clearTimeout(pending.current);
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches;
  if(reduced){setCurrent(i);setFading(false);return}
  setFading(true);pending.current=setTimeout(()=>{setCurrent(i);setFading(false)},260);
 }
 useEffect(()=>{
  const timer=setInterval(()=>{const r=section.current?.getBoundingClientRect();
   if(auto.current&&!matchMedia('(prefers-reduced-motion: reduce)').matches&&r&&r.top<innerHeight*.8&&r.bottom>innerHeight*.2)select((index.current+1)%audiences.length);
  },4600);
  return()=>{clearInterval(timer);if(pending.current)clearTimeout(pending.current)};
 },[]);
 const who=audiences[current],fade={opacity:fading?0:1,transform:fading?'translateY(10px)':'none'};

 return (<section ref={section} className="sec" id="s4">

<div className="two">
<div data-rv="">
<h2 >
{"Designed for every kind"}
<br  />
{"of inventory"}
</h2>
</div>
<div >

</div>
</div>

<div className="tabs" id="tabs" data-rv="" role="group" aria-label="Inventory examples">{audiences.map((w,i)=><button key={w.t} type="button" className={"tab"+(i===current?" on":"")} aria-pressed={i===current} onClick={()=>{auto.current=false;select(i)}}>{w.t}</button>)}</div>

<div className="who" data-rv="">

<div className="txt">
<div className="fadeSwap" id="wT" style={fade}><h3>{who.h}</h3><ul>{who.l.map(line=><li key={line}>{line}</li>)}</ul></div>
<a className="btn w" style={{"alignSelf":"flex-start","marginTop":"26px"}} href="/signup">
{"Start free"}
</a>
</div>

<div className={"art grain "+who.g} id="wA">
<div className="q fadeSwap" id="wQ" style={fade}><div className="mu" style={{width:'fit-content',maxWidth:'100%',marginLeft:'auto'}}>{who.q}</div><div className="ma" style={{marginTop:12}}>{who.a.split(new RegExp("(<b>.*?</b>)")).map((s,i)=>s.startsWith('<b>')?<b key={i}>{s.slice(3,-4)}</b>:s)}<br/><span className="loc"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 20s6-5.5 6-10a6 6 0 0 0-12 0c0 4.5 6 10 6 10z"/><circle cx="12" cy="10" r="2.2"/></svg>{who.loc}</span></div></div>
</div>

</div>

<span className="tick l">

</span>
<span className="tick r">

</span>

</section>);
}
