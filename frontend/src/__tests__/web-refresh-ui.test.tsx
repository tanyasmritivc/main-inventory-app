/** @jest-environment jsdom */
import { act, fireEvent, render, renderHook, screen } from '@testing-library/react';
import { QuickStart, SpaceInfoLine, useHomePlaceholder } from '@/components/site/web-refresh-ui';

let reduced = false;
beforeEach(() => {
  jest.useFakeTimers();
  reduced = false;
  Object.defineProperty(window, 'matchMedia', { configurable: true, value: jest.fn(() => ({ matches: reduced, addEventListener: jest.fn(), removeEventListener: jest.fn() })) });
});
afterEach(() => { jest.useRealTimers(); });
test('home hints stop on focus and honor reduced motion', () => {
  const { result, unmount } = renderHook(() => useHomePlaceholder(true, ''));
  act(() => jest.advanceTimersByTime(1500));
  expect(result.current.placeholder).toMatch(/^Where/);
  act(() => result.current.stopPlaceholder());
  act(() => jest.advanceTimersByTime(5000));
  expect(result.current.placeholder).toBe('Ask about your inventory...');
  unmount(); reduced = true;
  const quiet = renderHook(() => useHomePlaceholder(true, ''));
  act(() => jest.advanceTimersByTime(5000));
  expect(quiet.result.current.placeholder).toBe('Ask about your inventory...');
});
test('typed drafts suppress hints; contextual composers do not animate', () => {
  const { result, rerender } = renderHook(({ enabled, value }) => useHomePlaceholder(enabled, value), { initialProps: { enabled: false, value: '' } });
  act(() => jest.advanceTimersByTime(5000));
  expect(result.current.placeholder).toBe('Ask about your inventory...');
  rerender({ enabled: true, value: 'My draft' });
  act(() => jest.advanceTimersByTime(5000));
  expect(result.current.placeholder).toBe('Ask about your inventory...');
});
test('quick start dispatches the supplied existing actions once and respects disabled state', () => {
  const handlers = { onPhoto: jest.fn(), onImport: jest.fn(), onFind: jest.fn(), onLow: jest.fn() };
  const { rerender } = render(<QuickStart disabled={false} {...handlers} />);
  for (const name of ['Scan a photo', 'Import a sheet', 'Find an item', 'Running low']) fireEvent.click(screen.getByRole('button', { name: new RegExp(name) }));
  Object.values(handlers).forEach(fn => expect(fn).toHaveBeenCalledTimes(1));
  rerender(<QuickStart disabled {...handlers} />);
  fireEvent.click(screen.getByRole('button', { name: /Running low/ }));
  expect(handlers.onLow).toHaveBeenCalledTimes(1);
});
test('space metadata omits unavailable values and uses supplied low stock flags', () => {
  jest.setSystemTime(new Date('2026-11-04T12:00:00Z'));
  const { container, rerender } = render(<SpaceInfoLine />);
  expect(container.textContent).toBe('');
  rerender(<SpaceInfoLine units={7583} low={2} addedAt="2026-11-02T12:00:00Z" />);
  expect(screen.getByText('7,583 units')).toBeTruthy();
  expect(screen.getByText('2 running low')).toBeTruthy();
  expect(screen.getByText('Added 2 days ago')).toBeTruthy();
  rerender(<SpaceInfoLine units={0} low={0} createdAt="2026-11-04T12:00:00Z" />);
  expect(screen.queryByText(/running low/)).toBeNull();
  expect(screen.getByText('Created today')).toBeTruthy();
});
