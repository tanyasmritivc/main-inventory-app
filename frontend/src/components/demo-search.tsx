'use client';

import { useEffect, useRef, useState } from 'react';
import type { DemoTopic } from './demo-booking';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const searches = [
  { query: 'M4 x 12 socket head screws', rows: [
    ['M4', 'M4 x 12 socket head', 'Pit cart · Bin B3', '46 on hand'],
    ['M4', 'M4 x 16 socket head', 'Shop wall · Drawer 2', '18 on hand'],
    ['M4', 'M4 nylock nut', 'Pit cart · Bin B4', '4 left'],
  ] },
  { query: 'GoBILDA 5203 motor', rows: [
    ['MTR', 'GoBILDA 5203 Yellow Jacket', 'Electronics shelf · Tote 1', '3 on hand'],
    ['MTR', 'Motor mount plate', 'Shop wall · Drawer 5', '6 on hand'],
    ['CBL', 'Motor encoder cable', 'Electronics shelf · Tote 2', '1 left'],
  ] },
  { query: '8mm hex shaft', rows: [
    ['SFT', '8mm REX shaft, 96mm', 'Stock rack · Slot 4', '7 on hand'],
    ['BRG', '8mm flanged bearing', 'Pit cart · Bin A1', '22 on hand'],
    ['SFT', '8mm REX shaft, 150mm', 'Stock rack · Slot 4', '2 left'],
  ] },
];

const examples = {
  'AI inventory search': searches[0],
  'Robotics inventory': searches[1],
  'Fusion and STEP models': { query: '8mm shaft for a Fusion assembly', rows: searches[2].rows },
  'BOM comparison': { query: 'Compare drivetrain_v4 with stock', rows: [
    ['SFT', '8mm REX shaft', 'Required 2 · On hand 7', 'Ready'],
    ['BRG', '8mm flanged bearing', 'Required 4 · On hand 22', 'Ready'],
    ['MTR', '5203 Yellow Jacket', 'Required 4 · On hand 3', '1 short'],
  ] },
};

export function DemoSearch({topic}: {topic?: DemoTopic}) {
  const card = useRef<HTMLDivElement>(null);
  const [frame, setFrame] = useState({ search: 0, tick: searches[0].query.length });
  const [playing, setPlaying] = useState(false);
  useEffect(() => {
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    let visible = false;
    let timer: number | undefined;
    function sync() {
      window.clearInterval(timer);
      const play = !topic && visible && !document.hidden && !motion.matches;
      setPlaying(play);
      if (motion.matches) setFrame({ search: 0, tick: searches[0].query.length });
      if (play) timer = window.setInterval(() => setFrame(({ search, tick }) =>
        tick >= searches[search].query.length + 26
          ? { search: (search + 1) % searches.length, tick: 0 }
          : { search, tick: tick + 1 }
      ), 70);
    }
    const observer = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; sync(); });
    observer.observe(card.current!);
    motion.addEventListener('change', sync);
    document.addEventListener('visibilitychange', sync);
    return () => {
      window.clearInterval(timer);
      observer.disconnect();
      motion.removeEventListener('change', sync);
      document.removeEventListener('visibilitychange', sync);
    };
  }, [topic]);
  const { query, rows } = topic ? examples[topic] : searches[frame.search];
  return <div ref={card} aria-hidden="true" className={styles.sample}>
    <div className={styles.searchBar}>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
      <span className={styles.query}>{topic ? query : query.slice(0, frame.tick)}<i className={styles.caret} style={{animationPlayState: playing ? 'running' : 'paused'}} /></span>
      <span className={styles.sampleLabel}>Sample data</span>
    </div>
    <div className={styles.results} style={{opacity: topic || frame.tick >= query.length ? 1 : 0.25}}>
      {rows.map(([tag, name, location, quantity]) => <div key={name} className={styles.result}>
        <span className={styles.tag}>{tag}</span>
        <span className={styles.part}>{name}<small>{location}</small></span>
        <span className={/(left|short)$/.test(quantity) ? styles.low : styles.qty}>{quantity}</span>
      </div>)}
    </div>
    <div className={styles.sampleFooter}><span>drivetrain_v4 · Autodesk Fusion</span><span>7 of 8 ready<span className={styles.low}> · 1 short</span></span></div>
  </div>;
}
