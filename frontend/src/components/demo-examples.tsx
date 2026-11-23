'use client';

import {useEffect, useRef, useState, type KeyboardEvent} from 'react';
import styles from '@/app/(marketing)/book-demo/demo.module.css';

const slides = [
  {
    tab: "Robotics",
    who: "A robotics team",
    stat: "22",
    label: "8mm bearings · Pit cart, Bin A1",
    question: "“Where are the 8mm bearings?”",
    answer: "Recorded in Pit cart, Bin A1. You have 22.",
    background: "#F4CFD6",
    stroke: "#0A0A0B",
    drawing: <>
      <g opacity=".35" transform="translate(26 -18)"><circle r="104"></circle><circle r="62"></circle></g>
      <circle r="104"></circle><circle r="90"></circle><circle r="62"></circle><circle r="48"></circle>
      <circle cx="76" cy="0" r="12"></circle><circle cx="53.7" cy="53.7" r="12"></circle><circle cx="0" cy="76" r="12"></circle><circle cx="-53.7" cy="53.7" r="12"></circle><circle cx="-76" cy="0" r="12"></circle><circle cx="-53.7" cy="-53.7" r="12"></circle><circle cx="0" cy="-76" r="12"></circle><circle cx="53.7" cy="-53.7" r="12"></circle>
      <line x1="-150" y1="0" x2="150" y2="0" strokeDasharray="6 6" opacity=".2"></line><line x1="0" y1="-128" x2="0" y2="128" strokeDasharray="6 6" opacity=".2"></line>
    </>,
  },
  {
    tab: "Hardware",
    who: "A hardware startup",
    stat: "7/8",
    label: "Parts ready · for the rev C build",
    question: "“Can we build rev C with what we have?”",
    answer: "7 of 8 parts are on hand. 6 M3 standoffs are short.",
    background: "#5C1A27",
    stroke: "#F4CFD6",
    drawing: <>
      <g transform="translate(24 -16) scale(.92)" opacity=".35"><use href="#cz-gear"></use><circle r="30"></circle></g>
      <g transform="scale(.92)"><use href="#cz-gear"></use><circle r="84"></circle><circle r="30"></circle><rect x="-6" y="-38" width="12" height="10"></rect>
      <circle cx="56" cy="0" r="12"></circle><circle cx="-56" cy="0" r="12"></circle><circle cx="0" cy="56" r="12"></circle><circle cx="0" cy="-56" r="12"></circle></g>
    </>,
  },
  {
    tab: "Labs",
    who: "A research lab",
    stat: "6",
    label: "Multimeters · Electronics wall",
    question: "“Where are the multimeters?”",
    answer: "Recorded on the Electronics wall. There are 6.",
    background: "#26272B",
    stroke: "#F3F1EA",
    drawing: <>
      <g transform="translate(22 -14)" opacity=".35"><circle r="100"></circle></g>
      <circle r="100"></circle><use href="#cz-pulley"></use><circle r="56"></circle>
      <polygon points="22,0 11,19 -11,19 -22,0 -11,-19 11,-19"></polygon>
      <line x1="-150" y1="0" x2="150" y2="0" strokeDasharray="6 6" opacity=".2"></line><line x1="0" y1="-128" x2="0" y2="128" strokeDasharray="6 6" opacity=".2"></line>
    </>,
  },
  {
    tab: "Workshops",
    who: "A workshop",
    stat: "2",
    label: "Spare drive belts · Maintenance cabinet",
    question: "“Do we have spare belts for the CNC?”",
    answer: "Recorded in the Maintenance cabinet, Shelf 3.",
    background: "radial-gradient(70% 90% at 0% 0%, rgba(255,181,71,.9), rgba(255,181,71,0) 60%), radial-gradient(70% 90% at 100% 100%, rgba(111,184,255,.85), rgba(111,184,255,0) 62%), #0A0A0B",
    stroke: "#FFFFFF",
    drawing: <>
      <g transform="rotate(-24)">
      <polygon points="-120,-46 -120,46 -90,62 -60,46 -60,-46 -90,-62"></polygon><line x1="-90" y1="-62" x2="-90" y2="62" opacity=".5"></line>
      <rect x="-60" y="-26" width="200" height="52"></rect>
      <line x1="-10" y1="-26" x2="-2" y2="26"></line><line x1="10" y1="-26" x2="18" y2="26"></line><line x1="30" y1="-26" x2="38" y2="26"></line><line x1="50" y1="-26" x2="58" y2="26"></line><line x1="70" y1="-26" x2="78" y2="26"></line><line x1="90" y1="-26" x2="98" y2="26"></line><line x1="110" y1="-26" x2="118" y2="26"></line>
      <line x1="-170" y1="0" x2="170" y2="0" strokeDasharray="6 6" opacity=".2"></line>
      </g>
    </>,
  },
];

