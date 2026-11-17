/** @jest-environment jsdom */
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CadDocs } from '@/components/site/cad-docs';
import { CadDocsNavigation, cadSections } from '@/components/site/cad-docs-navigation';
import { isThemedPath, isInteriorPath } from '@/lib/app-theme-constants';

test('CAD guide is public, uses appearance controls, and retains all old guide anchors', () => {
  const { container } = render(<CadDocs />);
  expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Connect your design to your inventory.');
  expect(screen.getByLabelText('Appearance')).toBeTruthy();
  expect(isThemedPath('/docs/cad')).toBe(true);
  expect(isInteriorPath('/docs/cad')).toBe(false);
  for (const [id] of cadSections) expect(container.querySelector(`#${id}`)).not.toBeNull();
  for (const a of container.querySelectorAll('a[href^="#"]')) expect(container.querySelector(a.getAttribute('href')!)).not.toBeNull();
  const ids = Array.from(container.querySelectorAll('[id]')).map(node => node.id);
  expect(new Set(ids).size).toBe(ids.length);
  expect(screen.getAllByRole('link', { name: 'Fusion workspace ZIP' }).every(link => link.getAttribute('href') === '/downloads/findez-fusion-workspace.zip?v=0.4.1')).toBe(true);
  expect(screen.getByText('Legacy export-only add-in (superseded)').closest('tr')?.textContent).toContain('Does not include Open FindEZ');
  expect(container.querySelector('#onshape')?.textContent).toContain('not available in this production release');
  expect(container.querySelector('#roadmap')?.textContent).toContain('planned, not available');
});

test('topic search finds Windows errors, handles no results and clears', async () => {
  const user = userEvent.setup(); render(<CadDocsNavigation />);
  const search = screen.getByRole('searchbox', { name: 'Find a CAD topic' });
  await user.type(search, 'site reached');
  expect(screen.getByRole('status').textContent).toBe('1 topic found');
  expect(screen.getByRole('link').getAttribute('href')).toBe('#troubleshooting');
  await user.clear(search); await user.type(search, 'not-a-topic');
  expect(screen.getByRole('status').textContent).toBe('0 topics found');
  await user.click(screen.getByRole('button', { name: 'Clear search' }));
  expect(screen.getAllByRole('link')).toHaveLength(cadSections.length);
});

test('comparison links retain the organization while the public page remains separate', () => {
  render(<CadDocs world="team / robotics" />);
  const main = screen.getByRole('main');
  expect(within(main).getAllByRole('link', { name: 'Open comparison tool ↗' })[0].getAttribute('href')).toBe('/cad?world=team%20%2F%20robotics');
  expect(within(main).getByRole('link', { name: 'public CAD Intelligence page' }).getAttribute('href')).toBe('/cad-intelligence');
});


test('CAD hub groups setup, Fusion, file comparison and help with a beginner path', () => {
  render(<CadDocs />);
  const nav = screen.getByRole('navigation', { name: 'CAD documentation' });
  for (const label of ['Get started', 'Work in Fusion', 'Compare a file', 'Reference & help']) expect(within(nav).getByText(label)).toBeTruthy();
  expect(screen.getByRole('table', { name: 'CAD tools and guides' })).toBeTruthy();
  expect(screen.getByRole('heading', { name: 'Create your first design' })).toBeTruthy();
  expect(screen.getByText('Generate model is disabled or I cannot click it')).toBeTruthy();
  expect(screen.getByRole('table', { name: 'Generation status and next step' })).toBeTruthy();
});
