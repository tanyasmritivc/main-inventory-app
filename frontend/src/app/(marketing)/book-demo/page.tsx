import type { Metadata } from 'next';
import Image from 'next/image';
import { HeaderMarkup, FooterMarkup } from '@/components/marketing-dark/public-chrome';
import { DemoBooking } from '@/components/demo-booking';
import { calendlyEvent } from '@/lib/demo-scheduling';
import styles from './demo.module.css';

export const metadata: Metadata = {
  title: { absolute: 'Book a Product Demo | FindEZ AI' },
  description: 'Book a 20-minute walkthrough of engineering inventory, Autodesk Fusion and bill of materials comparison.',
  alternates: { canonical: '/book-demo' },
};
export const dynamic = 'force-dynamic';

export default function BookDemo() {
  const scheduler = calendlyEvent(process.env.FINDEZ_DEMO_CALENDLY_URL ?? 'https://calendly.com/tanya-findez/30min');
  return <>
    <HeaderMarkup reserveSpace currentPage="book-demo" />
    <main className={styles.page} id="main">
      <div className={styles.columns}>
        <section className={styles.story}>
          <p className={styles.eyebrow}>Live product demonstration</p>
          <h1>See FindEZ<br/>in action.</h1>
          <p className={styles.intro}>Follow a part from the shelf to an engineering design. See how your team can find what’s on hand and check what a build still needs.</p>
          <Image className={styles.photo} src="/images/landing/workbench-wide.jpg" alt="Engineering workbench with labeled parts drawers and open hardware bins" width={720} height={380} sizes="(max-width: 800px) 92vw, 40vw" />
          <h2>What you’ll see</h2>
          <ul>
            <li>Find a part, its quantity and its location with AI search.</li>
            <li>Share inventory across teams and spaces.</li>
            <li>Work in Autodesk Fusion and generate a custom STEP model.</li>
            <li>Compare a bill of materials with available stock.</li>
          </ul>
          <a className={styles.pilot} href="mailto:info@findez.ai?subject=FindEZ%20organization%20pilot%20request">Request an Organization Pilot <span aria-hidden="true">↗</span></a>
        </section>
        <section className={styles.panel} aria-labelledby="booking-title">
          <p className={styles.eyebrow}>20 minutes · Live online</p>
          <h2 id="booking-title">Book your personalized demo</h2>
          <DemoBooking eventUrl={scheduler} />
        </section>
      </div>
    </main>
    <FooterMarkup />
  </>;
}
