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
  { label: 'Home', route: '/home' },
  { label: 'Capture', route: '/scan' },
  { label: 'Review', route: '/review' },
  { label: 'Inventory', route: '/inventory' },
  { label: 'Ask FindEZ', route: '/assist' },
  { label: 'Check-outs', route: '/checkout' },
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

test('orders the workspace flow and keeps developer links in Settings', () => {
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  const workspace = within(screen.getByText('Workspace').parentElement!);
  for (const { label, route } of workspaceLinks) {
    expect(workspace.getByRole('link', { name: label }).getAttribute('href')).toBe(route);
  }
  expect(workspace.getAllByRole('link').map((link) => link.textContent)).toEqual(workspaceLinks.map(({ label }) => label));
  const tools = within(screen.getByText('Tools').parentElement!);
  expect(tools.getByRole('link', { name: 'Smart collections' }).getAttribute('href')).toBe('/collections');
  expect(tools.getByRole('link', { name: 'Project kits' }).getAttribute('href')).toBe('/project-kits');
  expect(tools.getByRole('link', { name: 'Documents' }).getAttribute('href')).toBe('/documents');
  expect(tools.getByRole('link', { name: 'Labels' }).getAttribute('href')).toBe('/labels');
  expect(tools.getAllByRole('link').map((link) => link.textContent)).toEqual(['Smart collections', 'Project kits', 'Documents', 'Labels']);
  expect(screen.queryByText('API')).toBeNull();
  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
});

test('the collapsed desktop sidebar toggle stays in the DOM (never hover-only)', () => {
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen={false} />);
  const sidebar = container.querySelector('aside');
  const toggle = within(sidebar as HTMLElement).getByRole('button', { name: 'Open navigation' });

  expect(sidebar?.classList.contains('is-open')).toBe(false);
  expect(toggle).not.toBeNull();
});

test('uses the landing page mark in the workspace sidebar', () => {
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);
  const brand = screen.getByRole('link', { name: 'FindEZ home' });
  const paths = container.querySelectorAll('.app-sidebar-logo path');

  expect(brand.textContent).toBe('FindEZ');
  expect(paths).toHaveLength(2);
  expect(paths[0].getAttribute('d')).toBe('M28 38H58V68');
  expect(paths[1].getAttribute('stroke')).toBe('#E8590C');
});

test.each(workspaceLinks)('highlights only $label on its route', ({ label, route }) => {
  jest.mocked(usePathname).mockReturnValue(route);
  const { container } = render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(Array.from(container.querySelectorAll('a.is-active'))).toEqual([
    screen.getByRole('link', { name: label }),
  ]);
});

test('keeps Settings inactive on its developer child route', () => {
  jest.mocked(usePathname).mockReturnValue('/settings/api-keys/new');
  render(<AppSidebar onToggle={jest.fn()} sidebarOpen />);

  expect(screen.getByRole('link', { name: 'Settings' }).getAttribute('href')).toBe('/settings');
  expect(screen.getByRole('link', { name: 'Settings' }).classList.contains('is-active')).toBe(false);
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
