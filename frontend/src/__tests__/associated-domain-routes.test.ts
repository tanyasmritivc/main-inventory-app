import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const association = JSON.parse(readFileSync(join(process.cwd(), 'public/.well-known/apple-app-site-association'), 'utf8'));
const app = association.applinks.details.find((entry: {appIDs: string[]}) => entry.appIDs.includes('Y68YH9U95S.com.findez.app'));
const matches = (path: string) => app.components.some((rule: Record<string, string>) => {
  const pattern = '^' + rule['/'].split('*').map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('.*') + '$';
  return !rule.exclude && new RegExp(pattern).test(path);
});

test.each(['/join/team/ABC123', '/join/ABC123', '/join/access', '/join', '/workspaces/qa-workspace'])('iOS claims supported app route %s', path => {
  expect(matches(path)).toBe(true);
});
test.each(['/privacy', '/terms', '/login', '/api/keys', '/'])('ordinary website route %s stays on the web', path => {
  expect(matches(path)).toBe(false);
});
