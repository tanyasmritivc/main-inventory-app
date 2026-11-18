import type { SVGProps } from "react";
import styles from "./findez-brand.module.css";

// Shared Petals artwork; wordmarks use the approved smaller mark proportion.
export function FindEZMark({ width = 24, height = 24, ...props }: SVGProps<SVGSVGElement>) {
  const small = Number(width) < 32;
  return <svg viewBox="0 0 80 80" width={width} height={height} aria-hidden="true" {...props}>
    <image className={styles.light} href={`/brand/findez-mark${small ? "-small" : ""}.svg`} width="80" height="80" />
    <image className={styles.dark} href={`/brand/findez-mark${small ? "-small" : ""}-white.svg`} width="80" height="80" />
  </svg>;
}

export function FindEZWordmark({ sidebar = false, ...props }: SVGProps<SVGSVGElement> & { sidebar?: boolean }) {
  const width = sidebar ? 327.5 : 357.5;
  const asset = sidebar ? "findez-sidebar-wordmark" : "findez-wordmark";
  return <svg viewBox={`0 0 ${width} 101`} role="img" aria-label="FindEZ" {...props}>
    <image className={styles.light} href={`/brand/${asset}.svg`} width={width} height="101" />
    <image className={styles.dark} href={`/brand/${asset}-white.svg`} width={width} height="101" />
  </svg>;
}
