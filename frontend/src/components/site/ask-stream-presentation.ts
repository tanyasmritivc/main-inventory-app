"use client";
import { useEffect, useRef, useState } from "react";

/** Presentation pacing only: every character comes from the model response. */
export function useAnswerPresentation(target: string, animate: boolean) {
  const [shown, setShown] = useState(animate ? "" : target);
  const state = useRef({ target, shown: animate ? "" : target });
  useEffect(() => {
    const motion = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    state.current.target = target;
    let timer: number | undefined;
    const advance = () => {
      const value = state.current;
      if (!animate || motion?.matches) {
        value.shown = value.target;
      } else {
        // Canonical completion may normalize punctuation, never flush its suffix.
        const prefix = value.target.slice(0, value.shown.length);
        const tail = value.target.slice(prefix.length);
        const words = [...tail.matchAll(/\s+|\S+\s*/g)];
        const count = Math.min(16, 4 + Math.floor(words.length / 30));
        value.shown = prefix + words.slice(0, count).map((word) => word[0]).join("");
      }
      setShown(value.shown);
      if (value.shown !== value.target) timer = window.setTimeout(advance, 36);
    };
    advance();
    motion?.addEventListener?.("change", advance);
    return () => {
      window.clearInterval(timer);
      motion?.removeEventListener?.("change", advance);
    };
  }, [target, animate]);
  return animate ? shown : target;
}

export type FadeBirths = { text: string; times: number[] };
type Node = { type: string; value?: string; tagName?: string; children?: Node[]; properties?: Record<string, unknown> };

/** Inline spans preserve Markdown's semantic tree, wrapping and safe links. */
export function chunkFades(births: FadeBirths) {
  return () => (tree: Node) => {
    const now = Date.now();
    let text = "";
    const collect = (node: Node) => {
      if (node.type === "text") text += node.value ?? "";
      else node.children?.forEach(collect);
    };
    collect(tree);
    let prefix = 0;
    while (prefix < text.length && prefix < births.text.length && text[prefix] === births.text[prefix]) prefix++;
    births.times = [...births.times.slice(0, prefix), ...Array(text.length - prefix).fill(now)];
    births.text = text;
    let offset = 0;
    const wrap = (node: Node) => {
      if (!node.children) return;
      node.children = node.children.flatMap((child) => {
        if (child.type !== "text") { wrap(child); return [child]; }
        const parts = [...(child.value ?? "").matchAll(/\s+|\S+/g)].map((part) => {
          const birth = Math.min(...births.times.slice(offset, offset + part[0].length));
          offset += part[0].length;
          const age = Math.max(0, now - birth);
          return { type: "element", tagName: "span", properties: {
            className: ["ask-chunk"], style: `animation-delay:-${Math.min(age, 180)}ms;animation-duration:${age >= 180 ? 0 : 180}ms`,
          }, children: [{ type: "text", value: part[0] }] };
        });
        return parts;
      });
    };
    wrap(tree);
  };
}
