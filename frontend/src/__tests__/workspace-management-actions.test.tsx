/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {act,render,screen,waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {accountRequest} from '@/lib/account-request';
import {preview,receipt,mutations} from './removal-fixture';
import {DeleteWorkspaceDialog, WorkspaceManagementActions} from '@/components/site/workspace-management-actions';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const close=jest.fn(),deleted=jest.fn();
let remove: jest.Mock;
beforeEach(()=>{
 jest.clearAllMocks(); remove=jest.fn().mockResolvedValue(receipt('workspace','ftc'));
 jest.mocked(accountRequest).mockImplementation(async(_actor,_path,options)=> options?.method ? remove() : preview('workspace','ftc','FTC ROBOTS') as never);
});
async function selectDelete(){
 const choice=await screen.findByRole('radio',{name:'Delete workspace and all its contents'});
 await userEvent.click(choice);
}
test('exact name and explicit destructive choice are required before a confirmed deletion',async()=>{
 render(<DeleteWorkspaceDialog id="ftc" name="FTC ROBOTS" accountId="owner" onClose={close} onDeleted={deleted}/>);
 const input=await screen.findByRole('textbox');
 const submit=screen.getByRole('button',{name:'Delete workspace'});
 await userEvent.type(input,'FTC ROBOTS');expect(submit).toHaveProperty('disabled',true);
 await selectDelete();expect(screen.getByRole('note')).toBeTruthy();
 await userEvent.clear(input);await userEvent.type(input,'wrong name');expect(submit).toHaveProperty('disabled',true);
 await userEvent.clear(input);await userEvent.type(input,'FTC ROBOTS');await userEvent.click(submit);
 await waitFor(()=>expect(deleted).toHaveBeenCalledTimes(1));
 expect(mutations()).toEqual([['owner','/resource-removal/workspace/ftc',{method:'POST',body:{name:'FTC ROBOTS',action:'delete'}}]]);
});
test('false receipts and rejected writes preserve the confirmation without reporting success',async()=>{
 remove.mockResolvedValueOnce({...receipt('workspace','ftc'),deleted:false}).mockRejectedValueOnce(new Error('offline'));
 render(<DeleteWorkspaceDialog id="ftc" name="FTC ROBOTS" accountId="owner" onClose={close} onDeleted={deleted}/>);await selectDelete();await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));await screen.findByRole('alert');expect(deleted).not.toHaveBeenCalled();
 await userEvent.click(screen.getByRole('button',{name:'Delete workspace'}));await waitFor(()=>expect(remove).toHaveBeenCalledTimes(2));
 expect(deleted).not.toHaveBeenCalled();expect(screen.getByRole('textbox')).toHaveProperty('value','FTC ROBOTS');
});
test('Cancel reads impact but makes no mutation',async()=>{
 render(<DeleteWorkspaceDialog id="ftc" name="FTC ROBOTS" accountId="owner" onClose={close} onDeleted={deleted}/>);await screen.findByRole('textbox');
 await userEvent.click(screen.getByRole('button',{name:'Cancel'}));expect(close).toHaveBeenCalledTimes(1);expect(mutations()).toEqual([]);
});
test('pending submissions cannot duplicate or complete after unmount',async()=>{
 let finish!:(value:unknown)=>void;remove.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}));
 const view=render(<DeleteWorkspaceDialog id="ftc" name="FTC ROBOTS" accountId="owner" onClose={close} onDeleted={deleted}/>);await selectDelete();await userEvent.type(screen.getByRole('textbox'),'FTC ROBOTS');
 await userEvent.dblClick(screen.getByRole('button',{name:'Delete workspace'}));expect(remove).toHaveBeenCalledTimes(1);
 await userEvent.keyboard('{Escape}');expect(close).not.toHaveBeenCalled();view.unmount();
 await act(async()=>finish(receipt('workspace','ftc')));expect(deleted).not.toHaveBeenCalled();
});
test('workspace management opens the real impact preview',async()=>{
 render(<WorkspaceManagementActions id="ftc" name="FTC ROBOTS" accountId="owner" onRenamed={jest.fn()} onDeleted={deleted}/>);
 await userEvent.click(screen.getByRole('button',{name:'Manage workspace FTC ROBOTS'}));
 expect(await screen.findByRole('menuitem',{name:'Rename workspace'})).toBeTruthy();
 await userEvent.click(screen.getByRole('menuitem',{name:'Delete workspace'}));
 expect(await screen.findByRole('radio',{name:/Move inventories/})).toBeTruthy();
 expect(screen.getByRole('dialog',{name:'Delete workspace'})).toBeTruthy();
});
