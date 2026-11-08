'use client';

import dynamic from 'next/dynamic';
import { ChatDemo } from './chat-demo';
import { EXT } from './data';
import pages from './solution-hero-pages.json';
import './solution-hero.css';

export type SolutionAudience = keyof typeof pages;
const Scene = dynamic(() => import('./solution-hero-scene'), { ssr: false });

export function SolutionHero({ audience }: { audience: SolutionAudience }) {
  const page = pages[audience];
  return <header className="solution-hero" data-hero>
    <Scene config={page.cfg}/>
    <div className="sh-bottom"><div className="sh-wrap">
      <h1 data-sp="1" dangerouslySetInnerHTML={{ __html: page.h1 }}/>
      <div className="sh-controls">
        <ChatDemo audience={audience} asks={page.chips}/>
        <p className="sh-note">Free through Founders Access. <a href={EXT.signup}>Get started</a></p>
      </div>
    </div></div>
  </header>;
}