export function DemoExamples() {
  const [index, setIndex] = useState(0);
  const panel = useRef<HTMLElement>(null);
  const tabs = useRef<HTMLDivElement>(null);
  const restart = useRef<() => void>(() => {});
  const slide = slides[index];

  useEffect(() => {
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    let visible = false;
    let timer: number | undefined;
    function schedule() {
      window.clearInterval(timer);
      if (visible && !document.hidden && !motion.matches) {
        timer = window.setInterval(() => setIndex(i => (i + 1) % slides.length), 4000);
      }
    }
    restart.current = schedule;
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      schedule();
    });
    observer.observe(panel.current!);
    motion.addEventListener('change', schedule);
    document.addEventListener('visibilitychange', schedule);
    return () => {
      restart.current = () => {};
      window.clearInterval(timer);
      observer.disconnect();
      motion.removeEventListener('change', schedule);
      document.removeEventListener('visibilitychange', schedule);
    };
  }, []);

  function select(i: number) {
    setIndex(i);
    restart.current();
  }
  function navigate(event: KeyboardEvent<HTMLButtonElement>, i: number) {
    const destinations: Record<string, number> = {
      ArrowRight: (i + 1) % slides.length, ArrowLeft: (i + slides.length - 1) % slides.length,
      Home: 0, End: slides.length - 1,
    };
    const target = destinations[event.key];
    if (target === undefined) return;
    event.preventDefault();
    select(target);
    tabs.current?.querySelectorAll('button')[target]?.focus();
  }

  return <section className={styles.examples} ref={panel} aria-labelledby="demo-examples-heading">
    <svg width="0" height="0" className={styles.defs} aria-hidden="true"><defs>
