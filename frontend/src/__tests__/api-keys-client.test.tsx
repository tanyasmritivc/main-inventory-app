/** @jest-environment jsdom */

import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ApiKeysClient } from '@/components/site/api-keys-client';
import * as api from '@/lib/integration-api';
import { useApiSession } from '@/lib/use-api-session';

jest.mock('@/lib/integration-api', () => ({
  ...jest.requireActual('@/lib/integration-api'),
  listIntegrationKeys: jest.fn(), listKeyWorkspaces: jest.fn(),
  createIntegrationKey: jest.fn(), revokeIntegrationKey: jest.fn(), testIntegrationKey: jest.fn(),
}));
jest.mock('@/lib/use-api-session');
const confirmAction = jest.fn();
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction }) }));

const metadata: api.IntegrationKey = {
  id: 'key-1', name: 'Team spreadsheet', workspace_id: 'team-1', key_prefix: 'findez_live_sk_abcdef',
  scopes: ['items:read', 'workspace:read'], created_at: '2026-09-01T00:00:00Z',
  last_used_at: null, expires_at: null, revoked_at: null,
};
const rawKey = 'findez_live_sk_abcdefghijklmnopqrstuvwxyz123456';
const getSession = jest.fn();

beforeEach(() => {
  jest.clearAllMocks();
  getSession.mockResolvedValue({ data: { session: { access_token: 'fresh-web-session' } } });
  jest.mocked(useApiSession).mockReturnValue({ token: 'web-session', loading: false, error: null, supabase: { auth: { getSession } } } as unknown as ReturnType<typeof useApiSession>);
  jest.mocked(api.listIntegrationKeys).mockResolvedValue({ keys: [] });
  jest.mocked(api.listKeyWorkspaces).mockResolvedValue({ workspaces: [{ team_id: 'team-1', name: 'Robotics team' }] });
  jest.mocked(api.createIntegrationKey).mockResolvedValue({ ...metadata, key: rawKey });
  confirmAction.mockResolvedValue(true);
});

async function createKey(user: ReturnType<typeof userEvent.setup>) {
  await user.type(await screen.findByLabelText('Key name'), 'Team spreadsheet');
  await user.click(screen.getByRole('button', { name: 'Create key' }));
  return screen.findByLabelText('Your new API key');
}

test('creates with read-only defaults, fresh auth, then removes raw key after dismissal', async () => {
  const user = userEvent.setup();
  render(<ApiKeysClient />);
  const input = await createKey(user);
  expect((input as HTMLInputElement).value).toBe(rawKey);
  expect(api.createIntegrationKey).toHaveBeenCalledWith('fresh-web-session', expect.objectContaining({
    workspace_id: 'team-1', scopes: ['items:read', 'workspace:read'], name: 'Team spreadsheet',
  }));
  await user.click(screen.getByRole('button', { name: 'I’ve saved my key' }));
  expect(screen.queryByDisplayValue(rawKey)).toBeNull();
  expect(screen.getByText(`${metadata.key_prefix}…`)).toBeTruthy();
});

test('organization choice changes scopes instead of mixing key types', async () => {
  const user = userEvent.setup(); render(<ApiKeysClient />);
  await user.selectOptions(await screen.findByLabelText('Access'), 'organization');
  await createKey(user);
  expect(api.createIntegrationKey).toHaveBeenCalledWith('fresh-web-session', expect.objectContaining({ workspace_id: null, scopes: ['org:read'] }));
});

test('test connection uses the generated key and preserves it on failure', async () => {
  const user = userEvent.setup();
  jest.mocked(api.testIntegrationKey).mockRejectedValue(new Error('Inventory is unavailable.'));
  render(<ApiKeysClient />); await createKey(user);
  await user.click(screen.getByRole('button', { name: 'Test connection' }));
  expect(await screen.findByRole('alert')).toHaveProperty('textContent', 'Inventory is unavailable.');
  expect(api.testIntegrationKey).toHaveBeenCalledWith(rawKey);
  expect(screen.getByDisplayValue(rawKey)).toBeTruthy();
});

test('copy failure leaves the secret selectable and displays an error', async () => {
  const user = userEvent.setup();
  jest.spyOn(navigator.clipboard, 'writeText').mockRejectedValueOnce(new Error('denied'));
  render(<ApiKeysClient />); await createKey(user);
  await user.click(screen.getByRole('button', { name: 'Copy key' }));
  expect((await screen.findByRole('alert')).textContent).toContain('copy it manually');
  expect(screen.getByDisplayValue(rawKey)).toBeTruthy();
});

test('revokes only after confirmation and shows failure without marking it revoked', async () => {
  const user = userEvent.setup();
  jest.mocked(api.listIntegrationKeys).mockResolvedValue({ keys: [metadata] });
  jest.mocked(api.revokeIntegrationKey).mockRejectedValue(new Error('Could not revoke the key.'));
  render(<ApiKeysClient />);
  await user.click(await screen.findByRole('button', { name: 'Revoke Team spreadsheet' }));
  expect(await screen.findByRole('alert')).toHaveProperty('textContent', 'Could not revoke the key.');
  expect(screen.getByText('Active')).toBeTruthy();
  expect(confirmAction).toHaveBeenCalledTimes(1);
});

test('successful revocation updates the key status', async () => {
  const user = userEvent.setup();
  jest.mocked(api.listIntegrationKeys).mockResolvedValue({ keys: [metadata] });
  jest.mocked(api.revokeIntegrationKey).mockResolvedValue({ revoked: true, revoked_at: '2026-09-09T00:00:00Z' });
  render(<ApiKeysClient />);
  await user.click(await screen.findByRole('button', { name: 'Revoke Team spreadsheet' }));
  expect(await screen.findByText('Revoked')).toBeTruthy();
  expect(screen.queryByRole('button', { name: 'Revoke Team spreadsheet' })).toBeNull();
});

test('owners with no teams receive an actionable setup path', async () => {
  jest.mocked(api.listKeyWorkspaces).mockResolvedValue({ workspaces: [] });
  render(<ApiKeysClient />);
  expect(await screen.findByText('Create a team to use integrations')).toBeTruthy();
  expect(screen.getByRole('link', { name: 'Open Teams →' }).getAttribute('href')).toBe('/teams');
  expect(screen.queryByRole('button', { name: 'Create key' })).toBeNull();
  expect(screen.getByRole('link', { name: 'API documentation →' }).getAttribute('href')).toBe('/docs/api');
});

test('failed loading shows retry and never presents an empty success state', async () => {
  const user = userEvent.setup();
  jest.mocked(api.listIntegrationKeys).mockRejectedValueOnce(new Error('Connection failed.'));
  render(<ApiKeysClient />);
  await user.click(await screen.findByRole('button', { name: 'Retry' }));
  await waitFor(() => expect(screen.queryByRole('alert')).toBeNull());
  expect(await screen.findByLabelText('Key name')).toBeTruthy();
});
