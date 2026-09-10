/** @jest-environment jsdom */
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ApiDocs } from '@/components/site/api-docs';
import { CodeExample, DocsNavigation, guideSections } from '@/components/site/api-docs-controls';
import { endpoints, requestExamples } from '@/lib/api-reference';
import sitemap from '@/app/sitemap';

test('renders public documentation, every endpoint, and working section anchors without authentication', () => {
  const { container } = render(<ApiDocs />);
  expect(screen.getByRole('heading', { level: 1 }).textContent).toBe('Build with your inventory.');
  expect(endpoints).toHaveLength(12);
  for (const endpoint of endpoints) {
    const section = container.querySelector(`#${endpoint.operationId}`);
    expect(section).not.toBeNull();
    expect(within(section as HTMLElement).getByRole('heading', { name: endpoint.summary })).toBeTruthy();
  }
  for (const [id] of guideSections) expect(container.querySelector(`#${id}`)).not.toBeNull();
  const ids = Array.from(container.querySelectorAll('[id]')).map((node) => node.id);
  expect(new Set(ids).size).toBe(ids.length);
  for (const anchor of container.querySelectorAll('a[href^="#"]')) {
    expect(container.querySelector(anchor.getAttribute('href')!)).not.toBeNull();
  }
  expect(screen.getAllByRole('link', { name: /OpenAPI/ }).every((link) => link.getAttribute('href') === '/docs/api/openapi.json')).toBe(true);
  expect(sitemap().some((entry) => entry.url === 'https://findez.ai/docs/api')).toBe(true);
});

test('endpoint search finds behavior, supports empty results, and can be cleared', async () => {
  const user = userEvent.setup(); render(<DocsNavigation />);
  const search = screen.getByRole('searchbox', { name: 'Find an endpoint' });
  await user.type(search, 'sum_quantity');
  expect(screen.getByRole('status').textContent).toBe('1 endpoint found');
  expect(screen.getByRole('link').getAttribute('href')).toBe(`#${endpoints.find((entry) => entry.path === '/api/v1/query')!.operationId}`);
  await user.clear(search); await user.type(search, 'does-not-exist');
  expect(screen.getByRole('status').textContent).toBe('0 endpoints found');
  await user.click(screen.getByRole('button', { name: 'Clear search' }));
  expect(screen.getAllByRole('link')).toHaveLength(endpoints.length + guideSections.length);
});

test('language selection copies exactly the selected example and reports clipboard failure', async () => {
  const user = userEvent.setup();
  const examples = requestExamples(endpoints.find((entry) => entry.path === '/api/v1/query')!);
  const clipboard = jest.spyOn(navigator.clipboard, 'writeText').mockResolvedValue();
  render(<CodeExample label="Query request" examples={examples} />);
  await user.selectOptions(screen.getByLabelText('Query request language'), 'Python');
  await user.click(screen.getByRole('button', { name: 'Copy Query request' }));
  expect(clipboard).toHaveBeenCalledWith(examples.Python);
  expect(screen.getByRole('status').textContent).toBe('Copied');
  await user.selectOptions(screen.getByLabelText('Query request language'), 'JavaScript');
  expect(screen.queryByRole('status')).toBeNull();
  clipboard.mockRejectedValueOnce(new Error('denied'));
  await user.click(screen.getByRole('button', { name: 'Copy Query request' }));
  expect(screen.getByRole('status').textContent).toContain('Select and copy');
  expect(screen.getByLabelText('Query request', { selector: 'pre' }).textContent).toBe(examples.JavaScript);
});

test('uses owner-session credentials only for key management and preserves supported paths', () => {
  for (const endpoint of endpoints) {
    const examples = requestExamples(endpoint);
    const credential = endpoint.security[0].UserSession ? 'FINDEZ_USER_ACCESS_TOKEN' : 'FINDEZ_API_KEY';
    for (const code of Object.values(examples)) {
      expect(code).toContain(credential);
      expect(code).toContain('https://api.findez.ai/api/v1/');
      expect(code).not.toMatch(/\{(item_id|key_id)\}/);
      expect(code).not.toMatch(/findez_(live|test)_sk_[A-Za-z0-9_-]{32}/);
    }
  }
});
