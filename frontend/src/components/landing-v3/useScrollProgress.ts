"use client";
import { useCallback, useLayoutEffect, useRef, type RefObject } from 'react';
import { createLandingMotion } from './motion';

export type MotionState = {
  mx: number; my: number; tx: number; ty: number;
  heroVis: number; endVis: number; reduce: boolean;
  toolsFrame: ((now: number) => void) | null;
};

export function sectionProgress(top: number, height: number, viewport: number, entering: boolean) {
  const clamp = (v: number) => Math.min(1, Math.max(0, v));
  return top > 0 && entering
    ? clamp((viewport - top) / viewport) - 1
    : clamp(-top / Math.max(1, height - viewport));
}

export function createProgressSampler() {
  const values = new Map<string, number>();
  return (key: string, element: HTMLElement, reduced: boolean) => {
    const r = element.getBoundingClientRect();
    if (r.bottom < -50 || r.top > innerHeight + 50) return null;
    const target = sectionProgress(r.top, r.height, innerHeight, key !== 'a');
    const old = values.get(key) ?? 0;
    let value = reduced ? target : old + (target - old) * .15;
    if (Math.abs(target - value) < .0004) value = target;
    values.set(key, value);
    return value;
  };
}

/** One animation clock for every pinned section and the client-only tool scene. */
export function useScrollProgress(root: RefObject<HTMLDivElement | null>) {
  const motion = useRef<MotionState>({ mx: 0, my: 0, tx: 0, ty: 0, heroVis: 1, endVis: 0, reduce: false, toolsFrame: null });
  useLayoutEffect(() => {
    const element = root.current;
    if (!element) return;
    const state = motion.current;
    const query = window.matchMedia('(prefers-reduced-motion: reduce)');
    const preference = () => {
      state.reduce = query.matches;
      if (state.reduce) {
        state.tx = state.ty = 0;
        const ask = element.querySelector<HTMLTextAreaElement>('#ask');
        if (ask) ask.placeholder = 'Start an inventory for my garage';
      }
    };
    preference();
    query.addEventListener('change', preference);
    const painter = createLandingMotion(element, state, createProgressSampler());
    let raf = 0;
    const frame = (now: number) => {
      if (!document.hidden) { painter.frame(now); state.toolsFrame?.(now); }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => { cancelAnimationFrame(raf); query.removeEventListener('change', preference); painter.dispose(); };
  }, [root]);
  const registerTools = useCallback((frame: (now: number) => void) => {
    const state = motion.current;
    state.toolsFrame = frame;
    return () => { if (state.toolsFrame === frame) state.toolsFrame = null; };
  }, []);
  return { motion, registerTools };
}
