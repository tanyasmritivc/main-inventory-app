/**
 * Tests for the centralized pilot-mode production helper (src/lib/pilot.ts).
 *
 * Run with: npm test
 */

describe('isPilotPublic', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  function loadFresh() {
    jest.resetModules();
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    return require('../lib/pilot') as typeof import('../lib/pilot');
  }

  test('returns true when NEXT_PUBLIC_PILOT_MODE is "true"', () => {
    process.env.NEXT_PUBLIC_PILOT_MODE = 'true';
    const { isPilotPublic } = loadFresh();
    expect(isPilotPublic()).toBe(true);
  });

  test('returns false when NEXT_PUBLIC_PILOT_MODE is "false"', () => {
    process.env.NEXT_PUBLIC_PILOT_MODE = 'false';
    const { isPilotPublic } = loadFresh();
    expect(isPilotPublic()).toBe(false);
  });

  test('returns false when NEXT_PUBLIC_PILOT_MODE is absent', () => {
    delete process.env.NEXT_PUBLIC_PILOT_MODE;
    const { isPilotPublic } = loadFresh();
    expect(isPilotPublic()).toBe(false);
  });

  test('returns false for any value other than the exact string "true"', () => {
    for (const v of ['True', 'TRUE', '1', 'yes', '']) {
      process.env.NEXT_PUBLIC_PILOT_MODE = v;
      const { isPilotPublic } = loadFresh();
      expect(isPilotPublic()).toBe(false);
    }
  });
});

describe('PILOT_COPY', () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { PILOT_COPY } = require('../lib/pilot') as typeof import('../lib/pilot');

  test('title is "Free Pilot"', () => {
    expect(PILOT_COPY.title).toBe('Free Pilot');
  });

  test('notice mentions September 11, 2026', () => {
    expect(PILOT_COPY.notice).toContain('September 11, 2026');
  });

  test('notice mentions September 12', () => {
    expect(PILOT_COPY.notice).toContain('September 12');
  });

  test('notice says users will not be charged automatically', () => {
    expect(PILOT_COPY.notice).toContain('not be charged automatically');
  });

  test('notice mentions unlimited access', () => {
    expect(PILOT_COPY.notice).toContain('Unlimited access');
  });

  test('buttonLabel is defined', () => {
    expect(typeof PILOT_COPY.buttonLabel).toBe('string');
    expect(PILOT_COPY.buttonLabel.length).toBeGreaterThan(0);
  });

  test('pricingNote is defined', () => {
    expect(typeof PILOT_COPY.pricingNote).toBe('string');
    expect(PILOT_COPY.pricingNote.length).toBeGreaterThan(0);
  });
});
