/** @jest-environment jsdom */
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { EmailConfirmClient } from '@/components/site/email-confirm-client';
const verifyOtp = jest.fn();
jest.mock('@/lib/supabase/browser', () => ({ createSupabaseBrowserClient: () => ({ auth: { verifyOtp } }) }));
const hash = 'b'.repeat(64);
beforeEach(() => {
 jest.clearAllMocks(); window.history.replaceState({}, '', '/auth/confirm#token_hash=' + hash + '&type=recovery');
 verifyOtp.mockResolvedValue({ data: { session: null }, error: { code: 'otp_expired' } });
});
test('opening a link does not consume it and removes proof from history', async () => {
 render(<EmailConfirmClient />);
 expect(await screen.findByRole('button', { name: 'Continue to reset password' })).toBeTruthy();
 expect(verifyOtp).not.toHaveBeenCalled(); expect(window.location.hash).toBe(''); expect(window.location.search).toBe('');
});
test('verifies only after explicit action and explains expired links', async () => {
 const user = userEvent.setup(); render(<EmailConfirmClient />);
 await user.click(await screen.findByRole('button', { name: 'Continue to reset password' }));
 expect(verifyOtp).toHaveBeenCalledTimes(1); expect(verifyOtp).toHaveBeenCalledWith({ token_hash: hash, type: 'recovery' });
 expect((await screen.findByRole('alert')).textContent).toContain('expired or has already been used');
});
test('missing proof never submits verification', async () => {
 window.history.replaceState({}, '', '/auth/confirm'); render(<EmailConfirmClient />);
 expect((await screen.findByRole('alert')).textContent).toContain('incomplete'); expect(screen.queryByRole('button')).toBeNull(); expect(verifyOtp).not.toHaveBeenCalled();
});
test('explains remaining email-change confirmation without claiming sign-in', async () => {
 const user = userEvent.setup(); window.history.replaceState({}, '', '/auth/confirm#token_hash=' + hash + '&type=email_change');
 verifyOtp.mockResolvedValue({ data: { session: null }, error: null }); render(<EmailConfirmClient />);
 await user.click(await screen.findByRole('button', { name: 'Confirm and continue' }));
 await waitFor(() => expect(screen.getByRole('heading').textContent).toContain('Email confirmation received'));
 expect(screen.getByRole('link', { name: 'Go to sign in' })).toBeTruthy(); expect(screen.queryByRole('button')).toBeNull();
});
