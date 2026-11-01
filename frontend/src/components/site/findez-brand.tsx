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

export function FindEZWordmark(props: SVGProps<SVGSVGElement>) {
  return <svg viewBox="0 0 357.5 101" role="img" aria-label="FindEZ" {...props}>
    <image className={styles.light} href="/brand/findez-wordmark.svg" width="357.5" height="101" />
    <image className={styles.dark} href="/brand/findez-wordmark-white.svg" width="357.5" height="101" />
  </svg>;
}
