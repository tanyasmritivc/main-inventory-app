import { Inter, IBM_Plex_Mono, Instrument_Serif } from 'next/font/google';
import '@/components/world/world.css';
const inter = Inter({ subsets: ['latin'], variable: '--font-world-inter', display: 'swap' });
const mono = IBM_Plex_Mono({ subsets: ['latin'], weight: ['400', '500'], variable: '--font-world-mono', display: 'swap' });
const serif = Instrument_Serif({ subsets: ['latin'], weight: '400', style: ['normal', 'italic'], variable: '--font-world-serif', display: 'swap' });
export const metadata = { title: 'World', robots: { index: false, follow: false }, referrer: 'no-referrer' as const };
export default function WorldLayout({ children }: { children: React.ReactNode }) {
  return <div className={`${inter.variable} ${mono.variable} ${serif.variable}`}>{children}</div>;
}
