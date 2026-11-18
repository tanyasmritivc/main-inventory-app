import type { Layout, Position, Room } from './types';

const point = (x: number, z: number, y = 0): Position => ({ x, z, y, r: 0 });
export function itemKey(room: Room, id: string) { return room.public ? id : `item:${id}`; }

/** Preserve canonical IDs and saved coordinates; reconcile only additions/deletions. */
export function reconcileLayout(room: Room, makeId = () => crypto.randomUUID()): Layout {
  if (room.public) return room.layout || { v: 2, floor: 0, pieces: [], places: {} };
  const source = room.layout;
  const valid = new Set([
    ...room.items.map(i => `item:${i.id}`), ...room.bins.map(b => `bin:${b.id}`),
    ...room.storage_areas.map(a => `area:${a.id}`),
  ]);
  const places: Record<string, Position> = Object.fromEntries(
    Object.entries(source?.places || {}).filter(([key]) => valid.has(key)).map(([key, p]) => [key, { ...p }]),
  );
  const pieces = source ? source.pieces.map(p => ({ ...p })) : [
    { id: makeId(), t: 'workbench', ...point(0, -3) },
  ];
  const areas = [...room.storage_areas].sort((a, b) => a.id.localeCompare(b.id));
  areas.forEach((area, i) => { places[`area:${area.id}`] ||= point(-4 + (i % 5) * 1.8, -4.1 + (Math.floor(i / 5) % 10) * .9, Math.floor(i / 50) * 1.5); });
  [...room.bins].sort((a, b) => a.id.localeCompare(b.id)).forEach((bin, i) => {
    places[`bin:${bin.id}`] ||= point(-4.4 + (Math.floor(i / 81) % 9), -3.5 + (i % 9) * .9, (Math.floor(i / 9) % 9) * .5);
  });
  const occupied = new Set(Object.entries(places).filter(([k]) => k.startsWith('item:')).map(([, p]) => `${p.x.toFixed(2)}:${p.z.toFixed(2)}:${p.y.toFixed(2)}`));
  let free = 0;
  const containerSlots = new Map<string, number>();
  const width = Math.max(6, Math.ceil(Math.sqrt(room.items.length)));
  const step = 8.4 / width;
  [...room.items].sort((a, b) => a.id.localeCompare(b.id)).forEach(item => {
    const key = `item:${item.id}`;
    if (places[key]) return;
    const storage = (item.bin_id && places[`bin:${item.bin_id}`]) || (item.area_id && places[`area:${item.area_id}`]);
    let candidate: Position;
    do {
      const index = free++;
      candidate = index < 12 ? point(-1.7 + (index % 6) * .65, -3.5 + Math.floor(index / 6) * .7, 1.6)
        : point(-4.2 + ((index - 12) % width) * step, -1.8 + Math.floor((index - 12) / width) * Math.min(step, 6.2 / width));
    } while (occupied.has(`${candidate.x.toFixed(2)}:${candidate.z.toFixed(2)}:${candidate.y.toFixed(2)}`));
    if (storage) {
      const group = item.bin_id || item.area_id || '';
      let slot = containerSlots.get(group) || 0;
      do {
        candidate = { ...storage, x: Math.max(-4.8, Math.min(4.8, storage.x - .3 + (slot % 4) * .2)),
          z: Math.max(-4.8, Math.min(4.8, storage.z - .3 + (Math.floor(slot / 4) % 4) * .2)),
          y: Math.min(4.8, storage.y + .55 + Math.floor(slot / 16) * .18) };
        slot++;
      } while (slot < 400 && occupied.has(`${candidate.x.toFixed(2)}:${candidate.z.toFixed(2)}:${candidate.y.toFixed(2)}`));
      containerSlots.set(group, slot);
    }
    places[key] = candidate;
    occupied.add(`${candidate.x.toFixed(2)}:${candidate.z.toFixed(2)}:${candidate.y.toFixed(2)}`);
  });
  return { v: 2, floor: source?.floor || 0, pieces, places };
}

export function placeLine(item: Room['items'][number]) {
  return [...new Set([item.location, item.container, item.bin].filter(Boolean))].join(' · ');
}
