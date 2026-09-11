import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFile } from 'node:fs/promises';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { InMemoryTransport } from '@modelcontextprotocol/sdk/inMemory.js';
import { createFindEZServer } from '../src/server.mjs';

const key = 'findez_live_sk_' + 'x'.repeat(32); // Synthetic, never issued.
const itemId = '30000000-0000-4000-8000-000000000001';
const teamId = '20000000-0000-4000-8000-000000000001';
const json = (data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json' } });

async function connect(t, fetchImpl) {
  const server = createFindEZServer({ apiKey: key, fetchImpl });
  const client = new Client({ name: 'findez-test', version: '1.0.0' });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await server.connect(serverTransport);
  await client.connect(clientTransport);
  t.after(async () => { await client.close(); await server.close(); });
  return client;
}
const parse = (response) => JSON.parse(response.content[0].text);

test('SDK handshake discovers exactly the inventory surface and correctly marks write tools', async (t) => {
  const client = await connect(t, () => { throw new Error('Discovery must not read inventory'); });
  assert.equal(client.getServerVersion().name, 'findez');
  const { tools } = await client.listTools();
  assert.equal(tools.length, 8);
  assert.equal(tools.filter((tool) => !tool.annotations.readOnlyHint).length, 3);
  assert.ok(tools.every((tool) => !/delete|revoke|keys/.test(tool.name)));
  assert.ok(tools.every((tool) => tool.inputSchema.additionalProperties === false));
  assert.equal(tools.find((tool) => tool.name === 'findez_query_inventory').annotations.readOnlyHint, true);
  assert.equal(tools.find((tool) => tool.name === 'findez_create_item').annotations.idempotentHint, false);
  assert.equal(tools.find((tool) => tool.name === 'findez_update_item').annotations.destructiveHint, true);
  assert.ok(!JSON.stringify(tools).includes(key));
});

const cases = [
  ['findez_connection', {}, 'GET', '/api/v1/whoami', undefined, { workspace_id: teamId, scopes: ['items:read'] }],
  ['findez_list_items', { page: 2, page_size: 100, workspace_id: teamId }, 'GET', `/api/v1/items?page=2&page_size=100&workspace_id=${teamId}`, undefined, { items: [], page: 2, page_size: 100, total: 0 }],
  ['findez_list_locations', {}, 'GET', '/api/v1/spaces', undefined, { spaces: [] }],
  ['findez_workspace_summary', {}, 'GET', '/api/v1/workspaces/summary', undefined, { workspaces: [] }],
  ['findez_query_inventory', { filters: [{ field: 'part_number', op: 'eq', value: '0019' }], aggregate: 'sum_quantity' }, 'POST', '/api/v1/query', { filters: [{ field: 'part_number', op: 'eq', value: '0019' }], aggregate: 'sum_quantity' }, { resource: 'items', aggregate: 'sum_quantity', value: 8 }],
  ['findez_create_item', { name: 'Motor', location: 'Shelf B', quantity: 4, workspace_id: teamId }, 'POST', '/api/v1/items', { name: 'Motor', location: 'Shelf B', quantity: 4, workspace_id: teamId }, { item: { item_id: itemId, name: 'Motor', quantity: 4 } }],
  ['findez_update_item', { item_id: itemId, changes: { quantity: 0, notes: null } }, 'PATCH', `/api/v1/items/${itemId}`, { quantity: 0, notes: null }, { updated: true, item_id: itemId }],
  ['findez_bulk_upsert', { items: [{ name: 'Motor', location: 'Shelf B', quantity: 9, category: 'Hardware', source_system: 'erp', external_id: 'motor-1' }] }, 'POST', '/api/v1/items/bulk', { items: [{ name: 'Motor', location: 'Shelf B', quantity: 9, category: 'Hardware', source_system: 'erp', external_id: 'motor-1' }] }, { processed: 1 }],
];
for (const [name, args, method, path, body, output] of cases) {
  test(`${name} sends the exact API contract with private Bearer authentication`, async (t) => {
    let calls = 0;
    const client = await connect(t, async (url, options) => {
      calls++;
      assert.equal(url, 'https://api.findez.ai' + path);
      assert.equal(options.method, method);
      assert.equal(options.headers.Authorization, 'Bearer ' + key);
      assert.equal(options.redirect, 'error');
      assert.ok(options.signal instanceof AbortSignal);
      assert.deepEqual(options.body ? JSON.parse(options.body) : undefined, body);
      return json(output);
    });
    const response = await client.callTool({ name, arguments: args });
    assert.ok(!response.isError);
    assert.deepEqual(parse(response), output);
    assert.equal(calls, 1);
  });
}

test('repeat imports preserve stable identity and never manufacture a new ID', async (t) => {
  const sent = [];
  const client = await connect(t, async (_, options) => { sent.push(JSON.parse(options.body)); return json({ processed: 1 }); });
  const args = cases.at(-1)[1];
  await client.callTool({ name: 'findez_bulk_upsert', arguments: args });
  await client.callTool({ name: 'findez_bulk_upsert', arguments: args });
  assert.deepEqual(sent, [args, args]);
});

test('delete, key management, arbitrary destinations and malformed writes never reach HTTP', async (t) => {
  let calls = 0;
  const client = await connect(t, async () => { calls++; return json({}); });
  for (const [name, args] of [
    ['findez_delete_item', { item_id: itemId }],
    ['findez_revoke_key', { key_id: itemId }],
    ['findez_create_key', {}],
    ['findez_list_items', { url: 'https://example.com', method: 'DELETE' }],
    ['findez_update_item', { item_id: '../keys/' + itemId, changes: { name: 'x' } }],
    ['findez_update_item', { item_id: itemId, changes: {} }],
    ['findez_update_item', { item_id: itemId, changes: { quantity: null } }],
    ['findez_update_item', { item_id: itemId, changes: { quantity: -1 } }],
    ['findez_update_item', { item_id: itemId, changes: { deleted: true } }],
    ['findez_update_item', { item_id: itemId, changes: { workspace_id: teamId } }],
    ['findez_create_item', { name: 'Motor', location: 'Shelf B', quantity: 1.5 }],
    ['findez_bulk_upsert', { items: [] }],
    ['findez_bulk_upsert', { items: [{ name: 'Motor', location: 'Shelf B' }] }],
    ['findez_query_inventory', { sql: 'DELETE FROM items' }],
    ['findez_query_inventory', { page_size: 101 }],
  ]) {
    const response = await client.callTool({ name, arguments: args });
    assert.equal(response.isError, true, name);
  }
  assert.equal(calls, 0);
});

for (const status of [400, 401, 403, 404, 409, 413, 422, 429, 500, 503]) {
  test(`HTTP ${status} returns a safe failure, never a successful write or leaked error`, async (t) => {
    let calls = 0;
    const client = await connect(t, async () => { calls++; return json({ secret: key, traceback: '/home/private/internal' }, status); });
    const response = await client.callTool({ name: 'findez_update_item', arguments: { item_id: itemId, changes: { quantity: 4 } } });
    assert.equal(response.isError, true);
    assert.equal(parse(response).error.status, status);
    assert.ok(!JSON.stringify(response).includes(key));
    assert.ok(!JSON.stringify(response).includes('/home/private'));
    assert.equal(calls, 1);
  });
}

test('uncertain writes and redirected requests are not retried', async (t) => {
  let calls = 0;
  const client = await connect(t, async () => { calls++; throw new Error('timeout with credential ' + key); });
  const response = await client.callTool({ name: 'findez_create_item', arguments: { name: 'Motor', location: 'Shelf B' } });
  assert.equal(response.isError, true);
  assert.match(parse(response).error.message, /may have succeeded/);
  assert.ok(!JSON.stringify(response).includes(key));
  assert.equal(calls, 1);
});

test('HTML, invalid JSON and oversized responses fail safely', async (t) => {
  for (const response of [new Response('<html>error</html>'), new Response('not json', { headers: { 'content-type': 'application/json' } }), json({ data: 'x'.repeat(2_000_001) })]) {
    const client = await connect(t, async () => response);
    assert.equal((await client.callTool({ name: 'findez_list_items' })).isError, true);
  }
});

test('accidental successful credential reflection is redacted', async (t) => {
  const client = await connect(t, async () => json({ notes: `accident ${key}` }));
  const response = await client.callTool({ name: 'findez_connection' });
  assert.ok(!JSON.stringify(response).includes(key));
  assert.match(parse(response).notes, /redacted/);
});

test('missing, malformed and non-production credentials fail without echoing a secret', () => {
  for (const apiKey of [undefined, '', 'something-private', 'findez_test_sk_' + 'x'.repeat(32)]) {
    assert.throws(() => createFindEZServer({ apiKey }), /Set a production FindEZ API key/);
  }
});

test('Actions import uses only key-auth inventory operations and makes writes consequential', async () => {
  const spec = JSON.parse(await readFile(new URL('../../../frontend/public/docs/api/chatgpt-actions.json', import.meta.url), 'utf8'));
  const operations = Object.entries(spec.paths).flatMap(([path, methods]) => Object.entries(methods).map(([method, op]) => ({ path, method, ...op })));
  assert.equal(operations.length, 8);
  assert.ok(operations.every((op) => op.method !== 'delete' && !op.path.includes('/keys')));
  assert.deepEqual(spec.servers, [{ url: 'https://api.findez.ai' }]);
  assert.deepEqual(Object.keys(spec.components.securitySchemes), ['IntegrationKey']);
  assert.ok(!Object.keys(spec.components.schemas).some((name) => /Key|UserSession/.test(name)));
  assert.ok(operations.every((op) => op.description.length <= 300 && op.summary.length <= 300));
  assert.equal(operations.filter((op) => op['x-openai-isConsequential']).length, 3);
  assert.equal(operations.find((op) => op.path === '/api/v1/query')['x-openai-isConsequential'], false);
  assert.equal(spec.paths['/api/v1/items'].get.parameters.find((p) => p.name === 'page_size').required, true);
  assert.equal(spec.components.schemas.InventoryQuery.properties.page_size.maximum, 10);
  assert.ok(spec.components.schemas.InventoryQuery.required.includes('page_size'));
  assert.equal(spec.components.schemas.APIBulkRequest.properties.items.maxItems, 10);
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    if (node.$ref) assert.ok(spec.components.schemas[node.$ref.split('/').at(-1)]);
    Object.values(node).forEach(walk);
  }
  walk(spec);
});
