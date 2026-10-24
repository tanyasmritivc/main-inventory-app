"use client";
import { useEffect, useRef, type RefObject } from 'react';
import { createToolsScene } from './toolsScene';
import type { MotionState } from './useScrollProgress';
export default function Tools3D({ motion, registerTools }: { motion: RefObject<MotionState>; registerTools: (frame: (now: number) => void) => () => void }) {
  const canvas = useRef<HTMLCanvasElement>(null), tooltip = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!canvas.current || !tooltip.current) return;
    const state = motion.current;
    const scene = createToolsScene(canvas.current, tooltip.current, state);
    const detach = registerTools(scene.frame);
    return () => { detach(); scene.dispose(); };
  }, [motion, registerTools]);
  return <><canvas ref={canvas} id="gl" aria-hidden="true" /><div ref={tooltip} id="tip" role="tooltip"><b /><span /></div></>;
}
