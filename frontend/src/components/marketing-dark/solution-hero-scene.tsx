'use client';

import { useEffect, useRef } from 'react';
import pages from './solution-hero-pages.json';
import { mountSolutionScene } from './solution-hero-runtime';

export default function SolutionHeroScene({ config }: { config: (typeof pages)[keyof typeof pages]['cfg'] }) {
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (!host.current || !canvas.current) return;
    return mountSolutionScene(host.current, canvas.current, config);
  }, [config]);
  return <div className="sh-scene" ref={host} aria-hidden="true">
    <canvas ref={canvas}/><div className="sh-overlays" data-overlays/>
    <div className="sh-fade"/>
    <div className="sh-question" data-question>
      <span data-question-text/><span className="sh-send">
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2"><path d="M12 19V5M6 11l6-6 6 6"/></svg>
      </span>
    </div>
    <div className="sh-answer" data-answer>{config.ans}</div>
  </div>;
}
