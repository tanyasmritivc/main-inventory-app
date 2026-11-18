/** @jest-environment jsdom */
import { act, renderHook, waitFor } from '@testing-library/react';
import type { AuthChangeEvent, Session } from '@supabase/supabase-js';
import { useApiSession } from '@/lib/use-api-session';
import { createSupabaseBrowserClient } from '@/lib/supabase/browser';

jest.mock('@/lib/supabase/browser', () => ({ createSupabaseBrowserClient: jest.fn() }));
const getSession = jest.fn();
const unsubscribe = jest.fn();
let authEvent: (event: AuthChangeEvent, session: Session | null) => void;
const session = (id: string, token: string) => ({ user: { id }, access_token: token } as Session);
beforeEach(() => {
 jest.clearAllMocks();
 jest.mocked(createSupabaseBrowserClient).mockReturnValue({auth:{getSession,onAuthStateChange: jest.fn(callback => {
  authEvent = callback; return {data:{subscription:{unsubscribe}}};
 })}} as unknown as ReturnType<typeof createSupabaseBrowserClient>);
});

test('a refreshed session recovers a failed initial session check without reloading', async () => {
 getSession.mockResolvedValue({data:{session:null},error:new Error('Temporary session failure')});
 const {result}=renderHook(()=>useApiSession());
 await waitFor(()=>expect(result.current.loading).toBe(false));
 expect(result.current.error).toBeTruthy();
 act(()=>authEvent('TOKEN_REFRESHED',session('actor','new-token')));
 expect(result.current.accountId).toBe('actor');
 expect(result.current.token).toBe('new-token');
 expect(result.current.error).toBeNull();
});

test('normal same-account refresh does not restart token-keyed page effects',async()=>{
 getSession.mockResolvedValue({data:{session:session('actor','original-token')},error:null});
 const {result}=renderHook(()=>useApiSession());
 await waitFor(()=>expect(result.current.accountId).toBe('actor'));
 act(()=>authEvent('TOKEN_REFRESHED',session('actor','renewed-token')));
 expect(result.current.token).toBe('original-token');
 expect(result.current.error).toBeNull();
});

test('a refreshed different account invalidates the previous account view',async()=>{
 getSession.mockResolvedValue({data:{session:session('first','first-token')},error:null});
 const {result}=renderHook(()=>useApiSession());
 await waitFor(()=>expect(result.current.accountId).toBe('first'));
 act(()=>authEvent('TOKEN_REFRESHED',session('second','second-token')));
 expect(result.current.accountId).toBe('second');
 expect(result.current.token).toBe('second-token');
});

test('a delayed initial response cannot overwrite a recovered session', async () => {
 let resolveSession!: (value: unknown) => void;
 getSession.mockReturnValue(new Promise(resolve => { resolveSession = resolve; }));
 const {result} = renderHook(() => useApiSession());
 act(() => authEvent('TOKEN_REFRESHED', session('current', 'current-token')));
 await act(async () => {
  resolveSession({data:{session:session('stale','stale-token')},error:null});
 });
 expect(result.current.accountId).toBe('current');
 expect(result.current.token).toBe('current-token');
 expect(result.current.loading).toBe(false);
 expect(result.current.error).toBeNull();
});
