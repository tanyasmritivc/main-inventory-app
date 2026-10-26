import { parseEmailLink, verifyEmailLink } from '@/lib/email-link';
const tokenHash = 'a'.repeat(64);
const fragment = (type = 'signup', redirect = 'https://findez.ai/auth/callback?next=/onboarding') => '#' + new URLSearchParams({ token_hash: tokenHash, type, redirect_to: redirect });
test.each(['signup', 'recovery', 'magiclink', 'invite', 'email_change', 'email'])('parses %s without local browser proof', (type) => {
 expect(parseEmailLink(fragment(type))).toEqual({ tokenHash, type, destination: type === 'recovery' ? '/reset-password' : '/onboarding' });
});
test.each(['', '#type=recovery', '#token_hash=short&type=recovery', fragment('sms'), fragment() + '&type=recovery', fragment() + '&token_hash=' + tokenHash])('rejects malformed proof: %s', (value) => expect(parseEmailLink(value)).toBeNull());
test.each(['https://attacker.example', '//attacker.example', '/\\attacker.example', 'javascript:alert(1)', 'io.supabase.flutter://login-callback', 'https://findez.ai.attacker.example/auth/callback', 'https://findez.ai/auth/callback?next=//attacker.example', '/auth/callback?next=/auth/confirm', '/reset-password'])('blocks unsafe destinations: %s', (redirect) => expect(parseEmailLink(fragment('signup', redirect))?.destination).toBe('/worlds'));
test('preserves local invitations and forces recovery to reset', () => {
 expect(parseEmailLink(fragment('signup', 'https://www.findez.ai/auth/callback?next=%2Fjoin%2Fteam%2Fqa-code'))?.destination).toBe('/join/team/qa-code');
 expect(parseEmailLink(fragment('recovery', 'https://attacker.example'))?.destination).toBe('/reset-password');
});
test('verifies the email proof on a fresh device', async () => {
 const auth = { verifyOtp: jest.fn().mockResolvedValue({ data: { session: { access_token: 'synthetic-token', user: { id: 'recipient' } } }, error: null }), getSession: jest.fn() };
 expect(await verifyEmailLink(auth, parseEmailLink(fragment('recovery'))!)).toEqual({ destination: '/reset-password' });
 expect(auth.verifyOtp).toHaveBeenCalledWith({ token_hash: tokenHash, type: 'recovery' });
 expect(auth.getSession).not.toHaveBeenCalled();
});
test('consumed proof cannot fall back to another signed-in account', async () => {
 const auth = { verifyOtp: jest.fn().mockResolvedValue({ data: { session: null }, error: { code: 'otp_expired' } }), getSession: jest.fn() };
 const result = await verifyEmailLink(auth, parseEmailLink(fragment())!);
 expect(result.error).toContain('expired or has already been used'); expect(result.destination).toBeUndefined(); expect(auth.getSession).not.toHaveBeenCalled();
});
test('signup and recovery require a fresh verified session', async () => {
 const auth = { verifyOtp: jest.fn().mockResolvedValue({ data: { session: null }, error: null }) };
 expect((await verifyEmailLink(auth, parseEmailLink(fragment('recovery'))!)).error).toContain('establish a session');
 expect((await verifyEmailLink(auth, parseEmailLink(fragment('signup'))!)).error).toContain('establish a session');
});
test('supports first confirmation of a two-address email change', async () => {
 const auth = { verifyOtp: jest.fn().mockResolvedValue({ data: { session: null }, error: null }) };
 expect(await verifyEmailLink(auth, parseEmailLink(fragment('email_change'))!)).toEqual({ awaitingConfirmation: true });
});
test('network failure does not expose provider details', async () => {
 const auth = { verifyOtp: jest.fn().mockRejectedValue(new Error('private provider detail')) };
 const result = await verifyEmailLink(auth, parseEmailLink(fragment())!);
 expect(result.error).toContain('connection'); expect(result.error).not.toContain('private provider');
});
