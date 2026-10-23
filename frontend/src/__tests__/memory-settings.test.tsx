/** @jest-environment jsdom */
import { render, screen, waitFor, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemorySettings } from "@/components/site/memory-settings";
import { accountRequest } from "@/lib/account-request";
import { selectInventory } from "@/lib/inventory-selection";
import { ApiError } from "@/lib/api";
jest.mock("@/lib/account-request",()=>({accountRequest:jest.fn()}));
const confirm=jest.fn(async()=>true);
jest.mock("@/components/site/app-dialog-provider",()=>({useAppDialog:()=>({confirmAction:confirm})}));
const request=jest.mocked(accountRequest);
const empty={enabled:false,revision:0,entries:[],legacy:[],legacy_truncated:false};
beforeEach(()=>{jest.clearAllMocks();selectInventory(null);Object.defineProperty(global.crypto,'randomUUID',{configurable:true,value:jest.fn(()=>"10000000-0000-4000-8000-000000000001")});});
afterEach(()=>selectInventory(null));

test('loads private memory, enables it and saves a confirmed preference',async()=>{
  let data={...empty};
  request.mockImplementation(async(_account,path,options)=>{
    if(path==='/memory' && options?.method==='POST'){
      const body=options.body as Record<string,unknown>;
      if(body.action==='settings') data={...data,enabled:body.enabled as boolean,revision:1};
      return {saved:true};
    }
    return data;
  });
  render(<MemorySettings accountId="a"/>);
  const checkbox=await screen.findByLabelText('Use personalization');
  await userEvent.click(checkbox);
  await waitFor(()=>expect((checkbox as HTMLInputElement).checked).toBe(true));
  await userEvent.selectOptions(screen.getByLabelText('Answer format'),'bullets');
  await waitFor(()=>expect(request).toHaveBeenCalledWith('a','/memory',expect.objectContaining({body:expect.objectContaining({action:'set',key:'answer_format',value:'bullets',expected_revision:1})})));
});

test('unknown outcome retries the same operation, then refreshes',async()=>{
  let fail=true;
  request.mockImplementation(async(_account,_path,options)=>{
    if(options?.method==='POST') {if(fail) throw new Error('timeout');return {saved:true};}
    return empty;
  });
  render(<MemorySettings accountId="a"/>);
  await userEvent.click(await screen.findByLabelText('Use personalization'));
  await screen.findByText('The save could not be confirmed. Retry save uses the same request.');
  const original=request.mock.calls.find(c=>c[2]?.method==='POST')![2]!.body;
  fail=false;await userEvent.click(screen.getByText('Retry save'));
  await waitFor(()=>expect(request.mock.calls.filter(c=>c[2]?.method==='POST')).toHaveLength(2));
  expect(request.mock.calls.filter(c=>c[2]?.method==='POST')[1][2]!.body).toEqual(original);
});

test('failed initial read has retry and no pretend active controls',async()=>{
  request.mockRejectedValueOnce(new Error('offline')).mockResolvedValue(empty);
  render(<MemorySettings accountId="a"/>);
  await screen.findByRole('alert');
  expect(screen.queryByLabelText('Use personalization')).toBeNull();
  await userEvent.click(screen.getByText('Refresh memory'));
  await screen.findByLabelText('Use personalization');
});

test('foreign late response is discarded when switching account',async()=>{
  let resolve!:(value:unknown)=>void;
  request.mockImplementation(async(account)=>account==='a' ? new Promise(r=>resolve=r) : empty);
  const view=render(<MemorySettings accountId="a"/>);
  view.rerender(<MemorySettings accountId="b"/>);
  await screen.findByLabelText('Use personalization');
  await act(async()=>resolve({...empty,legacy:[{key:'private',value:'FOREIGN_SECRET',state:'legacy'}]}));
  expect(screen.queryByText(/FOREIGN_SECRET/)).toBeNull();
});

test('clear requires confirmation and sends no inventory or user ID',async()=>{
  request.mockImplementation(async(_account,_path,options)=>options?.method==='POST' ? {saved:true} : empty);
  render(<MemorySettings accountId="a"/>);
  await userEvent.click(await screen.findByText('Forget personalization'));
  await waitFor(()=>expect(confirm).toHaveBeenCalled());
  const body=request.mock.calls.find(c=>c[2]?.method==='POST')![2]!.body as Record<string,unknown>;
  expect(body.action).toBe('clear');expect(body.user_id).toBeUndefined();expect(body.inventory_id).toBeUndefined();
});

test('conflict requires refresh instead of replaying a stale preference',async()=>{
  request.mockImplementation(async(_account,_path,options)=>{if(options?.method==='POST') throw new ApiError('conflict',409,{});return empty;});
  render(<MemorySettings accountId="a"/>);
  await userEvent.click(await screen.findByLabelText('Use personalization'));
  await screen.findByText('Memory changed. Refresh before trying again.');
  expect(screen.queryByText('Retry save')).toBeNull();
});
