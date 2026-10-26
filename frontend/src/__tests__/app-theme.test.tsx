/** @jest-environment jsdom */
import React from 'react';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { renderToString } from 'react-dom/server';
import { AppThemeProvider, useAppTheme } from '@/components/site/use-app-theme';
import { APP_THEME_STORAGE_KEY, INTERIOR_PATH_PREFIXES } from '@/lib/app-theme-constants';
import fs from 'node:fs';
import path from 'node:path';

let dark = false;
const listeners = new Set<() => void>();
function Choice() {
  const { theme, resolvedTheme, setTheme } = useAppTheme();
  return <><output>{theme}:{resolvedTheme}</output>{(['light', 'dark', 'system'] as const).map(value => <button key={value} onClick={() => setTheme(value)}>{value}</button>)}</>;
}
function mount() { return render(<AppThemeProvider><Choice /></AppThemeProvider>); }
beforeEach(() => {
  dark = false;
  localStorage.clear();
  listeners.clear();
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: () => ({
    get matches() { return dark; }, addEventListener: (_: string, cb: () => void) => listeners.add(cb),
    removeEventListener: (_: string, cb: () => void) => listeners.delete(cb),
  }) });
});
afterEach(() => { cleanup(); jest.restoreAllMocks(); });
test('stored dark choice survives mounting and cleans up when leaving the app', () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  const view = mount();
  expect(screen.getByText('dark:dark')).toBeTruthy();
  expect(document.documentElement.classList.contains('dark')).toBe(true);
  view.unmount();
  expect(document.documentElement.classList.contains('dark')).toBe(false);
  expect(listeners.size).toBe(0);
});
test('explicit choice wins over the OS and system follows later OS changes', () => {
  mount();
  fireEvent.click(screen.getByRole('button', { name: 'light' }));
  act(() => { dark = true; listeners.forEach(fn => fn()); });
  expect(screen.getByText('light:light')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'system' }));
  expect(screen.getByText('system:dark')).toBeTruthy();
  expect(localStorage.getItem(APP_THEME_STORAGE_KEY)).toBeNull();
  act(() => { dark = false; listeners.forEach(fn => fn()); });
  expect(document.documentElement.classList.contains('dark')).toBe(false);
});
test('appearance updates across tabs, including clearing saved preferences', () => {
  mount();
  act(() => { localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark'); window.dispatchEvent(new StorageEvent('storage', { key: APP_THEME_STORAGE_KEY })); });
  expect(screen.getByText('dark:dark')).toBeTruthy();
  act(() => { localStorage.clear(); window.dispatchEvent(new StorageEvent('storage', { key: null })); });
  expect(screen.getByText('system:light')).toBeTruthy();
});
test('blocked storage neither crashes the app nor disables the theme controls', () => {
  dark = true;
  jest.spyOn(Storage.prototype, 'getItem').mockImplementation(() => { throw new Error('blocked'); });
  jest.spyOn(Storage.prototype, 'setItem').mockImplementation(() => { throw new Error('blocked'); });
  jest.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => { throw new Error('blocked'); });
  mount();
  expect(screen.getByText('system:dark')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'light' }));
  expect(screen.getByText('light:light')).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'system' }));
  expect(screen.getByText('system:dark')).toBeTruthy();
});
test('server render is independent of local browser preferences for hydration', () => {
  const tree = <AppThemeProvider><Choice /></AppThemeProvider>;
  const before = renderToString(tree);
  dark = true; localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  expect(renderToString(tree)).toBe(before);
});
test('prepaint script follows OS preference even if storage is blocked', () => {
  const layout = fs.readFileSync(path.join(process.cwd(), 'src/app/layout.tsx'), 'utf8');
  const template = layout.match(/const THEME_INIT_SCRIPT = `([^`]+)`/)![1];
  const script = template.replace('${INTERIOR_PATH_PREFIXES.join(\'","\')}', INTERIOR_PATH_PREFIXES.join('\",\"'))
    .replace('${JSON.stringify(APP_THEME_STORAGE_KEY)}', JSON.stringify(APP_THEME_STORAGE_KEY));
  const classList = { add: jest.fn() };
  const run = (pathname: string) => new Function('window', 'document', script)({ location: { pathname }, localStorage: { getItem: () => { throw new Error('blocked'); } }, matchMedia: () => ({ matches: true }) }, { documentElement: { classList } });
  for (const pathname of ['/worlds/personal', '/settings/memory', '/agent-approvals/test', '/inventory-access-request/test']) {
    run(pathname); expect(classList.add).toHaveBeenLastCalledWith('dark'); classList.add.mockClear();
  }
  for (const pathname of ['/', '/signin', '/pricing', '/worlds-other']) { run(pathname); expect(classList.add).not.toHaveBeenCalled(); }
});
