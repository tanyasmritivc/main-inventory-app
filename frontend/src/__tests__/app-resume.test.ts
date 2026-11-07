/** @jest-environment jsdom */
import { readResume, resumePath, rememberPage, rememberedPage, RESUME_COOKIE, conversationResumeKey } from '@/lib/app-resume';

afterEach(() => { document.cookie = `${RESUME_COOKIE}=; Max-Age=0; Path=/`; });
test('retains the exact Space and view but never replays a prompt or action', () => {
  expect(resumePath('/inventory?inventory=inv&space=Shelf%20B&q=delete&confirm=true')).toBe('/inventory?inventory=inv&space=Shelf+B');
  expect(resumePath('/worlds/personal?view=tools')).toBe('/worlds/personal?view=tools');
});
test.each(['https://evil.example','//evil.example','/\\evil.example','/worlds/../../signin','/%73ignin','/auth/callback?code=secret','/onboarding','/worlds','/reset-password','/worlds/%0aevil'])('rejects unsafe or non-resumable destinations: %s', path => {
  expect(resumePath(path)).toBeNull();
});
test('persists page navigation for the same account only', () => {
  rememberPage('account-a','/worlds/personal?view=spaces');
  expect(rememberedPage('account-a')).toBe('/worlds/personal?view=spaces');
  expect(rememberedPage('account-b')).toBeNull();
  expect(readResume('broken','account-a')).toBeNull();
});
test('conversation storage is isolated by account and inventory or organization', () => {
  expect(conversationResumeKey('a',':world:personal')).not.toBe(conversationResumeKey('b',':world:personal'));
  expect(conversationResumeKey('a',':world:personal')).not.toBe(conversationResumeKey('a',':inventory:one'));
});
