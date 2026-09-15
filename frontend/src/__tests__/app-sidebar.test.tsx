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

test('keeps workspace tools compact and gives APIs their own section', () => {
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  const workspace = within(screen.getByText('Workspace').parentElement!);
  for (const { label, route } of workspaceLinks) {
    expect(workspace.getByRole('link', { name: label }).getAttribute('href')).toBe(route);
  }
  const tools = within(screen.getByText('Tools').parentElement!);
  expect(tools.getByRole('link', { name: 'Documents' }).getAttribute('href')).toBe('/documents');
  const api = within(screen.getByText('API').parentElement!);
  expect(api.getByRole('link', { name: 'API keys' }).getAttribute('href')).toBe('/settings/api-keys');
  expect(api.getByRole('link', { name: 'API documentation' }).getAttribute('href')).toBe('/docs/api');
  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
});

test('marks the collapsed desktop sidebar as hover-expandable', () => {
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen={false} />);
  const sidebar = container.querySelector('aside');

  expect(sidebar?.classList.contains('is-hover-expandable')).toBe(true);
  expect(sidebar?.classList.contains('is-open')).toBe(false);
});

test.each(workspaceLinks)('highlights only $label on its route', ({ label, route }) => {
  jest.mocked(usePathname).mockReturnValue(route);
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(Array.from(container.querySelectorAll('a.is-active'))).toEqual([
    screen.getByRole('link', { name: label }),
  ]);
});

test('highlights API keys independently from Settings', () => {
  jest.mocked(usePathname).mockReturnValue('/settings/api-keys/new');
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
  expect(screen.getByRole('link', { name: 'Settings' }).classList.contains('is-active')).toBe(false);
  expect(screen.getByRole('link', { name: 'API keys' }).classList.contains('is-active')).toBe(true);
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
