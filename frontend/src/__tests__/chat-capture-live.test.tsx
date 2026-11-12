/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { ChatCaptureCard, CaptureScan, captureDisplayRows, captureUnknown, captureProgress, mapCaptureBox, captureDetails } from '@/components/site/chat-capture-card';
import { accountRequest } from '@/lib/account-request';
import type { ChatCapture, CaptureRow } from '@/lib/chat-sources';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
const row = (index: number, name: string, confidence?: number, needs_review = false): CaptureRow => ({index, selected:true,item:{name,category:'Parts',quantity:index+1,brand:'Maker',notes:'Exact notes',scan_evidence:{needs_review},...{confidence}}});
const fixture = (): ChatCapture => ({id:'11111111-1111-4111-8111-111111111111',revision:1,status:'draft',source_kind:'photo',items:[row(0,'Unknown',.2),row(1,'Motor',.72),row(2,'Bearing',.95)],inventory_id:'inventory-a',space_id:'space-a',location:'Bench'});
beforeEach(() => jest.clearAllMocks());
test('display sorting retains references, canonical indices and the original save order', () => {
 const capture=fixture(),original=JSON.stringify(capture);
 const rows=captureDisplayRows(capture);
 expect(rows.map(r=>r.index)).toEqual([2,1,0]);expect(rows[0]).toBe(capture.items[2]);expect(JSON.stringify(capture)).toBe(original);
 expect(captureDetails(rows[0])).toBe('Maker · Exact notes');
});
test('unknown names and real low confidence are last, with stable ties',()=>{
 for(const name of ['', 'unknown', 'UNIDENTIFIED','Object','item','Unknown item']) expect(captureUnknown(row(0,name))).toBe(true);
 expect(captureUnknown(row(0,'Bearing',.49))).toBe(true);expect(captureUnknown(row(0,'Bearing',.5))).toBe(false);
 const c=fixture();c.items=[row(0,'A',.9),row(1,'B',.9),row(2,'Unknown',1)];expect(captureDisplayRows(c).map(r=>r.index)).toEqual([0,1,2]);
});
test('without complete confidence metadata warning and missing-quantity groups remain stable',()=>{
 const c=fixture();c.items=[row(0,'Unknown'),row(1,'Missing'),row(2,'Review',undefined,true),row(3,'Complete'),row(4,'Complete too')];c.summary={unknown_quantity_indices:[1]};
 expect(captureDisplayRows(c).map(r=>r.index)).toEqual([3,4,2,1,0]);
});
test('box mapping accounts for horizontal and vertical letterboxing',()=>{
 expect(mapCaptureBox({x:10,y:20,width:30,height:40},{width:100,height:200},{width:300,height:300})).toEqual({left:90,top:30,width:45,height:60});
 expect(mapCaptureBox({x:10,y:20,width:30,height:40},{width:200,height:100},{width:300,height:300})).toEqual({left:15,top:105,width:45,height:60});
 expect(mapCaptureBox({x:0,y:0,width:10,height:10},{width:0,height:100},{width:300,height:300})).toBeNull();
});
test('progress advances only from received stages and checked counts',()=>{
 expect(captureProgress(['Reading your photo...'])).toBe(0);
 expect(captureProgress(['Preparing your photo...'])).toBe(.2);
 expect(captureProgress(['Finding objects in your photo...','Checked 2 of 4 objects...'])).toBe(.7);
 expect(captureProgress(['Checked 4 of 4 objects...','Reading your photo...'])).toBe(.8);
 render(<CaptureScan photo="blob:fixture" steps={['Finding objects in your photo...']} stopped={false} failed={false} onClose={()=>{}} onRetry={()=>{}}/>);
 expect(screen.getByRole('progressbar').getAttribute('aria-valuenow')).toBe('40');expect(screen.queryByText('Waiting')).toBeNull();
});
test('checkbox and editor address the canonical item after display sorting, and save payload is unchanged',async()=>{
 let c=fixture();
 jest.mocked(accountRequest).mockImplementation(async(_account,path,options)=>{
  if(path==='/worlds/personal/spaces')return {inventories:[{inventory_id:'inventory-a',name:'Inventory',can_edit:true,spaces:[{id:'space-a',name:'Bench'}]}]} as never;
  if(options?.method==='PATCH'){
   const body=options.body as {revision:number;changes:{items:{index:number;selected?:boolean;name?:string}[]}};
   const patch=body.changes.items[0];c={...c,revision:c.revision+1,items:c.items.map(r=>r.index===patch.index?{...r,selected:patch.selected??r.selected,item:{...r.item,name:patch.name??r.item.name}}:r)};
  }
  return {capture:c} as never;
 });
 render(<ChatCaptureCard capture={c} accountId="account" worldId="personal" conversationId="chat"/>);
 await waitFor(()=>expect(accountRequest).toHaveBeenCalled());
 const rows=screen.getAllByRole('listitem');expect(within(rows[0]).getByRole('checkbox',{name:'Include Bearing'})).toBeTruthy();
 fireEvent.click(screen.getByRole('checkbox',{name:'Include Bearing'}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('account',expect.stringContaining('/captures/'),expect.objectContaining({method:'PATCH',body:{revision:1,changes:{items:[{index:2,selected:false}]}}})));
 await waitFor(()=>expect((screen.getByRole('checkbox',{name:'Include Bearing'}) as HTMLInputElement).disabled).toBe(false));
 fireEvent.click(screen.getByRole('button',{name:'Edit Motor'}));const name=screen.getByRole('textbox',{name:'Name for row 2'});fireEvent.change(name,{target:{value:'Exact changed name'}});fireEvent.blur(name);
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('account',expect.stringContaining('/captures/'),expect.objectContaining({method:'PATCH',body:{revision:2,changes:{items:[{index:1,name:'Exact changed name'}]}}})));
 await waitFor(()=>expect((screen.getByRole('button',{name:'Confirm and save'}) as HTMLButtonElement).disabled).toBe(false));
 fireEvent.click(screen.getByRole('button',{name:'Confirm and save'}));
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('account',expect.stringContaining('/save'),{method:'POST',body:{revision:3,allow_duplicates:false,confirm_items:true}}));
 expect(c.items.map(r=>r.index)).toEqual([0,1,2]);
});
