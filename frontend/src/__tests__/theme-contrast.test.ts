import fs from 'node:fs';
import path from 'node:path';
import postcss from 'postcss';

// Portaled controls inherit tokens from html, outside .app-frame. Measure
// their text against actual CSS surfaces so a light-only alias cannot regress.
function tokens(dark: boolean) {
  const values: Record<string, string> = {};
  for (const file of ['globals.css', 'app-theme.css']) {
    const css = postcss.parse(fs.readFileSync(path.join(process.cwd(), 'src/app', file), 'utf8'));
    css.walkRules(rule => {
      if (rule.parent?.type !== 'root' || !(rule.selector === ':root' || (dark && rule.selector === '.dark'))) return;
      rule.walkDecls(decl => { if (decl.prop.startsWith('--')) values[decl.prop] = decl.value; });
    });
  }
  const resolve = (name: string): string => {
    const value = values[name];
    const alias = value?.match(/^var\((--[\w-]+)\)$/);
    return alias ? resolve(alias[1]) : value;
  };
  return resolve;
}
function luminance(hex: string) {
  expect(hex).toMatch(/^#[0-9a-f]{6}$/i);
  const channels = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map(v => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
  return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}
test.each([false, true])('portal text meets normal-text contrast in dark=%s', dark => {
  const resolve = tokens(dark);
  for (const surface of ['--light-panel', '--light-page', '--surface-raised']) {
    for (const text of ['--text-primary', '--text-secondary', '--text-muted', '--light-soft']) {
      const a = luminance(resolve(text));
      const b = luminance(resolve(surface));
      expect((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)).toBeGreaterThanOrEqual(4.5);
    }
  }
});
