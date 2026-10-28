"use client";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { previewPrompt } from "@/lib/landing-preview";

export function Hero() {
 const router = useRouter();
 const input = useRef<HTMLTextAreaElement>(null), busy = useRef(false);
 const [value, setValue] = useState(''), [leaving, setLeaving] = useState(false);
 useEffect(() => {
  try { const draft = JSON.parse(sessionStorage.getItem('findez_public_preview_draft') || 'null');
   if(draft && Date.now()-draft.at < 30*60*1000) { const text=previewPrompt(draft.prompt); if(input.current) input.current.value=text; setValue(text); }
  } catch { /* An unavailable draft must not block signup. */ }
  const restore = () => {busy.current=false;setLeaving(false)};
  window.addEventListener('pageshow',restore);
  const media=matchMedia('(prefers-reduced-motion: reduce)');
  const ideas=['Start an inventory for my garage','Snap the parts shelf in the lab','Where did we put the spare servos?','20 M3 screws, 4 batteries and a drill'];
  let i=0,c=0,dir=1,hold=0;
  const timer=setInterval(()=> { const el=input.current; if(!el||media.matches||document.activeElement===el||el.value)return;
   const text=ideas[i]; if(hold>0){hold--;return} c+=dir;el.placeholder=text.slice(0,c)||' ';
   if(c>=text.length){dir=-1;hold=28} else if(c<=0){dir=1;i=(i+1)%ideas.length;hold=4}
  },55);
  return()=>{clearInterval(timer);window.removeEventListener('pageshow',restore)};
 },[]);
 function submit(event: FormEvent<HTMLFormElement>) {
  event.preventDefault();if(busy.current)return;
  const prompt=previewPrompt(input.current?.value||'');
  if(!prompt){input.current?.focus();return}
  busy.current=true;setLeaving(true);
  try{sessionStorage.setItem('findez_public_preview_draft',JSON.stringify({prompt,at:Date.now()}))}catch{}
  router.push('/signup?prompt='+encodeURIComponent(prompt));
 }

 return (<section id="hero">
<div className="hbg grain" aria-hidden="true">
<i className="b1">

</i>
<i className="b2">

</i>
<i className="b3">

</i>
<i className="b4">

</i>
</div>
<div className="hero-in">

<h1 >
{"Describe your world."}
</h1>

<form className="composer" id="cform" action="/signup" method="get" onSubmit={submit} aria-busy={leaving}>

<textarea ref={input} name="prompt" id="ask" rows={2} maxLength={2000} onChange={e=>setValue(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();e.currentTarget.form?.requestSubmit()}}} placeholder="Start an inventory for my garage" aria-label="Describe what to add">

</textarea>

<div className="crow">
<a className="cb o" href="/signup" aria-label="Add">
<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#111112" strokeWidth="1.8" strokeLinecap="round">
<path d="M12 5v14M5 12h14">

</path>
</svg>
</a>
<span className="sp">

</span>

{!value.trim() && <a className="cb" href="/signup" aria-label="Speak">
<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#111112" strokeWidth="1.8" strokeLinecap="round">
<rect x="9" y="3" width="6" height="11" rx="3">

</rect>
<path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21">

</path>
</svg>
</a>}

{!value.trim() && <a className="scanp" href="/signup">
<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
<path d="M4 8V6.5A2.5 2.5 0 0 1 6.5 4H8M16 4h1.5A2.5 2.5 0 0 1 20 6.5V8M20 16v1.5a2.5 2.5 0 0 1-2.5 2.5H16M8 20H6.5A2.5 2.5 0 0 1 4 17.5V16">

</path>
<path d="M12 7.6l1.2 3.2 3.2 1.2-3.2 1.2L12 16.4l-1.2-3.2L7.6 12l3.2-1.2z" fill="#fff" stroke="none">

</path>
</svg>
{"Scan"}
</a>}
{value.trim() && <button className="cb send" type="submit" aria-label="Send" disabled={leaving}><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2"><path d="m5 12 7-7 7 7M12 5v14" /></svg></button>}
</div>

</form>

<p className="hint">
{"Snap a shelf or type a list to build an inventory."}
</p>

</div>
</section>);
}
