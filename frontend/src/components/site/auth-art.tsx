"use client";

import { useEffect, useRef } from "react";
import styles from "./auth-form.module.css";

// Existing FindEZ clove path, shared by the header and decorative canvas.
export const AUTH_MARK = "M12 24A12 12 0 0 1 24 12L40.5 12A5 5 0 0 1 45.5 17L45.5 38.5A4.5 4.5 0 0 0 50 43A4.5 4.5 0 0 0 54.5 38.5L54.5 17A5 5 0 0 1 59.5 12L76 12A12 12 0 0 1 88 24L88 40.5A5 5 0 0 1 83 45.5L61.5 45.5A4.5 4.5 0 0 0 57 50A4.5 4.5 0 0 0 61.5 54.5L83 54.5A5 5 0 0 1 88 59.5L88 76A12 12 0 0 1 76 88L59.5 88A5 5 0 0 1 54.5 83L54.5 61.5A4.5 4.5 0 0 0 50 57A4.5 4.5 0 0 0 45.5 61.5L45.5 83A5 5 0 0 1 40.5 88L24 88A12 12 0 0 1 12 76L12 59.5A5 5 0 0 1 17 54.5L38.5 54.5A4.5 4.5 0 0 0 43 50A4.5 4.5 0 0 0 38.5 45.5L17 45.5A5 5 0 0 1 12 40.5Z";

export function AuthArt({ active }: { active: boolean }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const cv = canvas.current;
    if (!active || !cv) return;
    const context = cv.getContext("2d");
    if (!context) return;
    const g = context;
    const MARK = new Path2D(AUTH_MARK);
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let W = 0, H = 0, D = 1, raf = 0, elapsed = 0, last = 0;
    // Allocate the grain once, not on every frame or resize.
    const noise = document.createElement("canvas");
    noise.width = noise.height = 256;
    const n = noise.getContext("2d");
    if (!n) return;
    const pixels = n.createImageData(256, 256);
    for (let i = 0; i < pixels.data.length; i += 4) {
      const value = Math.random() * 255;
      pixels.data[i] = pixels.data[i + 1] = pixels.data[i + 2] = value;
      pixels.data[i + 3] = 10;
    }
    n.putImageData(pixels, 0, 0);
    const pattern = g.createPattern(noise, "repeat");
    function rad(x: number, y: number, r: number, c: string, a: number) {
      const gr = g.createRadialGradient(x, y, 0, x, y, r);
      gr.addColorStop(0, `rgba(${c},${a})`);
      gr.addColorStop(.5, `rgba(${c},${a * .4})`);
      gr.addColorStop(1, `rgba(${c},0)`);
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
    }
    function draw(t: number) {
      if (!W || !H) return;
 g.globalCompositeOperation='source-over';g.fillStyle='#120D0F';g.fillRect(0,0,W,H);
 const sz=Math.max(H*1.15,W*1.25),cx=W*.84,cy=H*.74,rot=-0.2+0.025*Math.sin(t*.25);
 rad(cx-sz*.18,cy-sz*.2,sz*.75,'142,90,93',.55);
 rad(W*.1,H*.05,Math.max(W,H)*.6,'94,58,64',.35);
 g.save();g.translate(cx,cy);g.rotate(rot);g.translate(-sz/2,-sz/2);g.scale(sz/100,sz/100);
 // glow halo: layered strokes, no blur
 g.lineJoin='round';
 for(let k=8;k>=1;k--){g.lineWidth=k*1.1;g.strokeStyle=`rgba(214,150,158,${.05})`;g.stroke(MARK)}
 // body
 const lg=g.createLinearGradient(10,10,80,90);lg.addColorStop(0,'#EDBFC4');lg.addColorStop(.24,'#C48A91');lg.addColorStop(.48,'#7C4850');lg.addColorStop(.74,'#2E1C21');lg.addColorStop(1,'#160F11');
 g.fillStyle=lg;g.fill(MARK);
 g.save();g.clip(MARK);
 // inner shade from the bottom-right
 const sh=g.createLinearGradient(100,100,30,30);sh.addColorStop(0,'rgba(10,6,8,.85)');sh.addColorStop(.6,'rgba(10,6,8,0)');g.fillStyle=sh;g.fillRect(0,0,100,100);
 // moving light sweep
 const p=((t*.09)%1.6)-.3,sw=g.createLinearGradient(p*140-40,0,p*140,40);sw.addColorStop(0,'rgba(255,230,234,0)');sw.addColorStop(.5,'rgba(255,230,234,.22)');sw.addColorStop(1,'rgba(255,230,234,0)');g.fillStyle=sw;g.fillRect(0,0,100,100);
 g.restore();
 // rim light
 g.lineWidth=.45;const rl=g.createLinearGradient(10,10,70,70);rl.addColorStop(0,'rgba(255,225,230,.9)');rl.addColorStop(.5,'rgba(230,170,178,.35)');rl.addColorStop(1,'rgba(230,170,178,0)');g.strokeStyle=rl;g.stroke(MARK);
 g.restore();
 // fade toward the copy and edges
 const fd=g.createLinearGradient(0,0,0,H*.5);fd.addColorStop(0,'rgba(18,13,15,.8)');fd.addColorStop(1,'rgba(18,13,15,0)');g.fillStyle=fd;g.fillRect(0,0,W,H*.5);
 const fb=g.createLinearGradient(0,H*.75,0,H);fb.addColorStop(0,'rgba(18,13,15,0)');fb.addColorStop(1,'rgba(18,13,15,.75)');g.fillStyle=fb;g.fillRect(0,H*.75,W,H*.25);
 if (pattern) g.fillStyle=pattern;g.fillRect(0,0,W,H);

    }
    function stop() {
      cancelAnimationFrame(raf); raf = 0; last = 0;
    }
    function frame(now: number) {
      raf = 0;
      if (document.hidden || motion.matches || !W || !H) return;
      if (last) elapsed += (now - last) / 1000;
      last = now;
      draw(elapsed);
      raf = requestAnimationFrame(frame);
    }
    function refresh() {
      stop();
      if (document.hidden || !W || !H) return;
      draw(motion.matches ? 2 : elapsed);
      if (!motion.matches) raf = requestAnimationFrame(frame);
    }
    function resize() {
      if (!cv) return;
      const rect = cv.getBoundingClientRect();
      const ratio = Math.min(2, window.devicePixelRatio || 1);
      if (rect.width === W && rect.height === H && ratio === D) return;
      W = rect.width; H = rect.height; D = ratio;
      cv.width = Math.round(W * D); cv.height = Math.round(H * D);
      g.setTransform(D, 0, 0, D, 0, 0);
      refresh();
    }
    const observer = new ResizeObserver(resize);
    observer.observe(cv);
    window.addEventListener("resize", resize);
    document.addEventListener("visibilitychange", refresh);
    motion.addEventListener("change", refresh);
    resize();
    return () => {
      stop(); observer.disconnect();
      window.removeEventListener("resize", resize);
      document.removeEventListener("visibilitychange", refresh);
      motion.removeEventListener("change", refresh);
      cv.width = cv.height = 0;
      noise.width = noise.height = 0;
    };
  }, [active]);

  return <aside className={styles.art} aria-hidden="true">
    <canvas ref={canvas} />
    <div className={styles.artCopy}>
      <h2>The AI that knows where every part is.</h2>
      <p>Snap a shelf, ask a question, get the exact bin. Built for teams that build things.</p>
    </div>
    <div className={styles.artFoot}><b>Founders Access</b> is open. Free while we get ready for launch.</div>
  </aside>;
}
