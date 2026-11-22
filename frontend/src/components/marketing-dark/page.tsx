import {shareDescription, socialText} from '@/lib/marketing-social';
import './solutions-founders.css';
import type { Metadata } from 'next';
import { pageContent } from './sections';
import {HeaderMarkup, FooterMarkup} from './public-chrome';
import { Markup } from './markup';
import { Motion } from './motion';
import { TITLES, ROUTES, type PageKey, type Audience } from './data';
const descriptions: Partial<Record<PageKey, string>> = {
  "solutions": "FindEZ for robotics teams, hardware and engineering teams, research labs, workshops and small manufacturers. Know what you have, where it is and what's available.",
  "sol:robotics": "Find robot parts, tools and spares in plain words. See what you have, where it is and what's running low.",
  "sol:workshops": "Workshop inventory for tooling, consumables and spare parts that doesn't depend on someone's memory.",
  "sol:makers": "Shared components, materials and tools in one place, so everyone can find what they need.",
  "sol:labs": "Record and search shared lab equipment and consumables across courses, projects and people.",
  "founders": "Free Founders Access to FindEZ, AI-powered physical inventory intelligence. Get in early and help shape the product.",
  "plans": "Plans for individuals, teams and organizations that depend on physical resources. Start free with Founders Access."
};
export function pageMetadata(page: PageKey): Metadata {
  const path=page.startsWith('sol:')?ROUTES['/'+page.slice(4)]:page==='home'?'/':page==='plans'?'/pricing':'/'+page;
  const description = descriptions[page] ?? shareDescription;
  return {
    title: {absolute: TITLES[page]},
    ...(descriptions[page] ? {description} : {}),
    alternates: {canonical: path},
    ...socialText(TITLES[page], description, path, false),
  };
}
export function LandingPage({page}: {page:PageKey}) {
  const content=pageContent(page);
  return <><HeaderMarkup currentPage={page}/><Motion key={page} page={page}>
    <main id="main" className={page==='solutions'||page==='founders'?'solutions-founders':undefined}><Markup html={content.html} audience={(content.k||'robotics') as Audience}/></main>
  </Motion><FooterMarkup/></>;
}
