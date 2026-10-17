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
beforeEach(()=>jest.clearAllMocks());
test('deletion requires exact name and a confirmed receipt before refreshing',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockResolvedValue({deleted:true,inventory_id:'hardware'});
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 const remove=screen.getByRole('button',{name:'Delete inventory'});
 expect((remove as HTMLButtonElement).disabled).toBe(true);
 await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(remove);
 await waitFor(()=>expect(deleted).toHaveBeenCalledTimes(1));
 expect(accountRequest).toHaveBeenCalledWith('owner','/inventories/hardware',{method:'DELETE',body:{name:'Hardware'}});
});
test('saved-content rejection stays actionable and never reports success',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockRejectedValue(new ApiError('This inventory contains saved records.',409,{}));
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 await screen.findByRole('alert');expect(deleted).not.toHaveBeenCalled();expect(screen.getByRole('textbox')).toHaveProperty('value','Hardware');
});
test('cancel does not mutate and rename-only access never reveals deletion',async()=>{
 const close=jest.fn();
 const view=render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={close} onDeleted={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(accountRequest).not.toHaveBeenCalled();expect(close).toHaveBeenCalled();
 view.unmount();render(<InventoryManagementActions inventory={{...inventory,can_manage:false}} onRename={jest.fn()} onDelete={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage Hardware'}));
 expect(await screen.findByRole('menuitem',{name:'Rename'})).toBeTruthy();expect(screen.queryByRole('menuitem',{name:'Delete inventory'})).toBeNull();
});

test('including contents is a separate explicit choice sent only after exact confirmation',async()=>{
 const deleted=jest.fn();jest.mocked(accountRequest).mockResolvedValue({deleted:true,inventory_id:'hardware',file_cleanup_pending:true});
 render(<DeleteInventoryDialog inventory={inventory} accountId="owner" onClose={jest.fn()} onDeleted={deleted}/>);
 await userEvent.click(screen.getByRole('checkbox'));
 expect(screen.getByRole('note')).toBeTruthy();
 await userEvent.type(screen.getByRole('textbox'),'Hardware');await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 await waitFor(()=>expect(deleted).toHaveBeenCalledWith(true));
 expect(accountRequest).toHaveBeenCalledWith('owner','/inventories/hardware',{method:'DELETE',body:{name:'Hardware',delete_contents:true}});
});
