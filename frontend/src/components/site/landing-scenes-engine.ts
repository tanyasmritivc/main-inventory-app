const clamp = (v: number) => Math.max(0, Math.min(1, v));
const smooth = (v: number) => { v = clamp(v); return v * v * (3 - 2 * v); };

// Viewport-driven scene shapes. The existing Lab engine owns its pinned stories.
export function initLandingScenes(root: HTMLElement): () => void {
  const scenes = [...root.querySelectorAll<HTMLElement>("[data-landing-scene]")].map(surface => ({
    surface,
    section: surface.closest<HTMLElement>("section")!,
    orbit: surface.querySelector<SVGGElement>("[data-learning-orbit]"),
  }));
  const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let raf = 0, disposed = false;
  const render = () => {
    raf = 0;
    if (disposed) return;
    const height = window.innerHeight;
    for (const { surface, section, orbit } of scenes) {
      const rect = section.getBoundingClientRect();
      const enter = motion.matches ? 1 : smooth((height - rect.top) / (height * 0.8));
      const exit = motion.matches ? 0 : smooth((height * 0.55 - rect.bottom) / (height * 0.55));
      const shape = Math.min(enter, 1 - exit);
      surface.style.setProperty("--scene-in", enter.toFixed(4));
      surface.style.setProperty("--scene-out", exit.toFixed(4));
      surface.style.setProperty("--scene-shape", shape.toFixed(4));
      orbit?.setAttribute("transform", `rotate(${motion.matches ? 0 : -80 + enter * 120 + exit * 60} 240 240)`);
    }
  };
  const invalidate = () => {
    if (!raf && !disposed) raf = requestAnimationFrame(render);
  };
  window.addEventListener("scroll", invalidate, { passive: true });
  window.addEventListener("resize", invalidate);
  motion.addEventListener("change", invalidate);
  void document.fonts.ready.then(invalidate);
  invalidate();
  return () => {
    disposed = true;
    cancelAnimationFrame(raf);
    window.removeEventListener("scroll", invalidate);
    window.removeEventListener("resize", invalidate);
    motion.removeEventListener("change", invalidate);
    for (const { surface, orbit } of scenes) {
      ["--scene-in", "--scene-out", "--scene-shape"].forEach(name => surface.style.removeProperty(name));
      orbit?.removeAttribute("transform");
    }
  };
}
