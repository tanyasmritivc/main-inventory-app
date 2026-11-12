import { createIntegrationKey, listIntegrationKeys, testIntegrationKey } from '../lib/integration-api';

const fetchMock = jest.fn();
beforeEach(() => { jest.clearAllMocks(); global.fetch = fetchMock; });
function response(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status }); }

test('key creation uses user authentication and disables caching', async () => {
  fetchMock.mockResolvedValue(response({ key: 'new-key' }, 201));
  const body = { name: 'Reporting', workspace_id: 'team', scopes: ['items:read' as const], expires_at: null };
  await createIntegrationKey('user-token', body);
  expect(fetchMock).toHaveBeenCalledWith(expect.stringContaining('/api/v1/keys'), expect.objectContaining({
    method: 'POST', cache: 'no-store', body: JSON.stringify(body), headers: expect.objectContaining({ Authorization: 'Bearer user-token' }),
  }));
});

test('connection test exercises inventory access for read keys', async () => {
  fetchMock.mockResolvedValueOnce(response({ scopes: ['items:read'] })).mockResolvedValueOnce(response({ value: 42 }));
  expect(await testIntegrationKey('api-key')).toBe('Connected. This key can read 42 inventory items.');
  expect(fetchMock.mock.calls[1][1].body).toBe(JSON.stringify({ resource: 'items', aggregate: 'count' }));
  expect(fetchMock.mock.calls[1][1].headers.Authorization).toBe('Bearer api-key');
});

test('write-only connection test never writes data', async () => {
  fetchMock.mockResolvedValue(response({ scopes: ['items:write'] }));
  expect(await testIntegrationKey('api-key')).toContain('Write permissions were not exercised');
  expect(fetchMock).toHaveBeenCalledTimes(1);
  expect(fetchMock.mock.calls[0][1].method).toBe('GET');
});

test('structured errors are useful without exposing untrusted backend details', async () => {
  fetchMock.mockResolvedValueOnce(response({ detail: { code: 'revoked_api_key', message: 'secret internal detail' } }, 401));
  await expect(testIntegrationKey('key')).rejects.toThrow('This API key has been revoked.');
  fetchMock.mockResolvedValueOnce(response({ detail: { message: 'secret traceback' } }, 503));
  await expect(listIntegrationKeys('token')).rejects.toThrow('The request could not be completed.');
});
