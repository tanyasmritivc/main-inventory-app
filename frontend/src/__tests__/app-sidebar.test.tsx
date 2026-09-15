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

const workspaceLinks = [
  { label: 'Inventory', route: '/inventory' },
  { label: 'Add items', route: '/scan' },
  { label: 'Ask FindEZ', route: '/assist' },
  { label: 'Team', route: '/teams' },
];
const originalWidth = window.innerWidth;

beforeEach(() => {
  jest.mocked(usePathname).mockReturnValue('/inventory');
  window.innerWidth = 1024;
});

afterEach(() => {
  window.innerWidth = originalWidth;
});

test('keeps the primary workspace compact and leaves developer tools in Settings', () => {
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  const workspace = within(screen.getByText('Workspace').parentElement!);
  for (const { label, route } of workspaceLinks) {
    expect(workspace.getByRole('link', { name: label }).getAttribute('href')).toBe(route);
  }
  const tools = within(screen.getByText('Tools').parentElement!);
  expect(tools.getByRole('link', { name: 'Documents' }).getAttribute('href')).toBe('/documents');
  expect(screen.queryByRole('link', { name: 'API keys' })).toBeNull();
  expect(screen.queryByRole('link', { name: 'API documentation' })).toBeNull();
  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
});

test.each(workspaceLinks)('highlights only $label on its route', ({ label, route }) => {
  jest.mocked(usePathname).mockReturnValue(route);
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(Array.from(container.querySelectorAll('a.is-active'))).toEqual([
    screen.getByRole('link', { name: label }),
  ]);
});

test('uses Settings as the developer entry point', () => {
  jest.mocked(usePathname).mockReturnValue('/settings/api-keys/new');
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
  expect(screen.queryByRole('link', { name: 'API keys' })).toBeNull();
});

describe.each([
  { viewport: 'mobile', width: 390, expectedToggles: 1 },
  { viewport: 'desktop', width: 1024, expectedToggles: 0 },
])('$viewport navigation', ({ width, expectedToggles }) => {
  test.each(workspaceLinks)('$label preserves the sidebar behavior', async ({ label }) => {
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
