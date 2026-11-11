import './solutions-founders.css';
import type { Metadata } from 'next';
import { pageContent, navigation, footer } from './sections';
import { Markup } from './markup';
import { Motion } from './motion';
import { TITLES, ROUTES, type PageKey, type Audience } from './data';
export function pageMetadata(page: PageKey): Metadata {
  const path=page.startsWith('sol:')?ROUTES['/'+page.slice(4)]:page==='home'?'/':page==='plans'?'/pricing':'/'+page;
  return { alternates:{canonical:path}, openGraph:{title:TITLES[page],url:path}, title: {absolute: TITLES[page]}, ...(page==='home'?{description:"Turn spreadsheets, photos, and simple descriptions into searchable inventory. Ask FindEZ AI what parts, tools, and equipment you have, and where they're recorded."}:{}) };
}
export function LandingPage({page}: {page:PageKey}) {
  const content=pageContent(page);
  return <Motion key={page} page={page}>
    <Markup html={navigation}/>
    <main id="main" className={page==='solutions'||page==='founders'?'solutions-founders':undefined}><Markup html={content.html} audience={(content.k||'robotics') as Audience}/></main>
    <Markup html={footer}/>
  </Motion>;
}
