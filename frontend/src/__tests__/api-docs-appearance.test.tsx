/** @jest-environment jsdom */
import { act, cleanup, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DocsAppearance } from '@/components/site/api-docs-controls';
import { AppThemeDocument, AppThemeProvider } from '@/components/site/use-app-theme';
import { APP_THEME_INIT_SCRIPT, APP_THEME_STORAGE_KEY, isInteriorPath, isThemedPath } from '@/lib/app-theme-constants';

let mockPathname = '/docs/api';
jest.mock('next/navigation', () => ({ usePathname: () => mockPathname }));
let dark = false;
let listeners: Set<() => void>;
function osTheme(next: boolean) {
  act(() => { dark = next; listeners.forEach(listener => listener()); });
}
function view() {
  return <><AppThemeDocument /><AppThemeProvider><DocsAppearance /></AppThemeProvider></>;
}
beforeEach(() => {
  mockPathname = '/docs/api'; dark = false; listeners = new Set();
  localStorage.clear(); document.documentElement.className = '';
  delete document.documentElement.dataset.appTheme;
  act(() => window.dispatchEvent(new StorageEvent('storage', { key: APP_THEME_STORAGE_KEY })));
  window.matchMedia = jest.fn(() => ({ get matches() { return dark; },
    addEventListener: (_: string, fn: () => void) => listeners.add(fn),
    removeEventListener: (_: string, fn: () => void) => listeners.delete(fn),
  }) as unknown as MediaQueryList);
});
afterEach(() => { cleanup(); window.history.replaceState({}, '', '/'); jest.restoreAllMocks(); });

test('Light and Dark persist across remounts; System follows live OS changes', async () => {
  const user = userEvent.setup();
  const first = render(view());
  const select = screen.getByRole('combobox', { name: 'Appearance' });
  await user.selectOptions(select, 'dark');
  expect(document.documentElement.dataset.appTheme).toBe('dark');
  expect(localStorage.getItem(APP_THEME_STORAGE_KEY)).toBe('dark');
  first.unmount(); render(view());
  expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('dark');
  osTheme(false);
  expect(document.documentElement.dataset.appTheme).toBe('dark');
  await user.selectOptions(screen.getByRole('combobox'), 'light');
  osTheme(true);
  expect(document.documentElement.dataset.appTheme).toBe('light');
  await user.selectOptions(screen.getByRole('combobox'), 'system');
  expect(document.documentElement.dataset.appTheme).toBe('dark');
  osTheme(false);
  expect(document.documentElement.dataset.appTheme).toBe('light');
  expect(localStorage.getItem(APP_THEME_STORAGE_KEY)).toBe('system');
});

test('saved app preference and cross-tab changes apply on docs and clear on marketing navigation', () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  const mounted = render(view());
  expect(document.documentElement.dataset.appTheme).toBe('dark');
  act(() => {
    localStorage.setItem(APP_THEME_STORAGE_KEY, 'light');
    window.dispatchEvent(new StorageEvent('storage', { key: APP_THEME_STORAGE_KEY }));
  });
  expect((screen.getByRole('combobox') as HTMLSelectElement).value).toBe('light');
  mockPathname = '/'; mounted.rerender(view());
  expect(document.documentElement.dataset.appTheme).toBeUndefined();
  expect(document.documentElement.classList.contains('dark')).toBe(false);
  mockPathname = '/docs/api'; mounted.rerender(view());
  expect(document.documentElement.dataset.appTheme).toBe('light');
  expect(isInteriorPath('/docs/api')).toBe(false);
  expect(isThemedPath('/docs/api')).toBe(true);
  expect(isThemedPath('/docs/api-other')).toBe(false);
});

test.each([
  ['light', true, 'light'], ['dark', false, 'dark'],
  ['system', true, 'dark'], ['system', false, 'light'],
])('prepaint script resolves %s with OS dark=%s to %s', (choice, systemDark, expected) => {
  window.history.replaceState({}, '', '/docs/api');
  localStorage.setItem(APP_THEME_STORAGE_KEY, choice);
  dark = systemDark as boolean;
  Function(APP_THEME_INIT_SCRIPT)();
  expect(document.documentElement.dataset.appTheme).toBe(expected);
  expect(document.documentElement.classList.contains('dark')).toBe(expected === 'dark');
});

test('theme remains usable when browser storage is blocked', async () => {
  jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw new Error('Blocked'); });
  render(view());
  await userEvent.selectOptions(screen.getByRole('combobox'), 'dark');
  expect(document.documentElement.dataset.appTheme).toBe('dark');
  await userEvent.selectOptions(screen.getByRole('combobox'), 'system');
  osTheme(true);
  expect(document.documentElement.dataset.appTheme).toBe('dark');
});
