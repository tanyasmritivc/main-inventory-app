"use client";
import { useEffect, useRef } from "react";
import styles from "./chat-progress.module.css";

/** Loop-only adaptation of the user's supplied React Bits ShinyText.
 * Same cosine easing, 120 degree band, 40% width and soft falloff.
 * Browser paints the gradient without React rendering on animation frames.
 */
export function ShinyText({ text, speed = 2 }: { text: string; speed?: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  useEffect(() => {
    const node = ref.current;
    if (!node) return;
    const reduce = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    let frame = 0, start = 0, visible = true;
    const stop = () => { cancelAnimationFrame(frame); frame = 0; };
    const tick = (now: number) => {
      if (!start) start = now;
      const t = ((now - start) % (Math.max(.1, speed) * 1000)) / (Math.max(.1, speed) * 1000);
      const center = -22 + 144 * (.5 - Math.cos(Math.PI * t) / 2);
      const stops: [number, number][] = [];
      for (const side of [-1, 1]) for (const f of [0, .2, .4, .6, .8, 1]) {
        stops.push([center + side * (4 + 16 * (1 - f)), f * f * (3 - 2 * f)]);
      }
      stops.sort((a, b) => a[0] - b[0]);
      node.style.backgroundImage = `linear-gradient(120deg, var(--status-base) 0%, ${stops.map(([at, amount]) => `color-mix(in srgb-linear, var(--status-shine) ${amount * 100}%, var(--status-base)) ${at}%`).join(", ")}, var(--status-base) 100%)`;
      frame = requestAnimationFrame(tick);
    };
    const sync = () => {
      stop();
      if (!reduce?.matches && visible && !document.hidden) {
        start = 0; frame = requestAnimationFrame(tick);
      } else node.style.backgroundImage = "none";
    };
    const observer = typeof IntersectionObserver !== "undefined" ? new IntersectionObserver(entries => {
      visible = entries.some(entry => entry.isIntersecting); sync();
    }) : null;
    observer?.observe(node);
    reduce?.addEventListener?.("change", sync);
    document.addEventListener("visibilitychange", sync);
    sync();
    return () => {
      stop(); observer?.disconnect(); reduce?.removeEventListener?.("change", sync);
      document.removeEventListener("visibilitychange", sync);
    };
  }, [speed]);
  return <span role="status" ref={ref} className={styles.shiny}>{text}</span>;
}
