/** @jest-environment jsdom */
import {fireEvent,render,screen,waitFor} from '@testing-library/react';
import {InventoryChatArchive} from '@/components/site/inventory-chat-archive';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const confirm=jest.fn();
jest.mock('@/components/site/app-dialog-provider',()=>({useAppDialog:()=>({confirmAction:confirm})}));
beforeEach(()=>{jest.clearAllMocks();jest.mocked(accountRequest).mockImplementation(async(_a,p,o)=>{
 if(o?.method==='DELETE')return {deleted:true} as never;
 if(p.endsWith('/old'))return {messages:[{id:'answer',role:'assistant',content:'Earlier saved answer',created_at:'2026-01-01'}]} as never;
 return [{id:'old',title:'Earlier bolt question'}] as never;
});});
test('earlier private inventory conversations remain readable without offering a second scoped composer',async()=>{
 render(<InventoryChatArchive accountId="actor" inventoryId="inv" name="Hardware"/>);fireEvent.click(screen.getByText('Earlier chats'));
 fireEvent.click(await screen.findByText('Earlier bolt question'));expect(await screen.findByText('Earlier saved answer')).toBeTruthy();
 expect(accountRequest).toHaveBeenCalledWith('actor','/inventories/inv/conversations/old');expect(screen.queryByRole('textbox',{name:'Your question'})).toBeNull();
});
test('deleting an archived chat still requires confirmation and declining preserves it',async()=>{
 confirm.mockResolvedValue(false);render(<InventoryChatArchive accountId="actor" inventoryId="inv" name="Hardware"/>);fireEvent.click(screen.getByText('Earlier chats'));fireEvent.click(await screen.findByText('Earlier bolt question'));await screen.findByText('Earlier saved answer');
 fireEvent.click(screen.getByText('Delete conversation'));await waitFor(()=>expect(confirm).toHaveBeenCalled());expect(jest.mocked(accountRequest).mock.calls.some(c=>c[2]?.method==='DELETE')).toBe(false);
});
