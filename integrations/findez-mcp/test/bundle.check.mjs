import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { unzipSync } from 'fflate';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

test('downloadable extension runs standalone and supports writes without a delete tool', async (t) => {
  const zip = unzipSync(await readFile(new URL('../../../frontend/public/docs/api/findez-inventory.mcpb', import.meta.url)));
  const manifest = JSON.parse(Buffer.from(zip['manifest.json']).toString());
  assert.equal(manifest.user_config.api_key.sensitive, true);
  assert.equal(manifest.user_config.api_key.required, true);
  assert.deepEqual(Object.keys(zip).sort(), ['README.md', 'THIRD_PARTY_NOTICES.txt', 'manifest.json', 'package.json', 'server/index.mjs'].sort());
  assert.deepEqual(manifest, JSON.parse(await readFile(new URL('../manifest.json', import.meta.url), 'utf8')));
  assert.equal(Buffer.compare(Buffer.from(zip['server/index.mjs']), await readFile(new URL('../dist/server/index.mjs', import.meta.url))), 0);
  const dir = await mkdtemp(join(tmpdir(), 'findez-bundle-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  for (const [path, bytes] of Object.entries(zip)) {
    assert.ok(!path.startsWith('/') && !path.split('/').includes('..'));
    await mkdir(dirname(join(dir, path)), { recursive: true });
    await writeFile(join(dir, path), bytes);
  }
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ['--import', fileURLToPath(new URL('./fixtures/fetch-stub.mjs', import.meta.url)), join(dir, manifest.server.entry_point)],
    cwd: dir, env: { FINDEZ_API_KEY: 'findez_live_sk_' + 'x'.repeat(32) }, stderr: 'pipe',
  });
  let stderr = '';
  transport.stderr?.on('data', (chunk) => { stderr += chunk.toString(); });
  const client = new Client({ name: 'bundle-test', version: '1.0.0' });
  t.after(() => client.close());
  await client.connect(transport);
  const { tools } = await client.listTools();
  assert.equal(tools.length, 8);
  assert.ok(!tools.some((tool) => /delete|revoke/.test(tool.name)));
  const item = { name: 'Washer', quantity: 4, location: 'Shelf B' };
  const result = await client.callTool({ name: 'findez_create_item', arguments: item });
  assert.ok(!result.isError, JSON.stringify(result));
  assert.deepEqual(JSON.parse(result.content[0].text), { url: 'https://api.findez.ai/api/v1/items', method: 'POST', body: item, authenticated: true });
  assert.equal((await client.callTool({ name: 'findez_delete_item', arguments: {} })).isError, true);
  assert.ok(!stderr.includes('findez_live_sk_'));
});
