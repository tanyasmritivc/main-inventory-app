/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {render,screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {InventoryManagementActions,DeleteInventoryDialog} from '@/components/site/inventory-management-actions';
import {accountRequest} from '@/lib/account-request';
import type {DirectoryInventory} from '@/lib/workspace-directory';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const inventory={inventory_id:'parts',name:'Parts',can_rename:true,can_manage:false} as DirectoryInventory;
test('rename-only access never exposes deletion',async()=>{
 render(<InventoryManagementActions inventory={inventory} onRename={jest.fn()} onDelete={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage Parts'}));
 expect(screen.getByRole('menuitem',{name:'Rename'})).toBeTruthy();expect(screen.queryByRole('menuitem',{name:'Delete inventory'})).toBeNull();
});
test('inventory dialog offers move or full deletion without an empty-only default',async()=>{
 jest.mocked(accountRequest).mockResolvedValue({kind:'inventory',id:'parts',name:'Parts',items:7,spaces:1,inventories:1,workspaces:0,can_move:true,destinations:[]});
 render(<DeleteInventoryDialog inventory={inventory} accountId="admin" onClose={jest.fn()} onDeleted={jest.fn()}/>);
 expect(await screen.findByRole('radio',{name:/Move this inventory/})).toHaveProperty('checked',false);
 expect(screen.getByRole('radio',{name:'Delete inventory and all its contents'})).toHaveProperty('checked',false);
});
