/** @jest-environment jsdom */
import { mockBrowserTopLayer } from "./mock-browser-top-layer";
mockBrowserTopLayer();
import {render,screen,waitFor} from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {DeleteInventoryDialog, InventoryManagementActions} from "@/components/site/inventory-management-actions";
import {accountRequest} from "@/lib/account-request";
import {ApiError} from "@/lib/api";
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
const inventory={inventory_id:"hardware",workspace_id:"project",name:"Hardware",can_manage:true,can_rename:true};
const preview={kind:'inventory',id:'hardware',name:'Hardware',workspaces:0,inventories:0,spaces:2,items:3,can_move:true,destinations:[{id:'personal',name:'Personal'}]};
beforeEach(()=>{jest.clearAllMocks();jest.mocked(accountRequest).mockReset();jest.mocked(accountRequest).mockResolvedValue(preview);});
test('deletion requires exact name and a confirmed receipt before refreshing',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockResolvedValue({deleted:true,kind:'inventory',id:'hardware',action:'delete'});
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 const remove=await screen.findByRole('button',{name:'Delete inventory'});
 expect((remove as HTMLButtonElement).disabled).toBe(true);
 await screen.findByRole('textbox');await userEvent.click(screen.getByRole('radio',{name:'Delete inventory and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(remove);
 await waitFor(()=>expect(deleted).toHaveBeenCalledTimes(1));
 expect(accountRequest).toHaveBeenCalledWith('owner','/resource-removal/inventory/hardware',{method:'POST',body:{name:'Hardware',action:'delete'}});
});
test('saved-content rejection stays actionable and never reports success',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockRejectedValue(new ApiError('This inventory contains saved records.',409,{}));
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 await screen.findByRole('textbox');await userEvent.click(screen.getByRole('radio',{name:'Delete inventory and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 await screen.findByRole('alert');expect(deleted).not.toHaveBeenCalled();expect(screen.getByRole('textbox')).toHaveProperty('value','Hardware');
});
test('cancel does not mutate and rename-only access never reveals deletion',async()=>{
 const close=jest.fn();
 const view=render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={jest.fn()}/>);
 await screen.findByRole('textbox');await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(jest.mocked(accountRequest).mock.calls.some(call=>call[2]?.method)).toBe(false);expect(close).toHaveBeenCalled();
 view.unmount();render(<InventoryManagementActions inventory={{...inventory,can_manage:false}} onRename={jest.fn()} onDelete={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage Hardware'}));
 expect(await screen.findByRole('menuitem',{name:'Rename'})).toBeTruthy();expect(screen.queryByRole('menuitem',{name:'Delete inventory'})).toBeNull();
});

test('including contents is a separate explicit choice sent only after exact confirmation',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockResolvedValue({deleted:true,kind:'inventory',id:'hardware',action:'delete'});
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 await userEvent.click(await screen.findByRole('radio',{name:'Delete inventory and all its contents'}));
 expect(screen.getByRole('note')).toBeTruthy();
 await screen.findByRole('textbox');await userEvent.click(screen.getByRole('radio',{name:'Delete inventory and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 await waitFor(()=>expect(deleted).toHaveBeenCalledTimes(1));
 expect(accountRequest).toHaveBeenCalledWith('owner','/resource-removal/inventory/hardware',{method:'POST',body:{name:'Hardware',action:'delete'}});
});
