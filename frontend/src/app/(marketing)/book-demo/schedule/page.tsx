import { HeaderMarkup, FooterMarkup } from '@/components/marketing-dark/public-chrome';
import { DemoScheduler } from '@/components/demo-scheduler';
import styles from '../demo.module.css';

export const metadata = { title: 'Schedule your FindEZ AI demo', robots: { index: false, follow: false }, referrer: 'no-referrer' };
export default function ScheduleDemo() {
  return <><HeaderMarkup theme="light" reserveSpace currentPage="book-demo"/>
    <main className={styles.page}><DemoScheduler/></main><FooterMarkup theme="light"/></>;
}
