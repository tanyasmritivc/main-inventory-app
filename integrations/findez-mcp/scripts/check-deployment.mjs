// Explicit, read-only release check. Never uses an issued key or writes inventory.
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { unzipSync } from 'fflate';

const reference = JSON.parse(await readFile(new URL('../../../frontend/public/docs/api/openapi.json', import.meta.url), 'utf8'));
const origin = reference.servers[0].url;
async function request(url, options = {}) {
  return fetch(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(30_000) });
}
for (const path of ['/health', '/health/db']) {
  const response = await request(origin + path);
  assert.equal(response.status, 200, path);
  assert.equal((await response.json()).status, 'ok', path);
}
// Health can pass against the retired deployment while API-key lookup fails.
const probe = 'findez_live_sk_' + randomBytes(24).toString('base64url');
const rejected = await request(origin + '/api/v1/whoami', { headers: { Authorization: `Bearer ${probe}` } });
assert.equal(rejected.status, 401, 'Unissued key must return 401, not authentication_unavailable');
assert.equal((await rejected.json()).detail.code, 'invalid_api_key');

for (const file of ['openapi.json', 'chatgpt-actions.json']) {
  const response = await request('https://findez.ai/docs/api/' + file);
  assert.equal(response.status, 200, file);
  assert.equal((await response.json()).servers[0].url, origin, `${file} production destination`);
}
const bundle = await request('https://findez.ai/docs/api/findez-inventory.mcpb');
assert.equal(bundle.status, 200, 'Desktop download');
const deployed = Buffer.from(await bundle.arrayBuffer());
const local = await readFile(new URL('../../../frontend/public/docs/api/findez-inventory.mcpb', import.meta.url));
assert.equal(Buffer.compare(deployed, local), 0, 'Published Desktop download must match the tested package');
const files = unzipSync(deployed);
assert.ok(Buffer.from(files['server/index.mjs']).toString().includes(origin));
console.log('PASS: production health, API-key lookup, published API/Actions destinations, and exact Desktop package.');
console.log('This check does not replace authenticated inventory and host-application acceptance tests.');
