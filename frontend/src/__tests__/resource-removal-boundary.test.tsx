/** @jest-environment jsdom */
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {act,fireEvent,render,screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {ResourceRemovalDialog} from '@/components/site/resource-removal-dialog';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const preview={kind:'inventory',id:'a',name:'Parts',workspaces:0,inventories:0,spaces:1,items:2,can_move:true,destinations:[{id:'personal',name:'Personal'}]};
const props={kind:'inventory' as const,id:'a',name:'Parts',accountId:'owner',onClose:jest.fn(),onDone:jest.fn()};
beforeEach(()=>{jest.clearAllMocks();jest.mocked(accountRequest).mockReset();});
test.each(['account','resource'])('a pending removal cannot complete after changing %s',async boundary=>{
 let finish!:(value:unknown)=>void;
 jest.mocked(accountRequest).mockImplementation(async(_actor,path,options)=>{
  if(options?.method)return new Promise(resolve=>{finish=resolve;});
  return {...preview,id:path.endsWith('/b')?'b':'a'};
 });
 const view=render(<ResourceRemovalDialog {...props}/>);
 await userEvent.click(await screen.findByRole('radio',{name:'Delete inventory and all its contents'}));
 await userEvent.type(screen.getByRole('textbox'),'Parts');fireEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 view.rerender(<ResourceRemovalDialog {...props} {...(boundary==='account'?{accountId:'other'}:{id:'b'})}/>);
 expect(await screen.findByRole('textbox')).toHaveProperty('value','');
 await act(async()=>finish({kind:'inventory',id:'a',action:'delete',deleted:true}));
 expect(props.onDone).not.toHaveBeenCalled();expect(screen.getByRole('button',{name:'Delete inventory'})).toHaveProperty('disabled',true);
});
test('a move receipt cannot confirm a requested deletion',async()=>{
 jest.mocked(accountRequest).mockResolvedValueOnce(preview).mockResolvedValue({kind:'inventory',id:'a',action:'delete',moved:true,deleted:false});
 render(<ResourceRemovalDialog {...props}/>);
 await userEvent.click(await screen.findByRole('radio',{name:'Delete inventory and all its contents'}));
 await userEvent.type(screen.getByRole('textbox'),'Parts');await userEvent.click(screen.getByRole('button',{name:'Delete inventory'}));
 expect((await screen.findByRole('alert')).textContent).toContain('could not be confirmed');expect(props.onDone).not.toHaveBeenCalled();
});
