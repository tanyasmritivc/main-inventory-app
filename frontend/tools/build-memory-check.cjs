// Compile-only check with synthetic auth settings and bundled font fixtures.
// The generated .next directory is NOT a website release artifact.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const frontend = path.resolve(__dirname, '..');
const fonts = path.resolve(frontend, '..', 'mobile', 'assets', 'fonts');
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'findez-memory-fonts-'));
const fixture = path.join(scratch, 'fonts.cjs');
try {
  fs.writeFileSync(fixture, `module.exports = new Proxy({}, {get(_target,url) {
    if (typeof url !== 'string') return undefined;
    const family = new URL(url).searchParams.get('family').split(':')[0];
    const file = family.includes('Mono') ? 'GeistMono-Medium.ttf' : 'Geist-Regular.ttf';
    return "/* latin */\\n@font-face {font-family:'" + family + "';font-style:normal;font-weight:100 900;font-display:swap;src:url(" + ${JSON.stringify(fonts)} + "/" + file + ") format('truetype');}";
  }});`);
  process.stdout.write('COMPILE CHECK ONLY: synthetic auth configuration and substituted fonts. Do not publish this .next output.\n');
  const result = spawnSync(process.execPath, [require.resolve('next/dist/bin/next'), 'build', '--webpack'], {
    cwd: frontend,
    env: { ...process.env, NEXT_FONT_GOOGLE_MOCKED_RESPONSES: fixture,
      NEXT_PUBLIC_SUPABASE_URL: 'https://supabase.example.test',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: 'synthetic-build-only' },
    stdio: 'inherit',
  });
  process.exitCode = result.status ?? 1;
} finally { fs.rmSync(scratch, {recursive:true,force:true}); }
