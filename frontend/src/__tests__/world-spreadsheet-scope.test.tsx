/** @jest-environment jsdom */
import {render,screen,fireEvent,waitFor} from '@testing-library/react';
import {WorldSpreadsheetImport} from '@/components/site/world-spreadsheet-import';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
jest.mock('@/components/site/direct-spreadsheet-import',()=>({DirectSpreadsheetImport:({spaceName}:{spaceName:string})=><p>Import into {spaceName}</p>}));
const request=jest.mocked(accountRequest);
const file=new File(['Name\nPart'],'parts.csv');
const group=(id:string,editable=true)=>({inventory_id:id,name:id,can_edit:editable,spaces:[{id:`space-${id}`,name:`Space ${id}`}]});
function renderScope(worldId='org-a',accountId='actor') {return <WorldSpreadsheetImport file={file} worldId={worldId} accountId={accountId} onClose={()=>{}}/>;}
beforeEach(()=>request.mockReset());
test.each(['org-a','org-b','personal'])('only offers editable inventories belonging to %s',async world=>{
 request.mockImplementation(async(_,path)=>path.endsWith('/directory')?{world,inventories:[group(world),group('view-only',false)]}:{inventories:[group('org-a'),group('org-b'),group('personal'),group('view-only')]});
 render(renderScope(world));
 expect(await screen.findByRole('button',{name:`Space ${world}`})).toBeTruthy();
 for(const other of ['org-a','org-b','personal'].filter(x=>x!==world))expect(screen.queryByRole('button',{name:`Space ${other}`})).toBeNull();
 expect(screen.queryByRole('button',{name:'Space view-only'})).toBeNull();
 expect(request.mock.calls.map(c=>c[1])).toEqual([`/worlds/${world}/directory`,`/worlds/${world}/spaces`]);
 fireEvent.click(screen.getByRole('button',{name:`Space ${world}`}));
 expect(screen.getByText(`Import into Space ${world}`)).toBeTruthy();
});
test('wrong-world directory fails closed rather than showing destinations',async()=>{
 request.mockImplementation(async(_,path)=>path.endsWith('/directory')?{world:'personal',inventories:[group('personal')]}:{inventories:[group('personal')]});
 render(renderScope());await screen.findByRole('alert');expect(screen.queryByRole('button',{name:'Space personal'})).toBeNull();
});
test('organization switch drops previous selection and ignores late results',async()=>{
 let finish!: (value:unknown)=>void;
 request.mockImplementation(async(_,path)=>path==='/worlds/org-a/directory'?new Promise(resolve=>{finish=resolve;}):path.endsWith('/directory')?{world:'org-b',inventories:[group('org-b')]}:{inventories:[group('org-a'),group('org-b')]});
 const view=render(renderScope());
 view.rerender(renderScope('org-b'));
 await screen.findByRole('button',{name:'Space org-b'});
 finish({world:'org-a',inventories:[group('org-a')]});
 await waitFor(()=>expect(screen.queryByRole('button',{name:'Space org-a'})).toBeNull());
 fireEvent.click(screen.getByRole('button',{name:'Space org-b'}));
 expect(screen.getByText('Import into Space org-b')).toBeTruthy();
 view.rerender(renderScope('org-b','different-actor'));
 expect(screen.queryByText('Import into Space org-b')).toBeNull();
 await screen.findByRole('button',{name:'Space org-b'});
});
