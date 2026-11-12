import Link from "next/link";
import { CadHelp } from '@/components/cad/cad-help';
import styles from '@/components/cad/cad.module.css';

export const metadata = { title: 'CAD Intelligence setup guide | FindEZ', description: 'Install the FindEZ Fusion add-in, export your parts list, compare inventory, and troubleshoot each step.' };

export default function CadGuidePage() {
  return <main className={`${styles.page} ${styles.guidePage}`}>
    <nav className={styles.topline} aria-label="Guide navigation"><Link href="/">FindEZ</Link><a href="/cad">Open CAD Intelligence ↗</a></nav>
    <header className={styles.hero}><h1>From your design<br />to what&apos;s on your shelf.</h1><p>Install once. Export a parts list. Compare it with your inventory.</p></header>
    <div className={styles.guideLayout}><aside className={styles.guideNav}><p className={styles.eyebrow}>IN THIS GUIDE</p><a href="#install">1. Install the add-in</a><a href="#export">2. Export from Fusion</a><a href="#compare">3. Compare in FindEZ</a><a href="#spreadsheet">CSV and Excel</a><a href="#sample">Try a sample design</a><a href="#results">Understand results</a><a href="#troubleshooting">Troubleshooting</a><a href="#support">Contact support</a></aside><CadHelp /></div>
  </main>;
}
