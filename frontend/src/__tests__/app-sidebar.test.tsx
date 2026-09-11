/** @jest-environment jsdom */

import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { usePathname } from 'next/navigation';
import { AppSidebar } from '@/components/site/app-sidebar';

jest.mock('next/navigation', () => ({
  usePathname: jest.fn(),
  useRouter: () => ({ replace: jest.fn(), refresh: jest.fn() }),
}));
jest.mock('@/lib/supabase/browser', () => ({ createSupabaseBrowserClient: jest.fn() }));

const apiLinks = [
  { label: 'API keys', route: '/settings/api-keys' },
  { label: 'API documentation', route: '/docs/api' },
];
const originalWidth = window.innerWidth;

beforeEach(() => {
  jest.mocked(usePathname).mockReturnValue('/inventory');
  window.innerWidth = 1024;
});

afterEach(() => {
  window.innerWidth = originalWidth;
});

test('links to both API pages under Manage without replacing Documents or Settings', () => {
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  const manage = within(screen.getByText('Manage').parentElement!);
  for (const { label, route } of apiLinks) {
    expect(manage.getByRole('link', { name: label }).getAttribute('href')).toBe(route);
  }
  expect(manage.getByRole('link', { name: 'Documents' }).getAttribute('href')).toBe('/documents');
  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
});

test.each(apiLinks)('highlights only $label on its route', ({ label, route }) => {
  jest.mocked(usePathname).mockReturnValue(route);
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(Array.from(container.querySelectorAll('a.is-active'))).toEqual([
    screen.getByRole('link', { name: label }),
  ]);
});

test('keeps API keys highlighted on a nested key-management route', () => {
  jest.mocked(usePathname).mockReturnValue('/settings/api-keys/new');
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(screen.getByRole('link', { name: 'API keys' }).classList.contains('is-active')).toBe(true);
  expect(screen.getByRole('link', { name: 'Settings' }).classList.contains('is-active')).toBe(false);
});

describe.each([
  { viewport: 'mobile', width: 390, expectedToggles: 1 },
  { viewport: 'desktop', width: 1024, expectedToggles: 0 },
])('$viewport navigation', ({ width, expectedToggles }) => {
  test.each(apiLinks)('$label preserves the sidebar behavior', async ({ label }) => {
    window.innerWidth = width;
    const user = userEvent.setup();
    const onToggle = jest.fn();
    render(<AppSidebar onToggle={onToggle} sidebarOpen />);

    const link = screen.getByRole('link', { name: label });
    // Exercise the click handler without asking jsdom to navigate to another page.
    link.addEventListener('click', (event) => event.preventDefault());
    await user.click(link);

    expect(onToggle).toHaveBeenCalledTimes(expectedToggles);
  });
});
