import type { Space } from '@/lib/api';

/** Bucket for items without a resolvable Space (legacy rows or deleted Spaces). */
export const UNSORTED_SPACE = 'Unsorted';

/** Minimal item shape needed to resolve Space membership. */
export type SpaceMember = { space_id?: string | null; location?: string | null };

/** Normalizes free-text location for the legacy fallback and for display. */
export function normalizeLocationName(value?: string | null): string {
  const loc = (value ?? '').trim();
  if (!loc || loc.toLowerCase() === UNSORTED_SPACE.toLowerCase()) return UNSORTED_SPACE;
  return loc;
}

export type SpaceIndex = {
  byId: Map<string, Space>;
  /** Lower-cased name → Space. Space names are unique per owner. */
  byName: Map<string, Space>;
};

export function buildSpaceIndex(spaces: Space[]): SpaceIndex {
  return {
    byId: new Map(spaces.map((space) => [space.id, space])),
    byName: new Map(spaces.map((space) => [space.name.trim().toLowerCase(), space])),
  };
}

/**
 * Canonical Space of an item. `space_id` is the source of truth; `location` is
 * descriptive text and never decides membership while Spaces are known. Items
 * with no `space_id`, or one that no longer resolves, have no Space.
 */
export function spaceForItem(item: SpaceMember, index: SpaceIndex): Space | null {
  return item.space_id ? index.byId.get(item.space_id) ?? null : null;
}

/**
 * Display name of the Space bucket an item belongs to (a Space name or Unsorted).
 * When the Space list could not be loaded (`index` is null), falls back to the
 * legacy location text so inventory stays reachable. That degraded mode is the
 * only place where location decides membership.
 */
export function spaceNameForItem(item: SpaceMember, index: SpaceIndex | null): string {
  if (!index) return normalizeLocationName(item.location);
  return spaceForItem(item, index)?.name ?? UNSORTED_SPACE;
}

/** Groups items by Space bucket name, preserving input order within each group. */
export function groupItemsBySpace<T extends SpaceMember>(
  items: T[],
  index: SpaceIndex | null,
): Record<string, T[]> {
  const groups: Record<string, T[]> = {};
  for (const item of items ?? []) {
    const name = spaceNameForItem(item, index);
    (groups[name] ??= []).push(item);
  }
  return groups;
}

/** Items that belong to the named Space bucket (including Unsorted). */
export function itemsInSpace<T extends SpaceMember>(
  items: T[],
  spaceName: string,
  index: SpaceIndex | null,
): T[] {
  return (items ?? []).filter((item) => spaceNameForItem(item, index) === spaceName);
}

/**
 * Determines which space names to render as cards.
 *
 * When GET /spaces succeeded (spacesLoadError false): shows only the canonical
 * server spaces. 'Unsorted' is appended when any item has no resolvable
 * `space_id`, so those items remain reachable.
 *
 * When GET /spaces failed (spacesLoadError true): falls back to deriving names
 * from items' location field. No rename/delete controls should be shown in this mode.
 */
export function resolveDisplaySpaces(
  serverSpaces: Space[],
  allItems: SpaceMember[],
  spacesLoadError: boolean,
): string[] {
  if (!spacesLoadError) {
    const index = buildSpaceIndex(serverSpaces);
    const hasOrphans = (allItems ?? []).some((item) => !spaceForItem(item, index));
    const sorted = serverSpaces.map((s) => s.name).sort();
    return hasOrphans ? [...sorted, UNSORTED_SPACE] : sorted;
  }
  // Fallback: derive all unique locations from items — stale names preserved for access
  const names = new Set<string>((allItems ?? []).map((item) => normalizeLocationName(item.location)));
  return Array.from(names).sort();
}
