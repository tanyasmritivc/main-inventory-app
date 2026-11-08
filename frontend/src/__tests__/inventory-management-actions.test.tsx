/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {act,render,screen,waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {accountRequest} from '@/lib/account-request';
import {preview,receipt,mutations} from './removal-fixture';
import {DeleteInventoryDialog, InventoryManagementActions} from '@/components/site/inventory-management-actions';
const inventory={inventory_id:'hardware',workspace_id:'project',name:'Hardware',can_manage:true,can_rename:true};
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const close=jest.fn(),deleted=jest.fn();
let remove: jest.Mock;
beforeEach(()=>{
 jest.clearAllMocks(); remove=jest.fn().mockResolvedValue(receipt('inventory','hardware'));
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=> options?.method ? remove() : preview('inventory','hardware','Hardware') as never);
});
async function selectDelete(){
 const choice=await screen.findByRole('radio',{name:'Delete inventory and all its contents'});
 await userEvent.click(choice);
}
test('exact name and explicit destructive choice are required before a confirmed deletion',async()=>{
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={deleted}/>);
 const input=await screen.findByRole('textbox');
 const submit=screen.getByRole('button',{name:'Delete inventory'});
 await userEvent.type(input,'Hardware');expect(submit).toHaveProperty('disabled',true);
 await selectDelete();expect(screen.getByRole('note')).toBeTruthy();
 await userEvent.clear(input);await userEvent.type(input,'wrong name');expect(submit).toHaveProperty('disabled',true);
 await userEvent.clear(input);await userEvent.type(input,'Hardware');await userEvent.click(submit);
 await waitFor(()=>expect(deleted).toHaveBeenCalledTimes(1));
 expect(mutations()).toEqual([['owner','/resource-removal/inventory/hardware',{method:'POST',body:{name:'Hardware',action:'delete'}}]]);
});
test('false receipts and rejected writes preserve the confirmation without reporting success',async()=>{
 remove.mockResolvedValueOnce({...receipt('inventory','hardware'),deleted:false}).mockRejectedValueOnce(new Error('offline'));
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={deleted}/>);await selectDelete();await userEvent.type(screen.getByRole('textbox'),'Hardware');
 await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));await screen.findByRole('alert');expect(deleted).not.toHaveBeenCalled();
 await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));await waitFor(()=>expect(remove).toHaveBeenCalledTimes(2));
 expect(deleted).not.toHaveBeenCalled();expect(screen.getByRole('textbox')).toHaveProperty('value','Hardware');
});
test('Cancel reads impact but makes no mutation',async()=>{
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={deleted}/>);await screen.findByRole('textbox');
 await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(close).toHaveBeenCalledTimes(1);expect(mutations()).toEqual([]);
});
test('pending submissions cannot duplicate or complete after unmount',async()=>{
 let finish!:(value:unknown)=>void;remove.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));
 const view=render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={deleted}/>);await selectDelete();await userEvent.type(screen.getByRole('textbox'),'Hardware');
 await userEvent.dblClick(screen.getByRole('button',{name:'Delete inventory'}));expect(remove).toHaveBeenCalledTimes(1);
 await userEvent.keyboard('{Escape}');expect(close).not.toHaveBeenCalled();view.unmount();
 await act(async()=>finish(receipt('inventory','hardware')));expect(deleted).not.toHaveBeenCalled();
});
test('rename-only access never reveals deletion',async()=>{
 render(<InventoryManagementActions inventory={{...inventory,can_manage:false}} onRename={jest.fn()} onDelete={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage Hardware'}));
 expect(await screen.findByRole('menuitem',{name:'Rename'})).toBeTruthy();
 expect(screen.queryByRole('menuitem',{name:'Delete inventory'})).toBeNull();
});
