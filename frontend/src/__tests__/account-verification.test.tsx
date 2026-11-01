/** @jest-environment jsdom */
import {render,screen,waitFor,act} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {AccountVerification} from '@/components/site/account-verification';
let actor='verify-1';
const auth={getUser:jest.fn(),resend:jest.fn(),onAuthStateChange:jest.fn(()=>({data:{subscription:{unsubscribe:jest.fn()}}}))};
jest.mock('@/lib/supabase/browser',()=>({createSupabaseBrowserClient:()=>({auth})}));
jest.mock('@/lib/use-api-session',()=>({useApiSession:()=>({accountId:actor})}));
jest.mock('@/lib/account-request',()=>({accountToken:jest.fn(async()=> 'token')}));
const unverified=()=>({data:{user:{id:actor,email:'verify@company.example',email_confirmed_at:null}},error:null});
beforeEach(()=>{actor+='x';sessionStorage.clear();jest.clearAllMocks();auth.getUser.mockImplementation(async()=>unverified());auth.resend.mockResolvedValue({error:null});});
test('uses authenticated email and only reports verified after server confirmation',async()=>{
 render(<AccountVerification/>);
 await screen.findByText('verify@company.example',{selector:'strong'});
 await userEvent.click(screen.getByRole('button',{name:'Send verification email'}));
 await screen.findByText(/Verification email requested/);
 expect(auth.resend).toHaveBeenCalledWith({type:'signup',email:'verify@company.example',options:{emailRedirectTo:'http://localhost/auth/callback?next=%2Fsettings%2Faccount'}});
 expect(screen.queryByText(/Verified email:/)).toBeNull();
 expect(screen.getByRole('button',{name:/Resend in/})).toHaveProperty('disabled',true);
 auth.getUser.mockResolvedValue({data:{user:{...unverified().data.user,email_confirmed_at:'2026-10-20'}},error:null});
 await userEvent.click(screen.getByRole('button',{name:'Check verification'}));
 await screen.findByText(/Verified email:/);
 expect(screen.queryByRole('button',{name:/Send verification/})).toBeNull();
});
test('verified users including Google users never see an unverified modal',async()=>{
 auth.getUser.mockResolvedValue({data:{user:{...unverified().data.user,email_confirmed_at:'2026-10-20',app_metadata:{provider:'google'}}},error:null});
 render(<AccountVerification prompt/>);
 await waitFor(()=>expect(auth.getUser).toHaveBeenCalled());
 expect(screen.queryByRole('dialog')).toBeNull();expect(auth.resend).not.toHaveBeenCalled();
});
test('unverified modal can be dismissed and does not reopen on navigation',async()=>{
 const v=render(<AccountVerification prompt/>);
 await screen.findByRole('dialog',{name:'Verify your email'});
 await userEvent.click(screen.getByRole('button',{name:'Later'}));
 v.unmount();render(<AccountVerification prompt/>);
 await waitFor(()=>expect(auth.getUser).toHaveBeenCalledTimes(2));
 expect(screen.queryByRole('dialog')).toBeNull();
});
test('network failures are unknown rather than incorrectly unverified',async()=>{
 auth.getUser.mockRejectedValue(new Error('Offline'));
 render(<AccountVerification/>);
 await screen.findByRole('alert');expect(screen.queryByRole('button',{name:'Send verification email'})).toBeNull();
});
test('resend errors are visible and never claim email delivery',async()=>{
 auth.resend.mockResolvedValue({error:new Error('Rate limited')});render(<AccountVerification/>);
 await userEvent.click(await screen.findByRole('button',{name:'Send verification email'}));
 await screen.findByRole('alert');expect(screen.queryByText(/Verification email requested/)).toBeNull();
});
test('switching accounts discards a late verification response',async()=>{
 let resolve!:(v:unknown)=>void;const old=unverified();auth.getUser.mockImplementationOnce(()=>new Promise(r=>{resolve=r;}));
 const v=render(<AccountVerification prompt/>);actor+='other';v.rerender(<AccountVerification prompt/>);
 await screen.findByRole('dialog');await userEvent.click(screen.getByRole('button',{name:'Later'}));
 await act(async()=>resolve(old));expect(screen.queryByRole('dialog')).toBeNull();
});
test('server response for another identity cannot be used to resend',async()=>{
 auth.getUser.mockResolvedValue({data:{user:{id:'other',email:'other@example.test'}},error:null});
 render(<AccountVerification/>);await screen.findByRole('alert');expect(auth.resend).not.toHaveBeenCalled();
});
