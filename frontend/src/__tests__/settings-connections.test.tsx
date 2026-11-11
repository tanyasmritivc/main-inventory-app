/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { SettingsConnections } from '@/components/site/settings-connections';
import { InventoryCommerce } from '@/components/site/commerce-client';
import { accountRequest } from '@/lib/account-request';
import { useApiSession } from '@/lib/use-api-session';
import { activeInventory, selectInventory } from '@/lib/inventory-selection';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: jest.fn() }));
jest.mock('@/components/site/commerce-client', () => ({ InventoryCommerce: jest.fn(() => <div>Connection controls</div>) }));
const detail = { inventory_id: 'a', name: 'Hardware', can_edit: true };
const request = async (_actor: string, path: string) => {
  if (path === '/inventory-workspaces') return {workspaces: [{workspace_id:'team',name:'Team'}, {workspace_id:'personal',name:'Personal'}]};
  if (path.includes('/inventories?')) return {inventories:[{inventory_id:'a',name:'Hardware'},{inventory_id:'b',name:'Tools'}],next_offset:null};
  return {inventory:detail};
};
beforeEach(() => {
  jest.clearAllMocks(); selectInventory(null);
  jest.mocked(useApiSession).mockReturnValue({accountId:'actor',loading:false,error:null} as ReturnType<typeof useApiSession>);
  jest.mocked(accountRequest).mockImplementation(request);
});
async function chooseInventory() {
  render(<SettingsConnections />);
  fireEvent.change(await screen.findByLabelText('Workspace'), {target:{value:'team'}});
  fireEvent.change(await screen.findByLabelText('Inventory'), {target:{value:'a'}});
}
test('settings verifies the selected inventory without changing the global inventory boundary', async () => {
  await chooseInventory(); await screen.findByText('Connection controls');
  expect(accountRequest).toHaveBeenCalledWith('actor','/inventories/a');
  expect(InventoryCommerce).toHaveBeenCalledWith(expect.objectContaining({inventory:{...detail,accountId:'actor'},inventoryBinding:null,embedded:true}),undefined);
  expect(activeInventory()).toBeNull();
});
test('read-only inventory cannot mount connection controls', async () => {
  jest.mocked(accountRequest).mockImplementation(async (actor,path) => path === '/inventories/a' ? {inventory:{...detail,can_edit:false}} : request(actor,path));
  await chooseInventory(); await screen.findByText(/editing access/);
  expect(InventoryCommerce).not.toHaveBeenCalled();
});
test('changing workspace discards a late inventory verification response', async () => {
  let resolve!: (value:unknown)=>void;
  jest.mocked(accountRequest).mockImplementation((actor,path) => path === '/inventories/a' ? new Promise(done=>{resolve=done;}) : request(actor,path));
  await chooseInventory(); await waitFor(()=>expect(resolve).toBeDefined());
  fireEvent.change(screen.getByLabelText('Workspace'),{target:{value:'personal'}});
  await act(async()=>resolve({inventory:detail}));
  expect(InventoryCommerce).not.toHaveBeenCalled();
  expect(screen.queryByText('Connection controls')).toBeNull();
});
test('a mismatched inventory response is rejected', async () => {
  jest.mocked(accountRequest).mockImplementation(async (actor,path) => path === '/inventories/a' ? {inventory:{...detail,inventory_id:'other'}} : request(actor,path));
  await chooseInventory(); await screen.findByRole('alert');
  expect(InventoryCommerce).not.toHaveBeenCalled();
});
