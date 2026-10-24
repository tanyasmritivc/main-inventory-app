"use client";
import dynamic from 'next/dynamic';
import { useRef } from 'react';
import { StoryA } from './StoryA';
import { Who } from './Who';
import { Business } from './Business';
import { AppCarousel } from './AppCarousel';
import { Sync } from './Sync';
import { Closing } from './Closing';
import { useScrollProgress } from './useScrollProgress';
import styles from './landing.module.css';
import { FindEZWordmark } from '../site/findez-brand';
const Tools3D = dynamic(() => import('./Tools3D'), { ssr: false });
export function LandingV3({ className = '' }: { className?: string }) {
  const root = useRef<HTMLDivElement>(null);
  const { motion, registerTools } = useScrollProgress(root);
  return <div ref={root} className={`${styles.root} ${className}`}>
    <div id="heroBg" aria-hidden="true" />
    <Tools3D motion={motion} registerTools={registerTools} />
<header className="nav" id="nav">
  <a className="brand" href="#storyA" aria-label="FindEZ home"><FindEZWordmark width={112} height={33} /></a>
  <nav className="links" aria-label="Main navigation">
    <a className="lg" href="/docs/api">Developers</a>
    <a className="lg" href="https://apps.apple.com/us/app/findez-ai/id6760401697">iOS App</a>
    <a className="go" href="/signup">Get started ↗</a>
  </nav>
</header>
<main><StoryA fontClass={className} onPreviewChange={open => { if (root.current) root.current.dataset.previewOpen = String(open); }} /><Who /><Business /><AppCarousel /><Sync /><Closing /></main>
<footer>
  <span>© 2026 AI Robots Inc.</span>
  <nav aria-label="Footer navigation"><a href="/pricing">Plans</a><a href="/docs/api">Developers</a><a href="https://apps.apple.com/us/app/findez-ai/id6760401697">iOS App</a><a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="mailto:info@findez.ai">Contact</a></nav>
</footer>
</div>;
}
