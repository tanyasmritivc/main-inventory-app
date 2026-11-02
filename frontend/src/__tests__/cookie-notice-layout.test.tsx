/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from '@testing-library/react';
import { CookieNotice } from '@/components/site/cookie-notice';
import { LEGAL_VERSION } from '@/lib/legal-content';

let resize: () => void;
const disconnect = jest.fn();
beforeEach(() => {
  localStorage.clear();
  disconnect.mockClear();
  global.ResizeObserver = class {
    constructor(callback: () => void) { resize = callback; }
    observe() {}
    unobserve() {}
    disconnect = disconnect;
  } as unknown as typeof ResizeObserver;
});

test('reserves the actual notice height, responds to wrapping, and releases it on unmount', () => {
  const rect = jest.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({ height: 70 } as DOMRect);
  const view = render(<CookieNotice />);
  expect(document.documentElement.style.getPropertyValue('--cookie-notice-height')).toBe('110px');
  rect.mockReturnValue({ height: 118.4 } as DOMRect);
  act(() => resize());
  expect(document.documentElement.style.getPropertyValue('--cookie-notice-height')).toBe('159px');
  view.unmount();
  expect(document.documentElement.style.getPropertyValue('--cookie-notice-height')).toBe('');
  expect(disconnect).toHaveBeenCalledTimes(1);
  rect.mockRestore();
});

test('dismissal preserves the existing legal-version preference and restores available space', () => {
  render(<CookieNotice />);
  fireEvent.click(screen.getByRole('button', { name: 'Got it' }));
  expect(screen.queryByRole('complementary')).toBeNull();
  expect(localStorage.getItem('findez-cookie-notice')).toBe(LEGAL_VERSION);
  expect(document.documentElement.style.getPropertyValue('--cookie-notice-height')).toBe('');
});
