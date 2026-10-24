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
const Tools3D = dynamic(() => import('./Tools3D'), { ssr: false });
export function LandingV3({ className = '' }: { className?: string }) {
  const root = useRef<HTMLDivElement>(null);
  const { motion, registerTools } = useScrollProgress(root);
  return <div ref={root} className={`${styles.root} ${className}`}>
    <div id="heroBg" aria-hidden="true" />
    <Tools3D motion={motion} registerTools={registerTools} />
<header className="nav" id="nav">
  <a className="brand" href="#storyA" aria-label="FindEZ home"><svg width="26" height="26" viewBox="18.75 22.25 55 55" aria-hidden="true">
      <path d="M25.250 39.750 A4.5 4.5 0 0 1 29.750 35.250 L56.250 35.250 A4.5 4.5 0 0 1 60.750 39.750 L60.750 66.250 A4.5 4.5 0 0 1 56.250 70.750 L54.250 70.750 A4.5 4.5 0 0 1 49.750 66.250 L49.750 50.750 A4.5 4.5 0 0 0 45.250 46.250 L29.750 46.250 A4.5 4.5 0 0 1 25.250 41.750Z" fill="#A9D6F5" transform="translate(-4.5 4.5)"></path>
      <path d="M25.250 39.750 A4.5 4.5 0 0 1 29.750 35.250 L56.250 35.250 A4.5 4.5 0 0 1 60.750 39.750 L60.750 66.250 A4.5 4.5 0 0 1 56.250 70.750 L54.250 70.750 A4.5 4.5 0 0 1 49.750 66.250 L49.750 50.750 A4.5 4.5 0 0 0 45.250 46.250 L29.750 46.250 A4.5 4.5 0 0 1 25.250 41.750Z" fill="currentColor"></path>
      <path d="M49.750 28.750 A4.5 4.5 0 0 1 54.250 24.250 L67.250 24.250 A4.5 4.5 0 0 1 71.750 28.750 L71.750 41.750 A4.5 4.5 0 0 1 67.250 46.250 L65.250 46.250 A4.5 4.5 0 0 1 60.750 41.750 L60.750 39.750 A4.5 4.5 0 0 0 56.250 35.250 L54.250 35.250 A4.5 4.5 0 0 1 49.750 30.750Z" fill="#E8590C"></path>
    </svg><span>Find<span className="ez">EZ</span></span></a>
  <nav className="links" aria-label="Main navigation">
    <a className="lg" href="/docs/api">Developers</a>
    <a className="lg" href="https://apps.apple.com/us/app/findez-ai/id6760401697">iOS App</a>
    <a className="go" href="/signup">Get started ↗</a>
  </nav>
</header>
<main><StoryA /><Who /><Business /><AppCarousel /><Sync /><Closing /></main>
<footer>
  <span>© 2026 AI Robots Inc.</span>
  <nav aria-label="Footer navigation"><a href="/pricing">Plans</a><a href="/docs/api">Developers</a><a href="https://apps.apple.com/us/app/findez-ai/id6760401697">iOS App</a><a href="/privacy">Privacy</a><a href="/terms">Terms</a><a href="mailto:info@findez.ai">Contact</a></nav>
</footer>
</div>;
}
