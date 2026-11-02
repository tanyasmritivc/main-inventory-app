"use client";
import { Fragment, useEffect, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { startWorkbenchMotion } from "./workbench-motion";
import "./workbench.css";
import { previewPrompt } from "@/lib/landing-preview";

const headline = "The AI that turns your inventory into intelligence.";

export function HeroWorkbench() {
 const router = useRouter();
 const hero = useRef<HTMLElement>(null);
 const focused = useRef(false);
 const input = useRef<HTMLTextAreaElement>(null), busy = useRef(false);
 const [value, setValue] = useState(''), [leaving, setLeaving] = useState(false);
 useEffect(() => {
  const element = hero.current;
  element?.classList.add('wb-intro');
  let restoreFrame = 0;
  try { const draft = JSON.parse(sessionStorage.getItem('findez_public_preview_draft') || 'null');
   if(draft && Date.now()-draft.at < 30*60*1000) { const text=previewPrompt(draft.prompt); if(input.current) input.current.value=text; restoreFrame = requestAnimationFrame(() => setValue(text)); }
  } catch { /* An unavailable draft must not block signup. */ }
  const restore = () => {busy.current=false;setLeaving(false)};
  window.addEventListener('pageshow',restore);
  const stop = hero.current && input.current ? startWorkbenchMotion(hero.current, input.current, () => focused.current) : () => {};
  return()=>{element?.classList.remove('wb-intro');cancelAnimationFrame(restoreFrame);stop();window.removeEventListener('pageshow',restore)};
 },[]);
 function submit(event: FormEvent<HTMLFormElement>) {
  event.preventDefault();if(busy.current)return;
  const prompt=previewPrompt(input.current?.value||'');
  if(!prompt){input.current?.focus();return}
  busy.current=true;setLeaving(true);
  try{sessionStorage.setItem('findez_public_preview_draft',JSON.stringify({prompt,at:Date.now()}))}catch{}
  router.push('/signup?prompt='+encodeURIComponent(prompt));
 }

 return (<section id="hero" className="hero-workbench" ref={hero}>
<div className="wb-photo" aria-hidden="true" />
<div className="wb-shade" aria-hidden="true" />
<div className="wb-boxes" aria-hidden="true" />
<div className="wb-veil" aria-hidden="true" />
<div className="wb-center">
<h1 aria-label={headline}>{headline.split(' ').map((word, index) => (
 <Fragment key={index}>
  {index > 0 && ' '}
  <span className="wb-word-mask" aria-hidden="true">
   <span className={`wb-word${word === 'intelligence.' ? ' wb-ember' : ''}`} style={{ animationDelay: `${150 + index * 70}ms` }}>{word}</span>
  </span>
 </Fragment>
))}</h1>

<form className="wb-composer" id="cform" action="/signup" method="get" onSubmit={submit} aria-busy={leaving}>

<textarea ref={input} name="prompt" id="ask" rows={1} wrap="off" maxLength={2000} onFocus={()=>{focused.current=true;if(input.current)input.current.placeholder="Describe your inventory"}} onChange={e=>setValue(e.target.value)} onKeyDown={e=>{if(e.key==="Enter"&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();e.currentTarget.form?.requestSubmit()}}} placeholder="Describe your inventory" aria-label="Describe what to add">

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

<p className="wb-hint">
{"Describe what you own, or tap Scan to start from a photo."}
</p>

</div>
</section>);
}