<path id="cz-gear" d="M104.0 0.0 L103.8 5.8 L119.6 9.4 L117.4 24.7 L101.3 23.7 L99.8 29.3 L98.0 34.8 L112.1 42.7 L105.7 56.8 L90.5 51.3 L87.5 56.2 L84.2 61.0 L95.5 72.6 L85.5 84.2 L72.4 74.7 L68.1 78.6 L63.6 82.3 L71.2 96.6 L58.3 104.9 L48.4 92.1 L43.2 94.6 L37.9 96.9 L41.1 112.7 L26.3 117.1 L20.5 102.0 L14.8 102.9 L9.0 103.6 L7.7 119.8 L-7.7 119.8 L-9.0 103.6 L-14.8 102.9 L-20.5 102.0 L-26.3 117.1 L-41.1 112.7 L-37.9 96.9 L-43.2 94.6 L-48.4 92.1 L-58.3 104.9 L-71.2 96.6 L-63.6 82.3 L-68.1 78.6 L-72.4 74.7 L-85.5 84.2 L-95.5 72.6 L-84.2 61.0 L-87.5 56.2 L-90.5 51.3 L-105.7 56.8 L-112.1 42.7 L-98.0 34.8 L-99.8 29.3 L-101.3 23.7 L-117.4 24.7 L-119.6 9.4 L-103.8 5.8 L-104.0 0.0 L-103.8 -5.8 L-119.6 -9.4 L-117.4 -24.7 L-101.3 -23.7 L-99.8 -29.3 L-98.0 -34.8 L-112.1 -42.7 L-105.7 -56.8 L-90.5 -51.3 L-87.5 -56.2 L-84.2 -61.0 L-95.5 -72.6 L-85.5 -84.2 L-72.4 -74.7 L-68.1 -78.6 L-63.6 -82.3 L-71.2 -96.6 L-58.3 -104.9 L-48.4 -92.1 L-43.2 -94.6 L-37.9 -96.9 L-41.1 -112.7 L-26.3 -117.1 L-20.5 -102.0 L-14.8 -102.9 L-9.0 -103.6 L-7.7 -119.8 L7.7 -119.8 L9.0 -103.6 L14.8 -102.9 L20.5 -102.0 L26.3 -117.1 L41.1 -112.7 L37.9 -96.9 L43.2 -94.6 L48.4 -92.1 L58.3 -104.9 L71.2 -96.6 L63.6 -82.3 L68.1 -78.6 L72.4 -74.7 L85.5 -84.2 L95.5 -72.6 L84.2 -61.0 L87.5 -56.2 L90.5 -51.3 L105.7 -56.8 L112.1 -42.7 L98.0 -34.8 L99.8 -29.3 L101.3 -23.7 L117.4 -24.7 L119.6 -9.4 L103.8 -5.8 Z"></path>
<path id="cz-pulley" d="M78.0 0.0 L78.0 2.8 L85.9 4.5 L84.9 13.5 L76.8 13.5 L76.3 16.2 L75.7 18.9 L83.1 22.3 L80.3 30.8 L72.3 29.2 L71.3 31.7 L70.1 34.2 L76.6 39.0 L72.1 46.8 L64.7 43.6 L63.1 45.8 L61.4 48.1 L66.8 54.1 L60.8 60.8 L54.2 56.1 L52.2 58.0 L50.1 59.8 L54.1 66.8 L46.8 72.1 L41.4 66.1 L39.0 67.5 L36.6 68.9 L39.0 76.6 L30.8 80.3 L26.7 73.3 L24.1 74.2 L21.4 75.0 L22.3 83.1 L13.5 84.9 L10.9 77.2 L8.2 77.6 L5.4 77.8 L4.5 85.9 L-4.5 85.9 L-5.4 77.8 L-8.2 77.6 L-10.9 77.2 L-13.5 84.9 L-22.3 83.1 L-21.4 75.0 L-24.1 74.2 L-26.7 73.3 L-30.8 80.3 L-39.0 76.6 L-36.6 68.9 L-39.0 67.5 L-41.4 66.1 L-46.8 72.1 L-54.1 66.8 L-50.1 59.8 L-52.2 58.0 L-54.2 56.1 L-60.8 60.8 L-66.8 54.1 L-61.4 48.1 L-63.1 45.8 L-64.7 43.6 L-72.1 46.8 L-76.6 39.0 L-70.1 34.2 L-71.3 31.7 L-72.3 29.2 L-80.3 30.8 L-83.1 22.3 L-75.7 18.9 L-76.3 16.2 L-76.8 13.5 L-84.9 13.5 L-85.9 4.5 L-78.0 2.8 L-78.0 0.0 L-78.0 -2.8 L-85.9 -4.5 L-84.9 -13.5 L-76.8 -13.5 L-76.3 -16.2 L-75.7 -18.9 L-83.1 -22.3 L-80.3 -30.8 L-72.3 -29.2 L-71.3 -31.7 L-70.1 -34.2 L-76.6 -39.0 L-72.1 -46.8 L-64.7 -43.6 L-63.1 -45.8 L-61.4 -48.1 L-66.8 -54.1 L-60.8 -60.8 L-54.2 -56.1 L-52.2 -58.0 L-50.1 -59.8 L-54.1 -66.8 L-46.8 -72.1 L-41.4 -66.1 L-39.0 -67.5 L-36.6 -68.9 L-39.0 -76.6 L-30.8 -80.3 L-26.7 -73.3 L-24.1 -74.2 L-21.4 -75.0 L-22.3 -83.1 L-13.5 -84.9 L-10.9 -77.2 L-8.2 -77.6 L-5.4 -77.8 L-4.5 -85.9 L4.5 -85.9 L5.4 -77.8 L8.2 -77.6 L10.9 -77.2 L13.5 -84.9 L22.3 -83.1 L21.4 -75.0 L24.1 -74.2 L26.7 -73.3 L30.8 -80.3 L39.0 -76.6 L36.6 -68.9 L39.0 -67.5 L41.4 -66.1 L46.8 -72.1 L54.1 -66.8 L50.1 -59.8 L52.2 -58.0 L54.2 -56.1 L60.8 -60.8 L66.8 -54.1 L61.4 -48.1 L63.1 -45.8 L64.7 -43.6 L72.1 -46.8 L76.6 -39.0 L70.1 -34.2 L71.3 -31.7 L72.3 -29.2 L80.3 -30.8 L83.1 -22.3 L75.7 -18.9 L76.3 -16.2 L76.8 -13.5 L84.9 -13.5 L85.9 -4.5 L78.0 -2.8 Z"></path>
</defs></svg>
    <div className={styles.examplesInner}>
      <h2 id="demo-examples-heading">How teams like yours use FindEZ</h2>
      <article className={styles.card} id="demo-example-panel" role="tabpanel" aria-labelledby={`demo-tab-${index}`}>
        <div className={styles.statRow}><span className={styles.stat}>{slide.stat}</span><span className={styles.statLabel}>{slide.label}</span></div>
        <div className={styles.copy}><div className={styles.team}>{slide.who} asks</div><h3>{slide.question}</h3><p>{slide.answer}</p></div>
        <div className={styles.drawing} style={{background: slide.background}}>
          <svg key={slide.tab} viewBox="-180 -140 360 280" fill="none" stroke={slide.stroke} strokeWidth="1.6" vectorEffect="non-scaling-stroke" aria-hidden="true">{slide.drawing}</svg>
        </div>
      </article>
      <div className={styles.tabs} role="tablist" aria-label="Team type" ref={tabs}>
        {slides.map((item, i) => <button key={item.tab} id={`demo-tab-${i}`} type="button" role="tab" aria-selected={i === index} aria-controls="demo-example-panel" tabIndex={i === index ? 0 : -1} onKeyDown={e => navigate(e, i)} onClick={() => select(i)}>{item.tab}</button>)}
      </div>
    </div>
  </section>;
}
