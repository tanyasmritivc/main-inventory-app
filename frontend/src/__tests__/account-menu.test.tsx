/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';mockBrowserTopLayer();
import {render,screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {AccountMenu} from '@/components/site/account-menu';
const router={push:jest.fn(),replace:jest.fn(),refresh:jest.fn()},setTheme=jest.fn(),signOut=jest.fn();
jest.mock('@/components/site/inventory-link',()=>({useInventoryRouter:()=>router}));
jest.mock('@/components/site/use-app-theme',()=>({useAppTheme:()=>({theme:'system',setTheme})}));
jest.mock('@/lib/supabase/browser',()=>({createSupabaseBrowserClient:()=>({auth:{signOut}})}));
beforeEach(()=>{jest.clearAllMocks();signOut.mockResolvedValue({error:null});});
test('account menu groups existing destinations and theme choices without inventing settings',async()=>{
 render(<AccountMenu name="Local tester" email="tester@example.test" initial="L"/>);
 await userEvent.click(screen.getByRole('button',{name:'Open profile'}));
 expect(screen.getByText('tester@example.test')).toBeTruthy();
 await userEvent.click(screen.getByRole('menuitemradio',{name:'Dark'}));expect(setTheme).toHaveBeenCalledWith('dark');
 await userEvent.click(screen.getByRole('button',{name:'Open profile'}));
 await userEvent.click(screen.getByRole('menuitem',{name:'Account settings'}));expect(router.push).toHaveBeenCalledWith('/settings');
});
test('failed sign out remains visible and never redirects',async()=>{
 signOut.mockResolvedValue({error:new Error('offline')});
 render(<AccountMenu name="Local tester" email="tester@example.test" initial="L"/>);
 await userEvent.click(screen.getByRole('button',{name:'Open profile'}));await userEvent.click(screen.getByRole('menuitem',{name:'Sign out'}));
 await screen.findByRole('alert');expect(router.replace).not.toHaveBeenCalled();
});
