"use client";
/** Render every received chunk immediately; fading never queues or delays text. */
export function useAnswerPresentation(target: string) {
  return target;
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
