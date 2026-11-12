/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {render,screen,waitFor,act} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {DeleteWorkspaceDialog,WorkspaceManagementActions} from '@/components/site/workspace-management-actions';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
beforeEach(()=>jest.clearAllMocks());
const props={id:'ftc',name:'FTC ROBOTS',accountId:'owner',onClose:jest.fn(),onDeleted:jest.fn()};
test('workspace menu exposes rename and deletion outside People',async()=>{
 render(<WorkspaceManagementActions {...props} onRenamed={jest.fn()}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage workspace FTC ROBOTS'}));
 expect(await screen.findByRole('menuitem',{name:'Rename workspace'})).toBeTruthy();
 await userEvent.click(screen.getByRole('menuitem',{name:'Delete workspace'}));
 expect(screen.getByRole('dialog',{name:'Delete workspace'})).toBeTruthy();
 expect(screen.getByText(/Physical inventories are retained/)).toBeTruthy();
});
test('exact name required, pending submission cannot duplicate, confirmed deletion completes',async()=>{
 let finish!:(v:unknown)=>void;
 jest.mocked(accountRequest).mockReturnValue(new Promise(resolve=>{finish=resolve;}));
 render(<DeleteWorkspaceDialog {...props}/>);
 const remove=screen.getByRole('button',{name:'Delete workspace'});
 expect(remove).toHaveProperty('disabled',true);
 await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.dblClick(remove);
 expect(accountRequest).toHaveBeenCalledTimes(1);
 expect(accountRequest).toHaveBeenCalledWith('owner','/teams/ftc',{method:'DELETE'});
 expect(props.onDeleted).not.toHaveBeenCalled();
 await act(async()=>finish({deleted:true}));
 expect(props.onDeleted).toHaveBeenCalledTimes(1);
});
test('false receipt and server rejection never report deletion',async()=>{
 jest.mocked(accountRequest).mockResolvedValue({deleted:false});
 render(<DeleteWorkspaceDialog {...props}/>);
 await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));
 await screen.findByRole('alert');expect(props.onDeleted).not.toHaveBeenCalled();
 jest.mocked(accountRequest).mockRejectedValue(new Error('Access revoked'));
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledTimes(2));
 expect(props.onDeleted).not.toHaveBeenCalled();
});
test('cancel and unmount during a request cannot redirect',async()=>{
 const view=render(<DeleteWorkspaceDialog {...props}/>);
 await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(accountRequest).not.toHaveBeenCalled();
 let finish!:(v:unknown)=>void;
 jest.mocked(accountRequest).mockReturnValue(new Promise(resolve=>{finish=resolve;}));
 await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));view.unmount();
 await act(async()=>finish({deleted:true}));expect(props.onDeleted).not.toHaveBeenCalled();
});
