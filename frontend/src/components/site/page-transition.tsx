import styles from "./page-transition.module.css";

/** Quiet, theme-aware transition; never show a bare status line at (0, 0). */
export function PageTransition() {
  return <div className={styles.transition} role="status" aria-busy="true">
    <span className="sr-only">Opening FindEZ</span>
    <div className={styles.mark} aria-hidden="true"><span /><span /><span /></div>
  </div>;
}
