/** @jest-environment jsdom */
import { StrictMode } from 'react';
import { render, screen } from '@testing-library/react';
import { AuthCallbackClient } from '@/components/site/auth-callback-client';
const mockExchange = jest.fn();
const mockClient = jest.fn();
jest.mock('@/lib/supabase/browser', () => ({ createSupabaseBrowserClient: () => mockClient() }));
beforeEach(() => {
 jest.clearAllMocks();
 window.history.replaceState({}, '', '/auth/callback?code=synthetic-code');
 mockClient.mockImplementation(() => {
  expect(window.location.search).toBe('');
  expect(window.location.hash).toBe('');
  return { auth: { exchangeCodeForSession: mockExchange } };
 });
 mockExchange.mockResolvedValue({ data: { session: null }, error: { code: 'flow_state_not_found' } });
});
test('strips URL before client initialization and exchanges once in Strict Mode', async () => {
 render(<StrictMode><AuthCallbackClient code="synthetic-code" next="/home" /></StrictMode>);
 expect(await screen.findByRole('heading', { name: 'Sign-in link could not be completed' })).toBeTruthy();
 expect(mockClient).toHaveBeenCalledTimes(1);
 expect(mockExchange).toHaveBeenCalledTimes(1);
 expect(mockExchange).toHaveBeenCalledWith('synthetic-code');
});
test('handles provider errors without exchanging an unrelated code', async () => {
 window.history.replaceState({}, '', '/auth/callback#error_code=otp_expired');
 render(<AuthCallbackClient code={null} next="/home" />);
 expect(await screen.findByText(/expired or has already been used/)).toBeTruthy();
 expect(mockExchange).not.toHaveBeenCalled();
});
