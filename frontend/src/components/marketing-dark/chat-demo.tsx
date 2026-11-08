'use client';
import { useEffect, useRef } from 'react';
import Image from 'next/image';
import { FindEZMark } from '@/components/site/findez-brand';
import { EXT, FZ_IMG, FZ_WASH, SOL, type Audience } from './data';
import { FZChat } from './chat-runtime';
export function ChatDemo({audience, asks}: {audience: Audience; asks?: string[]}) {
  const host = useRef<HTMLDivElement>(null);
  const templates = useRef<HTMLDivElement>(null);
  const redirecting = useRef(false);
  const openAuth = () => {
    if (redirecting.current) return;
    redirecting.current = true;
    window.location.assign(EXT.signup);
  };
  useEffect(()=>{
    if(!host.current||!templates.current)return;
    const s=SOL[audience];
    const chat=FZChat(host.current,{h:300,items:s.items,sheet:s.sheet,asks:asks??s.asks,templates:templates.current,onOpen:()=>host.current?.dispatchEvent(new CustomEvent('landing-chat-open',{bubbles:true}))});
    return ()=>chat.destroy();
  },[audience,asks]);
  return <><div data-chat ref={host}
    onInputCapture={event => {
      if (!(event.target instanceof HTMLTextAreaElement)) return;
      event.stopPropagation();
      openAuth();
    }}
    onKeyDownCapture={event => {
      if (!(event.target instanceof HTMLTextAreaElement) || event.key !== 'Enter') return;
      event.preventDefault();
      event.stopPropagation();
      openAuth();
    }}
  /><div className="asset-templates" ref={templates} aria-hidden="true">
    <span data-template="mark" className="dark"><FindEZMark width={15} height={15}/></span>
    {Object.entries(FZ_IMG).map(([k,src])=><span key={k} data-template={k}><Image src={src} alt="" width={32} height={32} unoptimized/></span>)}
    <span data-template="wash"><Image src={FZ_WASH} alt="Photo of a parts bin" width={600} height={400} unoptimized/></span>
  </div></>;
}
