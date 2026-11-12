'use client';

import { useEffect, useRef } from 'react';
import { CAD_SAMPLE, mountCadDemo } from './cad-intelligence-motion';
import styles from './cad-intelligence-section.module.css';

export function CadIntelligenceSection() {
  const root = useRef<HTMLElement>(null);
  useEffect(() => {
    if (root.current) return mountCadDemo(root.current, styles);
  }, []);

  return <section ref={root} className={styles.cad} id="cad" aria-labelledby="cad-h">
    <div className={styles.dots} aria-hidden="true" />
    <div className={styles.wrap}>
      <div className={styles.top}>
        <div>
          <h2 id="cad-h">Design it.<br />Find it.<br />Build it.</h2>
          <p className={styles.q}>Can you build it with what you already own?</p>
          <p className={styles.body}>Bring your Autodesk Fusion assembly into FindEZ. Compare its parts with your inventory, see what’s available, and find what’s missing.</p>
          <div className={styles.ctas}>
            <a className={styles.btn} href="/cad-intelligence">Explore CAD Intelligence <span className={styles.ar}>→</span></a>
            <div className={styles.avail}>Available for <b>Autodesk Fusion</b> · Preview</div>
          </div>
        </div>
        <div>
          <div className={styles.win} data-cad="win">
            <div className={styles.bar}>
              <i aria-hidden="true" /><i aria-hidden="true" /><i aria-hidden="true" />
              <span className={styles.ttl}>CAD Intelligence</span><span className={styles.tag}>Sample data</span>
            </div>
            <div className={styles.file}>
              <div className={styles.fic} aria-hidden="true">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#F5F5F6" strokeWidth="1.6" strokeLinejoin="round"><path d="M12 2 21 7v10l-9 5-9-5V7z" /><path d="m3 7 9 5 9-5M12 12v10" /></svg>
              </div>
              <div><div className={styles.fn}>drivetrain_v4</div><div className={styles.fs}>Exported from Fusion with the FindEZ add-in</div></div>
              <div className={styles.prog} data-cad="prog" aria-hidden="true"><b data-cad="progress" /></div>
              <div className={styles.done} data-cad="done">Uploaded · 8 components</div>
            </div>
            <div className={styles.model}>
              <canvas aria-hidden="true" />
              <div className={styles.mlab} data-cad="mlab">Reading assembly</div>
            </div>
            <div className={styles.tbody}>
              <div className={styles.scan} data-cad="scan" aria-hidden="true" />
              <table aria-label="Sample assembly inventory comparison">
                <thead><tr><th scope="col">Component</th><th scope="col" className={styles.n}>Needed</th><th scope="col" className={styles.n}>In stock</th><th scope="col" className={styles.s}>Status</th></tr></thead>
                <tbody>{CAD_SAMPLE.map(([name, location, needed], i) => <tr key={name} className={styles.r} data-cad={`r${i}`}>
                  <td><div className={styles.cn}>{name}</div><div className={styles.cl}>{location}</div></td>
                  <td className={styles.n}>{needed}</td>
                  <td className={`${styles.n} ${styles.have}`} data-cad={`h${i}`}>0</td>
                  <td className={styles.s}><span className={styles.st} data-cad={`t${i}`} /></td>
                </tr>)}</tbody>
              </table>
            </div>
            <div className={styles.sum}>
              <span><strong data-cad="ready">0</strong> of 8 ready</span>
              <div className={styles.mt} aria-hidden="true"><b data-cad="mb" /><u data-cad="mu" /></div>
              <span data-cad="sums">Comparing…</span>
            </div>
          </div>
          <p className={styles.note}>Sample data. Component names and counts are for illustration.</p>
        </div>
      </div>
    </div>
  </section>;
}
