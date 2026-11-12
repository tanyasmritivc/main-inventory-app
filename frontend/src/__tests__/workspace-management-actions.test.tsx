/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {render,screen,waitFor,act} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {DeleteWorkspaceDialog,WorkspaceManagementActions} from '@/components/site/workspace-management-actions';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const preview={kind:'workspace',id:'ftc',name:'FTC ROBOTS',workspaces:0,inventories:2,spaces:2,items:3,can_move:true,destinations:[]};
beforeEach(()=>{jest.clearAllMocks();jest.mocked(accountRequest).mockReset();jest.mocked(accountRequest).mockResolvedValue(preview);});
const props={id:'ftc',name:'FTC ROBOTS',accountId:'owner',onClose:jest.fn(),onDeleted:jest.fn()};
test('workspace menu exposes rename and deletion outside People',async()=>{
 render(<WorkspaceManagementActions {...props} onRenamed={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage workspace FTC ROBOTS'}));
 expect(await screen.findByRole('menuitem',{name:'Rename workspace'})).toBeTruthy();
 await userEvent.click(screen.getByRole('menuitem',{name:'Delete workspace'}));
 expect(screen.getByRole('dialog',{name:'Delete workspace'})).toBeTruthy();
 expect(await screen.findByRole('radio',{name:/Move inventories to their owners/})).toBeTruthy();
});
test('exact name required, pending submission cannot duplicate, confirmed deletion completes',async()=>{
 let finish!:(v:unknown)=>void;
 jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockReturnValue(new Promise(resolve=>{finish=resolve;}));
 render(<DeleteWorkspaceDialog {...props}/>);
 const remove=await screen.findByRole('button',{name:'Delete workspace'});
 expect(remove).toHaveProperty('disabled',true);
 await userEvent.click(await screen.findByRole('radio',{name:'Delete workspace and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.dblClick(remove);
 expect(accountRequest).toHaveBeenCalledTimes(2);
 expect(accountRequest).toHaveBeenCalledWith('owner','/resource-removal/workspace/ftc',{method:'POST',body:{name:'FTC ROBOTS',action:'delete'}});
 expect(props.onDeleted).not.toHaveBeenCalled();
 await act(async()=>finish({deleted:true,kind:'workspace',id:'ftc',action:'delete'}));
 expect(props.onDeleted).toHaveBeenCalledTimes(1);
});
test('false receipt and server rejection never report deletion',async()=>{
 jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockResolvedValue({deleted:false});
 render(<DeleteWorkspaceDialog {...props}/>);
 await userEvent.click(await screen.findByRole('radio',{name:'Delete workspace and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));
 await screen.findByRole('alert');expect(props.onDeleted).not.toHaveBeenCalled();
 jest.mocked(accountRequest).mockRejectedValue(new Error('Access revoked'));
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledTimes(3));
 expect(props.onDeleted).not.toHaveBeenCalled();
});
test('cancel and unmount during a request cannot redirect',async()=>{
 const view=render(<DeleteWorkspaceDialog {...props}/>);
 await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(jest.mocked(accountRequest).mock.calls.some(call=>call[2]?.method)).toBe(false);
 let finish!:(v:unknown)=>void;
 jest.mocked(accountRequest).mockReturnValue(new Promise(resolve=>{finish=resolve;}));
 await userEvent.click(await screen.findByRole('radio',{name:'Delete workspace and all its contents'}));await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));view.unmount();
 await act(async()=>finish({deleted:true,kind:'workspace',id:'ftc',action:'delete'}));expect(props.onDeleted).not.toHaveBeenCalled();
});
