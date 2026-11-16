/** @jest-environment jsdom */
import { fireEvent, render, screen } from '@testing-library/react';
import { FusionConnect } from '@/components/cad/fusion-connect';

jest.mock('@/lib/supabase/browser', () => ({
  createSupabaseBrowserClient: () => ({ auth: { getSession: async () => ({
    data: { session: { user: { id: 'actor' }, access_token: 'test-only-token' } }, error: null,
  }) } }),
}));
jest.mock('@/lib/session', () => ({ getAccessToken: jest.fn(), getAccessSession: jest.fn() }));
jest.mock('@/lib/inventory-selection', () => ({
  activeInventory: () => ({ accountId: 'actor', inventory_id: '11111111-1111-4111-8111-111111111111', name: 'Test stock' }),
  assertInventory: jest.fn(), inventoryApiPath: (path: string) => path,
}));

const originalFetch = global.fetch;
afterEach(() => { global.fetch = originalFetch; });

test('Fusion approval sends application/json through the real account and API request helpers', async () => {
  const fetchMock = jest.fn(async (_url: string, options: RequestInit) => {
    if (options.method === 'POST') {
      const headers = options.headers as Record<string, string>;
      // Match the API boundary: browser string bodies otherwise default to text/plain.
      const valid = headers['Content-Type'] === 'application/json';
      return { ok: valid, status: valid ? 200 : 422, text: async () => JSON.stringify(valid ? { approved: true } : { detail: 'Invalid request data.' }) };
    }
    return { ok: true, status: 200, text: async () => JSON.stringify({ connections: [] }) };
  });
  global.fetch = fetchMock as unknown as typeof fetch;
  render(<FusionConnect code="ABCD234567" />);
  await screen.findByText(/No active connections/);
  fireEvent.click(screen.getByRole('checkbox'));
  fireEvent.click(screen.getByRole('button', { name: 'Connect this inventory' }));
  await screen.findByText('Connection approved');
  const approval = fetchMock.mock.calls.find(([, options]) => options.method === 'POST')!;
  expect(approval[0]).toMatch(/\/fusion\/pairing\/approve$/);
  expect(approval[1].headers).toMatchObject({ 'Content-Type': 'application/json', Authorization: 'Bearer test-only-token' });
  expect(JSON.parse(approval[1].body as string)).toEqual({ code: 'ABCD234567', inventory_id: '11111111-1111-4111-8111-111111111111' });
});
