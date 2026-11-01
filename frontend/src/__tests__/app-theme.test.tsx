/** @jest-environment jsdom */
import React from 'react';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
import { renderToString } from 'react-dom/server';
import { AppThemeDocument, AppThemeProvider, useAppTheme } from '@/components/site/use-app-theme';
import { APP_THEME_STORAGE_KEY, INTERIOR_PATH_PREFIXES } from '@/lib/app-theme-constants';
import fs from 'node:fs';
import path from 'node:path';

let mockPathname = "/settings";
jest.mock("next/navigation", () => ({ usePathname: () => mockPathname }));
let dark = false;
const listeners = new Set<() => void>();
function Choice() {
  const { theme, resolvedTheme, setTheme } = useAppTheme();
  return <><output>{theme}:{resolvedTheme}</output>{(['light', 'dark', 'system'] as const).map(value => <button key={value} onClick={() => setTheme(value)}>{value}</button>)}</>;
}
function mount() { return render(<><AppThemeDocument /><AppThemeProvider><Choice /></AppThemeProvider></>); }
beforeEach(() => {
  dark = false;
  mockPathname = "/settings";
  document.documentElement.classList.remove("dark");
  localStorage.clear();
  listeners.clear();
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: () => ({
    get matches() { return dark; }, addEventListener: (_: string, cb: () => void) => listeners.add(cb),
    removeEventListener: (_: string, cb: () => void) => listeners.delete(cb),
  }) });
});
afterEach(() => { act(() => window.dispatchEvent(new StorageEvent('storage', { key: null }))); cleanup(); jest.restoreAllMocks(); });
test('stored dark choice survives page unmounts; public route clears it before paint', () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  const view = mount();
  expect(screen.getByText('dark:dark')).toBeTruthy();
  expect(document.documentElement.classList.contains('dark')).toBe(true);
  view.rerender(<AppThemeDocument />);
  expect(document.documentElement.classList.contains('dark')).toBe(true);
  mockPathname = '/pricing';
  view.rerender(<AppThemeDocument />);
  expect(document.documentElement.classList.contains('dark')).toBe(false);
  view.unmount();
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
  // Restore storage while mounted to clear the intentionally session-only choice.
  jest.restoreAllMocks();
  fireEvent.click(screen.getByRole('button', { name: 'system' }));
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
  const run = (pathname: string) => new Function('window', 'document', script)({ location: { pathname }, localStorage: { getItem: () => { throw new Error('blocked'); } }, matchMedia: () => ({ matches: true }) }, { documentElement: { classList }, querySelector: () => null });
  for (const pathname of ['/worlds/personal', '/settings/memory', '/agent-approvals/test', '/inventory-access-request/test']) {
    run(pathname); expect(classList.add).toHaveBeenLastCalledWith('dark'); classList.add.mockClear();
  }
  for (const pathname of ['/', '/signin', '/pricing', '/worlds-other']) { run(pathname); expect(classList.add).not.toHaveBeenCalled(); }
});

test('interior route changes and replacement shells never clear the dark document', () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  const view = mount();
  const remove = jest.spyOn(document.documentElement.classList, 'remove');
  const toggle = jest.spyOn(document.documentElement.classList, 'toggle');
  for (const route of ['/worlds/personal', '/notifications', '/settings/memory', '/inventory']) {
    mockPathname = route;
    view.rerender(<><AppThemeDocument /><div role="status">Loading</div></>);
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    view.rerender(<><AppThemeDocument /><AppThemeProvider key={route}><Choice /></AppThemeProvider></>);
    expect(document.documentElement.classList.contains('dark')).toBe(true);
  }
  expect(remove).not.toHaveBeenCalledWith('dark');
  expect(toggle).not.toHaveBeenCalledWith('dark', false);
});

test('marketing remains light and re-entering the app restores preference', () => {
  localStorage.setItem(APP_THEME_STORAGE_KEY, 'dark');
  const meta = document.createElement('meta'); meta.name = 'theme-color'; document.head.append(meta);
  const view = mount();
  for (const route of ['/', '/signin', '/pricing', '/worlds-other']) {
    mockPathname = route;
    view.rerender(<><AppThemeDocument /><AppThemeProvider><Choice /></AppThemeProvider></>);
    expect(document.documentElement.classList.contains('dark')).toBe(false);
    expect(meta.content).toBe('#ffffff');
  }
  mockPathname = '/worlds/personal';
  view.rerender(<><AppThemeDocument /><AppThemeProvider><Choice /></AppThemeProvider></>);
  expect(document.documentElement.classList.contains('dark')).toBe(true);
  expect(meta.content).toBe('#0b0b0d');
  meta.remove();
});
