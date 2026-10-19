/** @jest-environment jsdom */
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { CheckoutClient } from '@/components/site/checkout-client';
import { getActiveCheckouts } from '@/lib/api';
jest.mock('@/lib/api', () => ({getActiveCheckouts:jest.fn(),returnItem:jest.fn()}));
jest.mock('@/lib/supabase/browser', () => ({createSupabaseBrowserClient:()=>({auth:{getSession:async()=>({data:{session:{access_token:'test'}}})}})}));
jest.mock('@/components/site/app-dialog-provider', () => ({useAppDialog:()=>({confirmAction:jest.fn(),showNotice:jest.fn()})}));
jest.mock('@/components/site/inventory-link', () => ({__esModule:true,default:({children,...props}:{children:React.ReactNode})=><a {...props}>{children}</a>}));
test('failed checkout loading is actionable and does not claim nothing is checked out', async()=>{
 jest.mocked(getActiveCheckouts).mockRejectedValueOnce(new Error('Unavailable')).mockResolvedValueOnce({checkouts:[]});
 render(<CheckoutClient/>);
 await screen.findByRole('alert');
 expect(screen.queryByText('Nothing checked out')).toBeNull();
 await userEvent.click(screen.getByRole('button',{name:'Try again'}));
 await screen.findByText('Nothing checked out');
 expect(screen.queryByRole('alert')).toBeNull();
});
test('future due dates do not appear as negative time ago',async()=>{
 jest.mocked(getActiveCheckouts).mockResolvedValueOnce({checkouts:[{checkout_id:'co',items:{name:'Loaned drill'},due_back_at:'2099-12-31T12:00:00Z'}]});
 render(<CheckoutClient/>);
 await screen.findByText('Loaned drill');
 expect(screen.getByText(/^Due /).textContent).not.toContain('ago');
});
