/** @jest-environment jsdom */
import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { CadPurchasing } from '@/components/cad/cad-purchasing';
import { accountRequest } from '@/lib/account-request';
import { purchaseCsv, type PurchasePlan } from '@/lib/cad-purchasing';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/inventory-selection', () => ({ activeInventory: () => ({ accountId:'actor', inventory_id:'inventory' }) }));
const request = accountRequest as jest.Mock;
const plan: PurchasePlan = { id:'12345678-1234-1234-1234-123456789abc', inventory_id:'inventory', name:'Robot', state:'draft', revision:1, inventory_as_of:'2026-11-16T00:00:00Z', lines:[], order_reference:null, totals:{} };
function replies(edit = true, approve = true) {
  request.mockImplementation(async (_actor, path) => {
    if (path === '/cad/capabilities') return { inventory_id:'inventory', purchasing:true, can_edit:edit, can_approve:approve };
    if (path.startsWith('/cad/purchases?')) return {inventory_id:'inventory',plans:[plan],next_offset:null};
    return plan;
  });
}
beforeEach(() => { jest.clearAllMocks(); sessionStorage.clear(); });

test('purchase features are explicit and unavailable servers do not query new tables', async () => {
  request.mockResolvedValue({inventory_id:'inventory',purchasing:false});
  render(<CadPurchasing versionId="bom" />); expect(request).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Open purchase plans'));
  expect(await screen.findByText(/not enabled on this server/)).toBeTruthy();
  expect(request).toHaveBeenCalledTimes(1);
});

test('viewer does not get creation, approval or receiving controls', async () => {
  replies(false, false); render(<CadPurchasing versionId="bom" />);
  fireEvent.click(screen.getByText('Open purchase plans')); fireEvent.click(await screen.findByText('Robot / draft', {selector:'button'}));
  await screen.findByRole('heading',{name:'Robot / draft'});
  expect(screen.queryByText('Create plan from selected BOM')).toBeNull();
  expect(screen.queryByText('Approve selected quotes and quantities')).toBeNull();
});

test('unknown save outcomes keep the same request across retry and remount', async () => {
  replies(); const view=render(<CadPurchasing versionId="bom" />);
  fireEvent.click(screen.getByText('Open purchase plans')); await screen.findByText('Create plan from selected BOM');
  request.mockRejectedValueOnce(new Error('Network interrupted'));
  fireEvent.click(screen.getByText('Create plan from selected BOM'));
  await screen.findByText('Retry the same change');
  const first=request.mock.calls.find(call=>call[2]?.method==='POST');
  expect(first[2].body.request_id).toBeTruthy(); view.unmount();
  render(<CadPurchasing versionId="bom" />);
  const retry=await screen.findByText('Retry the same change');
  request.mockResolvedValueOnce({inventory_id:'inventory',id:plan.id,replayed:true}).mockResolvedValueOnce(plan).mockResolvedValueOnce({inventory_id:'inventory',plans:[plan],next_offset:null});
  fireEvent.click(retry);
  await screen.findByText(/earlier change was already saved/);
  const posts=request.mock.calls.filter(call=>call[2]?.method==='POST');
  expect(posts[1][2].body).toEqual(first[2].body);
  await waitFor(()=>expect(sessionStorage.length).toBe(0));
});

test('foreign inventory results are not rendered', async () => {
  request.mockResolvedValue({inventory_id:'other',purchasing:true});
  render(<CadPurchasing />);fireEvent.click(screen.getByText('Open purchase plans'));
  expect((await screen.findByRole('alert')).textContent).toContain('inventory changed');
  expect(request).toHaveBeenCalledTimes(1);
});

test('vendor CSV escapes spreadsheet formulas and quotes and keeps currency separate', () => {
  const csv=purchaseCsv({...plan,lines:[{id:'a',name:'=CMD()',manufacturer:'Maker',part_number:'A"B',required:5,available:1,quantity:4,received:0,quotes:[],selected_quote:null}]});
  expect(csv).toContain('"\'=CMD()"');expect(csv).toContain('"A""B"');expect(csv).toContain('excluding tax and shipping');
});

test('receiving requires a selected stock destination and sends only this delivery quantity', async () => {
  const line={id:'line',name:'Bearing',manufacturer:'Maker',part_number:'608',required:4,available:0,quantity:4,received:1,quotes:[],selected_quote:{id:'quote',vendor:'Vendor',currency:'USD',product_url:'https://example.com',source_note:'Email',quoted_at:'2026-01-01',valid_until:'2099-01-01',availability:'in_stock',estimate:{order_quantity:4,surplus_quantity:0,subtotal:'20',unit_price:'5'}}};
  const ordered={...plan,state:'ordered',lines:[line]};
  request.mockImplementation(async (_actor,path,options) => {
    if (path==='/cad/capabilities') return {inventory_id:'inventory',purchasing:true,can_edit:true,can_approve:false};
    if (path.startsWith('/cad/purchases?')) return {inventory_id:'inventory',plans:[ordered],next_offset:null};
    if (path.startsWith('/cad/candidates')) return {inventory_id:'inventory',items:[{item_id:'stock',name:'Bearing',part_number:'608',location:'Drawer B'}]};
    if (options?.method==='POST') return {inventory_id:'inventory',id:plan.id};
    return ordered;
  });
  render(<CadPurchasing />);fireEvent.click(screen.getByText('Open purchase plans'));
  fireEvent.click(await screen.findByText('Robot / ordered',{selector:'button'}));
  fireEvent.click(await screen.findByText('Receive Bearing'));
  expect((screen.getByText('Confirm receipt and update stock') as HTMLButtonElement).disabled).toBe(true);
  fireEvent.click(screen.getByText('Find stock destination'));
  await screen.findByText('Bearing / 608 / Drawer B');
  fireEvent.change(screen.getByLabelText('Destination item and recorded location'),{target:{value:'stock'}});
  fireEvent.change(screen.getByLabelText('Quantity delivered now'),{target:{value:'2'}});
  fireEvent.click(screen.getByLabelText(/I checked the delivered part/));
  fireEvent.click(screen.getByText('Confirm receipt and update stock'));
  await screen.findByText('Purchase plan updated.');
  expect(request.mock.calls.find(call=>call[2]?.method==='POST')[2].body).toMatchObject({action:'receive',line_id:'line',item_id:'stock',quantity:2,identity_confirmed:true,expected_revision:1});
});
