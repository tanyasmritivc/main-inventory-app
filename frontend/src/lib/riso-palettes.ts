/** Shared reference palettes for Founding Access and future Space artwork. */
export const RISO_PALETTES = {
  slate: ["#97A6B1", "#748193", "#4B556F", "#222236"],
  terracotta: ["#AB5D44", "#AC7A52", "#757067", "#D3B19E"],
  plum: ["#453349", "#773F42", "#996050", "#B69D9F"],
  sage: ["#576B5B", "#6C7F6D", "#84947F", "#AAB3A9"],
} as const;

export function risoBackground(palette: keyof typeof RISO_PALETTES) {
  const [a, b, c, d] = RISO_PALETTES[palette];
  return `radial-gradient(50% 60% at 12% 70%, ${a} 0%, transparent 75%),
    radial-gradient(55% 55% at 55% 60%, ${b} 0%, transparent 72%),
    radial-gradient(40% 45% at 92% 10%, ${c} 0%, transparent 72%),
    radial-gradient(35% 35% at 25% 5%, ${d} 0%, transparent 70%),
    linear-gradient(150deg, ${a}, ${b} 55%, ${c})`;
}
