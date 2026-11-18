import type { Room, WorldItem } from './types';

export type StorageGroup = { key: string; name: string; kind: string; items: WorldItem[] };
export const CONTENTS_PAGE_SIZE = 12;

// A read-only projection. Location remains the Space; categories never create storage.
export function storageGroups(room: Room): StorageGroup[] {
  if (room.sample || room.public) return [];
  const groups: StorageGroup[] = [
    ...room.storage_areas.map(a => ({ key: `area:${a.id}`, name: a.name, kind: a.kind, items: [] as WorldItem[] })),
    ...room.bins.map(b => ({ key: `bin:${b.id}`, name: b.name, kind: 'bin', items: [] as WorldItem[] })),
    { key: 'unplaced', name: 'Unplaced items', kind: 'No storage assigned', items: [] },
  ];
  const byKey = new Map(groups.map(g => [g.key, g]));
  for (const item of room.items) {
    // A bin is the more specific assignment when both a bin and an area are present.
    const group = byKey.get(`bin:${item.bin_id}`) || byKey.get(`area:${item.area_id}`) || byKey.get('unplaced')!;
    group.items.push(item);
  }
  return groups;
}
