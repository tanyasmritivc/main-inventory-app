import type { Space } from '@/lib/api';

/**
 * Determines which space names to render as cards.
 *
 * When GET /spaces succeeded (spacesLoadError false): shows only the canonical
 * server spaces. 'Unsorted' is appended when any item belongs to a deleted or
 * missing space so those items remain reachable.
 *
 * When GET /spaces failed (spacesLoadError true): falls back to deriving names
 * from items' location field. No rename/delete controls should be shown in this mode.
 */
export function resolveDisplaySpaces(
  serverSpaces: Space[],
  allItems: { location?: string | null }[],
  spacesLoadError: boolean,
): string[] {
  if (!spacesLoadError) {
    const serverNames = new Set(serverSpaces.map((s) => s.name.trim().toLowerCase()));
    const hasOrphans = (allItems ?? []).some((i) => {
      const loc = (i.location ?? '').trim().toLowerCase();
      return !loc || loc === 'unsorted' || !serverNames.has(loc);
    });
    const sorted = serverSpaces.map((s) => s.name).sort();
    return hasOrphans ? [...sorted, 'Unsorted'] : sorted;
  }
  // Fallback: derive all unique locations from items — stale names preserved for access
  const names = new Set<string>(
    (allItems ?? []).map((i) => {
      const loc = (i.location ?? '').trim();
      return !loc || loc.toLowerCase() === 'unsorted' ? 'Unsorted' : loc;
    }),
  );
  return Array.from(names).sort();
}
