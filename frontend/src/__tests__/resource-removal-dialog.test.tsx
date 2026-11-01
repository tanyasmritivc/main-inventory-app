/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {act,fireEvent,render,screen,waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {ResourceRemovalDialog,type RemovalKind} from '@/components/site/resource-removal-dialog';
import {accountRequest} from '@/lib/account-request';
import {ApiError} from '@/lib/api';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const done=jest.fn(),close=jest.fn();
const preview=(kind:RemovalKind)=>({kind,id:'resource',name:'Workshop',items:7,spaces:2,inventories:1,workspaces:1,can_move:true,destinations:[{id:'bench',name:'Bench'}]});
beforeEach(()=>jest.clearAllMocks());
for(const kind of ['organization','workspace','inventory','space'] as RemovalKind[]) {
 for(const action of ['move','delete'])test(`${kind}: explicit ${action} choice and exact name required`,async()=>{
  jest.mocked(accountRequest).mockImplementation(async(_account,_path,options)=>(options?.method?{kind,id:'resource',action,deleted:action==='delete',moved:action==='move'}:preview(kind)) as never);
  render(<ResourceRemovalDialog kind={kind} id="resource" name="Workshop" accountId="admin" onClose={close} onDone={done}/>);
  const input=await screen.findByRole('textbox');
  expect(screen.getByText(/7 items/)).toBeTruthy();
  await userEvent.type(input,'Workshop');
  expect(screen.getByRole('button',{name:`Delete ${kind}`})).toHaveProperty('disabled',true);
  await userEvent.click(screen.getAllByRole('radio')[action==='move'?0:1]);
  if(action==='move'&&(kind==='space'||kind==='inventory'))await userEvent.selectOptions(screen.getByRole('combobox'),'bench');
  await userEvent.click(screen.getByRole('button',{name:action==='move'?'Move and continue':`Delete ${kind}`}));
  await waitFor(()=>expect(done).toHaveBeenCalledTimes(1));
  expect(accountRequest).toHaveBeenLastCalledWith('admin',`/resource-removal/${kind}/resource`,{method:'POST',body:{name:'Workshop',action,...(action==='move'&&(kind==='space'||kind==='inventory')?{destination_id:'bench'}:{})}});
 });
}
test('cancel checks contents but never writes',async()=>{
 jest.mocked(accountRequest).mockResolvedValue(preview('inventory'));
 render(<ResourceRemovalDialog kind="inventory" id="resource" name="Workshop" accountId="admin" onClose={close} onDone={done}/>);
 await screen.findByRole('textbox');await userEvent.click(screen.getByRole('button',{name:'Cancel'}));
 expect(close).toHaveBeenCalledTimes(1);expect(jest.mocked(accountRequest).mock.calls.every(c=>!c[2]?.method)).toBe(true);
});
test('permission error and wrong receipt keep confirmation and do not navigate',async()=>{
 let attempts=0;
 jest.mocked(accountRequest).mockImplementation(async(_account,_path,options)=>{
  if(!options?.method)return preview('inventory') as never;
  if(++attempts===1)throw new ApiError('Denied',403,'Your access changed.');
  return {kind:'inventory',id:'another',action:'delete',deleted:true} as never;
 });
 render(<ResourceRemovalDialog kind="inventory" id="resource" name="Workshop" accountId="admin" onClose={close} onDone={done}/>);
 await userEvent.type(await screen.findByRole('textbox'),'Workshop');await userEvent.click(screen.getAllByRole('radio')[1]);
 await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));expect((await screen.findByRole('alert')).textContent).toContain('access changed');
 await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));await waitFor(()=>expect(screen.getByRole('alert').textContent).toContain('could not be confirmed'));expect(done).not.toHaveBeenCalled();
});
test('pending deletion is single-flight and unmounted responses are ignored',async()=>{
 let finish!:(value:never)=>void;
 jest.mocked(accountRequest).mockImplementation(async(_account,_path,options)=>options?.method?await new Promise(resolve=>{finish=resolve;}):preview('inventory') as never);
 const view=render(<ResourceRemovalDialog kind="inventory" id="resource" name="Workshop" accountId="admin" onClose={close} onDone={done}/>);
 await userEvent.type(await screen.findByRole('textbox'),'Workshop');await userEvent.click(screen.getAllByRole('radio')[1]);
 const form=screen.getByRole('button',{name:'Delete inventory'}).closest('form')!;fireEvent.submit(form);fireEvent.submit(form);
 expect(accountRequest).toHaveBeenCalledTimes(2);await userEvent.keyboard('{Escape}');expect(close).not.toHaveBeenCalled();view.unmount();
 await act(async()=>finish({kind:'inventory',id:'resource',action:'delete',deleted:true} as never));expect(done).not.toHaveBeenCalled();
});
