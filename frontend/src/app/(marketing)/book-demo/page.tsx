import type { Metadata } from 'next';
import { HeaderMarkup, FooterMarkup } from '@/components/marketing-dark/public-chrome';
import { DemoExperience } from '@/components/demo-booking';
import styles from './demo.module.css';

export const metadata: Metadata = {
  title: { absolute: 'Book a Product Demo | FindEZ AI' },
  description: 'Request a personalized walkthrough of engineering inventory, Autodesk Fusion and bill of materials comparison.',
  alternates: { canonical: '/book-demo' },
};
export const dynamic = 'force-dynamic';

export default function BookDemo() {
  return <>
    <HeaderMarkup theme="light" reserveSpace currentPage="book-demo" />
    <main className={styles.page} id="main">
      <DemoExperience />
    </main>
    <FooterMarkup theme="light" />
  </>;
}
