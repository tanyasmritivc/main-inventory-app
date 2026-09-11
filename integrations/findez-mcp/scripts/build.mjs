import { build } from 'esbuild';
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { unzipSync } from 'fflate';
import assert from 'node:assert/strict';

const base = fileURLToPath(new URL('../', import.meta.url));
const dist = resolve(base, 'dist');
await mkdir(resolve(dist, 'server'), { recursive: true });
const built = await build({
  absWorkingDir: base, entryPoints: ['src/stdio.mjs'], outfile: 'dist/server/index.mjs',
  platform: 'node', target: 'node20', format: 'esm', bundle: true, metafile: true,
  banner: { js: "import { createRequire } from 'node:module'; const require = createRequire(import.meta.url);" },
});
await copyFile(resolve(base, 'manifest.json'), resolve(dist, 'manifest.json'));
await copyFile(resolve(base, 'README.md'), resolve(dist, 'README.md'));
await writeFile(resolve(dist, 'package.json'), JSON.stringify({ name: 'findez-inventory', version: '1.0.0', private: true, type: 'module' }, null, 2) + '\n');
const packages = new Set();
for (const input of Object.keys(built.metafile.inputs)) {
  if (!input.includes('node_modules/')) continue;
  const [prefix, remainder] = input.split(/node_modules\/(?!.*node_modules\/)/);
  const segments = remainder.split('/');
  const packageName = segments.slice(0, segments[0].startsWith('@') ? 2 : 1).join('/');
  packages.add(resolve(base, prefix, 'node_modules', packageName));
}
const notices = [];
for (const path of [...packages].sort()) {
  const pkg = JSON.parse(await readFile(resolve(path, 'package.json'), 'utf8'));
  let license = '';
  for (const name of ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'license', 'license.md']) {
    try { license = await readFile(resolve(path, name), 'utf8'); break; } catch { /* Try conventional names. */ }
  }
  notices.push(`${pkg.name} ${pkg.version} (${pkg.license ?? 'see package'})\n${license}`);
}
await writeFile(resolve(dist, 'THIRD_PARTY_NOTICES.txt'), notices.join('\n\n---\n\n'));
const output = resolve(base, '../../frontend/public/docs/api/findez-inventory.mcpb');
await mkdir(dirname(output), { recursive: true });
const cli = resolve(base, 'node_modules/@anthropic-ai/mcpb/dist/cli/cli.js');
execFileSync(process.execPath, [cli, 'validate', resolve(dist, 'manifest.json')], { stdio: 'inherit' });
if (process.argv.includes('--check')) {
  const contents = unzipSync(await readFile(output));
  const files = ['README.md', 'THIRD_PARTY_NOTICES.txt', 'manifest.json', 'package.json', 'server/index.mjs'];
  assert.deepEqual(Object.keys(contents).sort(), files.sort(), 'Unexpected files in Desktop download');
  for (const path of files) {
    assert.equal(Buffer.compare(Buffer.from(contents[path]), await readFile(resolve(dist, path))), 0, `Rebuild Desktop download: ${path}`);
  }
  console.log('Committed Desktop download matches current source and dependencies.');
} else {
  execFileSync(process.execPath, [cli, 'pack', dist, output], { stdio: 'inherit' });
  console.log('Built FindEZ Desktop extension with bundled dependencies.');
}
