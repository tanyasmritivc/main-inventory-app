/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {render,screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {WorkspaceManagementActions} from '@/components/site/workspace-management-actions';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
beforeEach(()=>{jest.clearAllMocks();jest.mocked(accountRequest).mockResolvedValue({kind:'workspace',id:'ftc',name:'FTC ROBOTS',items:7,spaces:2,inventories:1,workspaces:0,can_move:true,destinations:[]});});
const props={id:'ftc',name:'FTC ROBOTS',accountId:'owner',onClose:jest.fn(),onDeleted:jest.fn()};
test('workspace menu exposes rename and deletion outside People',async()=>{
 render(<WorkspaceManagementActions {...props} onRenamed={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage workspace FTC ROBOTS'}));
 expect(await screen.findByRole('menuitem',{name:'Rename workspace'})).toBeTruthy();
 await userEvent.click(screen.getByRole('menuitem',{name:'Delete workspace'}));
 expect(screen.getByRole('dialog',{name:'Delete workspace'})).toBeTruthy();
 expect(await screen.findByRole('radio',{name:/Move inventories/})).toBeTruthy();
});
