import { resolveDisplaySpaces } from '../lib/spaces';

const makeSpaces = (names: string[]) =>
  names.map((name, i) => ({ id: `id-${i}`, name, created_at: null }));

const makeItems = (locations: (string | null | undefined)[]) =>
  locations.map((location) => ({ location }));

describe('resolveDisplaySpaces — server success (spacesLoadError=false)', () => {
  test('returns only server space names when all items match', () => {
    const spaces = makeSpaces(['Kitchen', 'Garage']);
    const items = makeItems(['Kitchen', 'Garage', 'Kitchen']);
    expect(resolveDisplaySpaces(spaces, items, false)).toEqual(['Garage', 'Kitchen']);
  });

  test('does NOT recreate deleted spaces as phantom cards', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = makeItems(['Kitchen', 'OldSpace1', 'OldSpace2']);
    const result = resolveDisplaySpaces(spaces, items, false);
    expect(result).not.toContain('OldSpace1');
    expect(result).not.toContain('OldSpace2');
  });

  test('appends Unsorted when items reference a deleted space', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = makeItems(['Kitchen', 'DeletedGarage']);
    const result = resolveDisplaySpaces(spaces, items, false);
    expect(result).toContain('Unsorted');
    expect(result).not.toContain('DeletedGarage');
  });

  test('appends Unsorted when items have null location', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = makeItems(['Kitchen', null]);
    expect(resolveDisplaySpaces(spaces, items, false)).toContain('Unsorted');
  });

  test('appends Unsorted when items have empty-string location', () => {
    const spaces = makeSpaces(['Kitchen']);
    const items = makeItems(['Kitchen', '']);
    expect(resolveDisplaySpaces(spaces, items, false)).toContain('Unsorted');
  });

  test('does NOT append Unsorted when all items are in server spaces', () => {
    const spaces = makeSpaces(['Kitchen', 'Garage']);
    const items = makeItems(['Kitchen', 'Garage']);
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
