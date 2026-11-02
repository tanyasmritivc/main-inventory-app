import type { ComponentProps, ReactNode } from "react";

const ART_PALETTES = ["dusk", "moss", "slate", "plum"] as const;
/** Stable across order, renders, themes and sessions; never uses display names. */
export function resourcePalette(id: string) {
  let hash = 2166136261;
  for (let i = 0; i < id.length; i++) hash = Math.imul(hash ^ id.charCodeAt(i), 16777619);
  return ART_PALETTES[(hash >>> 0) % ART_PALETTES.length];
}
export function ResourceArt({ id, children, tile = false }: { id: string; children?: ReactNode; tile?: boolean }) {
  return <span className={`resource-art grain g-${resourcePalette(id)}${tile ? " resource-tile" : ""}`}>
    {children && <span className={tile ? "resource-tile-icon" : "resource-count"}>{children}</span>}
  </span>;
}
export function PageHeader({ className = "", ...props }: ComponentProps<"header">) {
  return <header className={`theme-page-header ${className}`} {...props} />;
}
export function ThemeCard({ className = "", ...props }: ComponentProps<"div">) {
  return <div className={`theme-card ${className}`} {...props} />;
}

export const AVATAR_PALETTE = ["#3A3A40", "#6B6B70", "#8C7B6B", "#4E5878", "#46565F", "#3E5A4C", "#6B5486", "#A7808F"] as const;
/** Legacy saved colors retain their data; presentation stays on the current palette. */
export function avatarPresentationColor(value?: string | null): string {
  return AVATAR_PALETTE.find(color => color === value?.toUpperCase()) ?? AVATAR_PALETTE[0];
}
