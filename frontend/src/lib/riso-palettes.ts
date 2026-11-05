/** Shared reference palettes for Founding Access and future Space artwork. */
export const RISO_PALETTES = {
  slate: ["#97A6B1", "#748193", "#4B556F", "#222236"],
  terracotta: ["#AB5D44", "#AC7A52", "#757067", "#D3B19E"],
  plum: ["#453349", "#773F42", "#996050", "#B69D9F"],
  sage: ["#576B5B", "#6C7F6D", "#84947F", "#AAB3A9"],
} as const;

export function risoBackground(palette: keyof typeof RISO_PALETTES) {
  return `var(--art-${palette})`;
}
