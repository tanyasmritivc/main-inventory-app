"use client";

import { useEffect, useRef, type ReactNode } from "react";
import points from "../../../public/research/find-hero-points.json";

const clamp = (n: number) => Math.max(0, Math.min(1, n));

export function ResearchMotion({ children }: { children: ReactNode }) {
 const root = useRef<HTMLElement>(null);
 useEffect(() => {
  const el = root.current;
  if (!el) return;
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  const box = el.querySelector<HTMLElement>(".fr-cv")!;
  const canvas = box.querySelector("canvas")!;
  const context = canvas.getContext("2d");
  const labels = Array.from(box.querySelectorAll<HTMLElement>(".lab"));
  const pipe = el.querySelector<HTMLElement>(".fr-pipe")!;
  const photo = pipe.querySelector<HTMLElement>(".fr-ph")!;
  const steps = Array.from(pipe.querySelectorAll<HTMLElement>(".s"));
  const layers = Array.from(photo.querySelectorAll<HTMLElement>(".lay"));
  const scan = photo.querySelector<HTMLElement>("[data-scan]")!;
  let frame = 0, disposed = false, visible = false, elapsed = 0, last = 0;
  let width = 0, height = 0;
  let seed = 11;
  const random = () => (seed = seed * 16807 % 2147483647) / 2147483647;
  const dots = points.map(([x, y]) => ({ x, y, sx: random(), sy: random(), delay: random() * .6 }));

  const draw = (t: number, finished = false) => {
   if (!context) return;
   context.clearRect(0, 0, width, height);
   const progress = finished ? -1 : ((t - 1.2) % 5) / 3.2;
   const scanY = progress * height;
   for (const p of dots) {
    const k = finished ? 1 : clamp((t - .2 - p.delay) / 1.4);
    const ease = 1 - (1 - k) ** 3;
    const x = (p.sx + (p.x - p.sx) * ease) * width;
    const y = (p.sy + (p.y - p.sy) * ease) * height;
    const near = progress >= 0 && progress <= 1 ? Math.exp(-(((y - scanY) / 26) ** 2)) : 0;
    context.fillStyle = near > .05 ? `rgba(${Math.round(245 - near * 90)},${Math.round(245 - near * 60)},255,${.55 + near * .45})` : `rgba(245,245,246,${.25 + ease * .45})`;
    context.fillRect(x - .9 - near, y - .9 - near, 1.8 + near * 2, 1.8 + near * 2);
   }
   if (progress >= 0 && progress <= 1) {
    const gradient = context.createLinearGradient(0, scanY - 40, 0, scanY + 2);
    gradient.addColorStop(0, "rgba(157,182,230,0)");
    gradient.addColorStop(1, "rgba(157,182,230,.28)");
    context.fillStyle = gradient; context.fillRect(0, scanY - 40, width, 42);
    context.fillStyle = "rgba(255,255,255,.8)"; context.fillRect(0, scanY, width, 1.5);
   }
   labels.forEach((label, i) => label.classList.toggle("on", finished || t > 2.2 + i * .35));
  };
  const tick = (now: number) => {
   frame = 0;
   if (disposed || !visible || document.hidden || reduce.matches) return;
   if (last) elapsed += Math.min(now - last, 100);
   last = now;
   draw(elapsed / 1000);
   frame = requestAnimationFrame(tick);
  };
  const schedule = () => {
   cancelAnimationFrame(frame); frame = 0; last = 0;
   if (reduce.matches) draw(4, true);
   else if (visible && !document.hidden && !disposed) frame = requestAnimationFrame(tick);
  };
  const fit = () => {
   const rect = box.getBoundingClientRect();
   width = rect.width; height = rect.height;
   const ratio = Math.min(window.devicePixelRatio || 1, 1.5);
   canvas.width = Math.round(width * ratio); canvas.height = Math.round(height * ratio);
   context?.setTransform(ratio, 0, 0, ratio, 0, 0);
   draw(reduce.matches ? 4 : elapsed / 1000, reduce.matches);
  };
  // Scroll state is applied synchronously, without a queued frame or React render.
  const pipeline = () => {
   const span = Math.max(1, pipe.offsetHeight - window.innerHeight);
   const progress = Math.min(.9999, clamp(-pipe.getBoundingClientRect().top / span)) * steps.length;
   const index = reduce.matches ? steps.length - 1 : Math.floor(progress);
   steps.forEach((step, i) => {
    step.classList.toggle("on", i === index);
    step.style.setProperty("--f", String(i < index ? 1 : i === index ? progress - index : 0));
    if (i === index) step.setAttribute("aria-current", "step"); else step.removeAttribute("aria-current");
   });
   layers.forEach((layer, i) => {
    layer.classList.toggle("on", i === index);
    layer.setAttribute("aria-hidden", String(i !== index));
   });
   photo.classList.toggle("dim", index >= 1);
   const scanProgress = index === 1 ? Math.min(1, (progress - index) * 1.6) : 0;
   scan.style.transform = `translateY(${photo.clientHeight * (.66 + .08 * scanProgress)}px)`;
  };
  const reveals = new IntersectionObserver(entries => {
   for (const entry of entries) if (entry.isIntersecting) {
    entry.target.classList.add("in"); reveals.unobserve(entry.target);
   }
  }, { threshold: 0, rootMargin: "0px 0px -2% 0px" });
  const heroObserver = new IntersectionObserver(entries => {
   visible = entries[0].isIntersecting; schedule();
  });
  const ring = el.querySelector<HTMLElement>(".fr-ring .orbit")!;
  let ringVisible = false;
  const ringState = () => { ring.style.animationPlayState = ringVisible && !document.hidden && !reduce.matches ? "running" : "paused"; };
  const ringObserver = new IntersectionObserver(entries => { ringVisible = entries[0].isIntersecting; ringState(); });
  const preference = () => {
   if (reduce.matches) el.querySelectorAll(".rv").forEach(node => node.classList.add("in"));
   pipeline(); schedule(); ringState();
  };
  const visibility = () => { schedule(); ringState(); };
  const resize = new ResizeObserver(() => { fit(); pipeline(); });
  el.classList.add("motion-ready");
  el.querySelectorAll(".rv").forEach(node => reveals.observe(node));
  fit(); pipeline(); preference();
  heroObserver.observe(box); ringObserver.observe(ring.parentElement!); resize.observe(box); resize.observe(photo);
  window.addEventListener("scroll", pipeline, { passive: true });
  window.addEventListener("resize", pipeline);
  document.addEventListener("visibilitychange", visibility);
  reduce.addEventListener("change", preference);
  return () => {
   disposed = true; cancelAnimationFrame(frame);
   reveals.disconnect(); heroObserver.disconnect(); ringObserver.disconnect(); resize.disconnect();
   window.removeEventListener("scroll", pipeline); window.removeEventListener("resize", pipeline);
   document.removeEventListener("visibilitychange", visibility); reduce.removeEventListener("change", preference);
   el.classList.remove("motion-ready");
  };
 }, []);
 return <main className="find-research" ref={root}>{children}</main>;
}
