import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { endpoints, requestExamples } from '@/lib/api-reference';

test('JavaScript examples send exactly the documented HTTP requests without real network calls', async () => {
  const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
  for (const endpoint of endpoints) {
    const capture = jest.fn().mockResolvedValue({ ok: true, text: async () => '{}' });
    const execute = new AsyncFunction('process', 'fetch', 'AbortSignal', 'console', requestExamples(endpoint).JavaScript);
    await execute({ env: { FINDEZ_API_KEY: 'test-only', FINDEZ_USER_ACCESS_TOKEN: 'owner-test-only' } }, capture, { timeout: () => 'timeout-signal' }, { log: jest.fn() });
    const [url, options] = capture.mock.calls[0];
    expect(url).not.toContain('{');
    expect(options.method).toBe(endpoint.method);
    expect(options.headers.Authorization).toBe(endpoint.security[0].UserSession ? 'Bearer owner-test-only' : 'Bearer test-only');
    expect(options.body === undefined ? undefined : JSON.parse(options.body)).toEqual(endpoint.requestBody?.content['application/json'].example);
  }
});

test('every Python, JavaScript, and shell request example parses without executing requests', () => {
  const directory = mkdtempSync(join(tmpdir(), 'findez-docs-examples-'));
  try {
    for (const endpoint of endpoints) {
      const bodies = [endpoint.requestBody?.content['application/json'].example, ...Object.values(endpoint['x-extra-examples']).map((entry) => entry.request)];
      for (const body of bodies) {
        const examples = requestExamples(endpoint, body);
        const file = join(directory, 'example.mjs');
        writeFileSync(file, examples.JavaScript);
        execFileSync(process.execPath, ['--check', file]);
        execFileSync('bash', ['-n'], { input: examples.cURL });
        // ast.parse accepts source via stdin; it does not run the example.
        const result = spawnSync('python3', ['-c', 'import ast, sys; ast.parse(sys.stdin.read())'], { input: examples.Python, encoding: 'utf-8' });
        if (result.error) throw result.error;
        expect(result.stderr).toBe('');
        expect(result.status).toBe(0);
      }
    }
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
