/** @jest-environment jsdom */
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConnectionsDocs } from '@/components/site/connections-docs';
import { ConnectionsDocsNavigation, connectionsSections } from '@/components/site/connections-docs-navigation';
import ConnectionsDocumentationPage from '@/app/docs/connections/page';
import { worldNavigation } from '@/lib/world-navigation';
import { isInteriorPath, isThemedPath } from '@/lib/app-theme-constants';
import sitemap from '@/app/sitemap';

test('public guide has complete section navigation, appearance support, and a management entry point', () => {
  const { container } = render(<ConnectionsDocs />);
  expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Keep your purchases in context.');
  for (const [id] of connectionsSections) expect(container.querySelector(`#${id}`)).not.toBeNull();
  for (const anchor of container.querySelectorAll('a[href^="#"]')) expect(container.querySelector(anchor.getAttribute('href')!)).not.toBeNull();
  const ids = Array.from(container.querySelectorAll('[id]')).map(node => node.id);
  expect(new Set(ids).size).toBe(ids.length);
  expect(screen.getAllByRole('link', { name: /Manage connections/ }).every(link => link.getAttribute('href') === '/settings/connections')).toBe(true);
  expect(isThemedPath('/docs/connections')).toBe(true);
  expect(isInteriorPath('/docs/connections')).toBe(false);
  expect(sitemap().some(entry => entry.url === 'https://findez.ai/docs/connections')).toBe(true);
});

test('topic search filters relevant links, announces empty results, and clears', async () => {
  const user = userEvent.setup(); render(<ConnectionsDocsNavigation />);
  const input = screen.getByRole('searchbox', { name: 'Find a Connections topic' });
  await user.type(input, 'safari');
  expect(screen.getByRole('link').getAttribute('href')).toBe('#amazon');
  await user.clear(input); await user.type(input, 'no-such-topic');
  expect(screen.getByRole('status').textContent).toBe('0 topics found');
  await user.click(screen.getByRole('button', { name: 'Clear search' }));
  expect(screen.getAllByRole('link')).toHaveLength(connectionsSections.length);
});

test('organization context is encoded through navigation and the guide into the existing management route', async () => {
  const organization = 'org/a&b';
  const entry = worldNavigation(organization, 'Example').items.find(item => item.label === 'Connections');
  expect(entry?.route).toBe('/docs/connections?organization=org%2Fa%26b');
  expect(worldNavigation('personal', 'Personal').items.find(item => item.label === 'Connections')?.route).toBe('/docs/connections');
  render(await ConnectionsDocumentationPage({ searchParams: Promise.resolve({ organization }) }));
  expect(screen.getAllByRole('link', { name: /Manage connections/ }).every(link => link.getAttribute('href') === '/settings/connections?organization=org%2Fa%26b')).toBe(true);
});

test.each([{ organization: ['a', 'b'] }, { organization: 'a'.repeat(201) }])('ignores invalid organization query shape or length', async ({ organization }) => {
  render(await ConnectionsDocumentationPage({ searchParams: Promise.resolve({ organization }) }));
  expect(screen.getAllByRole('link', { name: /Manage connections/ }).every(link => link.getAttribute('href') === '/settings/connections')).toBe(true);
});
