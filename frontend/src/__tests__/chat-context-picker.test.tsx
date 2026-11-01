/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { ChatContextPicker } from "@/components/site/chat-context-picker";
import { accountRequest } from "@/lib/account-request";
jest.mock("@/lib/account-request", () => ({accountRequest:jest.fn()}));
const inventories=[{inventory_id:"inv-a",name:"Parts",workspace_name:"Workshop"},{inventory_id:"inv-b",name:"Tools",workspace_name:"Garage"}];
beforeEach(()=>jest.clearAllMocks());
test("source selection stays in the selected authorized inventory and old search results cannot replace new ones",async()=>{
 let finishOld!:(v:unknown)=>void;
 jest.mocked(accountRequest).mockImplementation(async (_actor,path)=>{
  if(path.endsWith('/directory'))return {inventories} as never;
  if(path.includes('inventory_id=inv-a'))return new Promise(resolve=>{finishOld=resolve;}) as never;
  return {sources:[{kind:'item',inventory_id:'inv-b',resource_id:'drill',name:'Drill'}],next_offset:null} as never;
 });
 const select=jest.fn();render(<ChatContextPicker accountId="actor" worldId="org" kind="item" onSelect={select} onClose={jest.fn()}/>);
 await waitFor(()=>expect(finishOld).toBeDefined());
 fireEvent.change(screen.getByRole('combobox'),{target:{value:'inv-b'}});
 await screen.findByRole('button',{name:'Drill +'});
 await act(async()=>finishOld({sources:[{kind:'item',inventory_id:'inv-a',resource_id:'old',name:'Old result'}],next_offset:null}));
 expect(screen.queryByText('Old result')).toBeNull();
 fireEvent.click(screen.getByRole('button',{name:'Drill +'}));
 expect(select).toHaveBeenCalledWith({kind:'item',inventory_id:'inv-b',resource_id:'drill',name:'Drill'});
 expect(accountRequest).toHaveBeenCalledWith('actor',expect.stringContaining('/worlds/org/chat-sources?inventory_id=inv-b&kind=item'));
});
test("a failed directory fetch never falls back to another inventory",async()=>{
 jest.mocked(accountRequest).mockRejectedValue(new Error('Access unavailable'));
 render(<ChatContextPicker accountId="actor" worldId="org" kind="space" onSelect={jest.fn()} onClose={jest.fn()}/>);
 await screen.findByRole('alert');
 expect(accountRequest).toHaveBeenCalledTimes(1);
 expect(screen.getAllByRole('button').some(button=>button.textContent==='Try again')).toBe(true);
});
