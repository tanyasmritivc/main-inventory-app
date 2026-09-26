import {
  UNSORTED_SPACE,
  buildSpaceIndex,
  groupItemsBySpace,
  itemsInSpace,
  resolveDisplaySpaces,
  spaceNameForItem,
} from '../lib/spaces';

const makeSpaces = (names: string[]) =>
  names.map((name, i) => ({ id: `id-${i}`, name, created_at: null }));

const makeItems = (locations: (string | null | undefined)[]) =>
  locations.map((location) => ({ location }));

type Row = { item_id: string; space_id?: string | null; location?: string | null };

describe('canonical Space identity (space_id)', () => {
  const spaces = makeSpaces(['Kitchen', 'Garage']); // Kitchen = id-0, Garage = id-1
  const index = buildSpaceIndex(spaces);

  test('an item belongs to the Space named by its space_id, not its location text', () => {
    const item = { space_id: 'id-1', location: 'Kitchen' };
    expect(spaceNameForItem(item, index)).toBe('Garage');
  });

  test('items without space_id stay reachable as Unsorted without crashing', () => {
    expect(spaceNameForItem({ location: 'Kitchen' }, index)).toBe(UNSORTED_SPACE);
    expect(spaceNameForItem({ space_id: null, location: null }, index)).toBe(UNSORTED_SPACE);
  });

  test('an item whose Space no longer exists is Unsorted, never a new Space', () => {
    expect(spaceNameForItem({ space_id: 'deleted-space', location: 'Old shed' }, index)).toBe(UNSORTED_SPACE);
  });

  test('groups a mixed inventory by canonical Space and keeps every item and field', () => {
    const rows: Row[] = [
      { item_id: 'a', space_id: 'id-0', location: 'Kitchen' },
      { item_id: 'b', space_id: 'id-1', location: 'Garage shelf 2' },
      { item_id: 'c', location: 'Garage' },
      { item_id: 'd', space_id: 'id-0', location: 'Pantry' },
    ];
    const groups = groupItemsBySpace(rows, index);
    expect(groups.Kitchen.map((row) => row.item_id)).toEqual(['a', 'd']);
    expect(groups.Garage.map((row) => row.item_id)).toEqual(['b']);
    expect(groups[UNSORTED_SPACE].map((row) => row.item_id)).toEqual(['c']);
    // Location text is preserved as descriptive metadata.
    expect(groups.Garage[0].location).toBe('Garage shelf 2');
    expect(Object.values(groups).flat()).toHaveLength(rows.length);
  });

  test('itemsInSpace selects a Space bucket, including Unsorted', () => {
    const rows: Row[] = [
      { item_id: 'a', space_id: 'id-0' },
      { item_id: 'b' },
    ];
    expect(itemsInSpace(rows, 'Kitchen', index).map((row) => row.item_id)).toEqual(['a']);
    expect(itemsInSpace(rows, UNSORTED_SPACE, index).map((row) => row.item_id)).toEqual(['b']);
  });

  test('when the Space list failed to load, membership falls back to location text', () => {
    expect(spaceNameForItem({ space_id: 'id-0', location: 'Shed' }, null)).toBe('Shed');
    expect(spaceNameForItem({ location: '  ' }, null)).toBe(UNSORTED_SPACE);
  });
});

describe('resolveDisplaySpaces — server success (spacesLoadError=false)', () => {
  test('returns only server space names when every item has a known space_id', () => {
    const spaces = makeSpaces(['Kitchen', 'Garage']);
    const items = [{ space_id: 'id-0' }, { space_id: 'id-1' }, { space_id: 'id-0' }];
    expect(resolveDisplaySpaces(spaces, items, false)).toEqual(['Garage', 'Kitchen']);
  });

  test('does NOT recreate deleted spaces as phantom cards', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = [{ space_id: 'id-0' }, { space_id: 'gone-1', location: 'OldSpace1' }, { space_id: 'gone-2', location: 'OldSpace2' }];
    const result = resolveDisplaySpaces(spaces, items, false);
    expect(result).not.toContain('OldSpace1');
    expect(result).not.toContain('OldSpace2');
  });

  test('appends Unsorted when items reference a deleted space', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = [{ space_id: 'id-0' }, { space_id: 'gone', location: 'DeletedGarage' }];
    const result = resolveDisplaySpaces(spaces, items, false);
    expect(result).toContain('Unsorted');
    expect(result).not.toContain('DeletedGarage');
  });

  test('appends Unsorted when items have no space_id, even if location matches a Space name', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = [{ space_id: 'id-0' }, { space_id: null, location: 'Kitchen' }];
    expect(resolveDisplaySpaces(spaces, items, false)).toContain('Unsorted');
  });

  test('does NOT append Unsorted when all items are in server spaces', () => {
    const spaces = makeSpaces(['Kitchen', 'Garage']);
    const items = [{ space_id: 'id-0' }, { space_id: 'id-1' }];
    expect(resolveDisplaySpaces(spaces, items, false)).not.toContain('Unsorted');
  });

  test('returns empty array when server returns no spaces and no items', () => {
    expect(resolveDisplaySpaces([], [], false)).toEqual([]);
  });

  test('returns Unsorted (only) when server has no spaces but items exist', () => {
    const items = makeItems(['SomeOldSpace', null]);
    const result = resolveDisplaySpaces([], items, false);
    expect(result).toEqual(['Unsorted']);
  });
});

describe('resolveDisplaySpaces — server failure (spacesLoadError=true)', () => {
  test('falls back to item locations when GET /spaces failed', () => {
    const items = makeItems(['Kitchen', 'Garage', 'Kitchen']);
    const result = resolveDisplaySpaces([], items, true);
    expect(result).toContain('Kitchen');
    expect(result).toContain('Garage');
  });

  test('maps null locations to Unsorted in fallback mode', () => {
    const items = makeItems([null, 'Kitchen']);
    const result = resolveDisplaySpaces([], items, true);
    expect(result).toContain('Unsorted');
    expect(result).toContain('Kitchen');
  });

  test('maps empty-string locations to Unsorted in fallback mode', () => {
    const items = makeItems(['', 'Kitchen']);
    const result = resolveDisplaySpaces([], items, true);
    expect(result).toContain('Unsorted');
  });

  test('returns empty array when no items in fallback mode', () => {
    expect(resolveDisplaySpaces([], [], true)).toEqual([]);
  });

  test('preserves deleted-space names as fallback cards (no server list to compare against)', () => {
    const items = makeItems(['OldKitchen', 'OldGarage']);
    const result = resolveDisplaySpaces([], items, true);
    expect(result).toContain('OldKitchen');
    expect(result).toContain('OldGarage');
  });
});
