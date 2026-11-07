/** @jest-environment jsdom */
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ItemCheckout, ItemDocuments, ItemThreshold } from '@/components/site/item-info-sections';
import { accountRequest } from '@/lib/account-request';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'actor' }) }));
const request = jest.mocked(accountRequest);
beforeEach(() => jest.clearAllMocks());
test('reads an existing threshold without changing it and confirms a saved zero', async () => {
 request.mockResolvedValueOnce({rules:{item:5}}).mockResolvedValueOnce({rules:{item:0}});
 render(<ItemThreshold itemId="item" canEdit />);
 const input = await screen.findByDisplayValue('5');
 expect(request).toHaveBeenCalledWith('actor','/notifications/stock-rules',{method:'POST',body:{rules:[{item_id:'item',threshold:null}],import_only:true}});
 await userEvent.clear(input); await userEvent.type(input,'0'); await userEvent.click(screen.getByRole('button',{name:'Save threshold'}));
 await waitFor(()=>expect(screen.queryByRole('button',{name:'Save threshold'})).toBeNull());
 expect(request).toHaveBeenLastCalledWith('actor','/notifications/stock-rules',{method:'POST',body:{rules:[{item_id:'item',threshold:0}],import_only:false}});
});
test('an unconfirmed threshold keeps the entered value and save action', async () => {
 request.mockResolvedValueOnce({rules:{}}).mockResolvedValueOnce({rules:{item:7}});
 render(<ItemThreshold itemId="item" canEdit />);
 const input=screen.getByLabelText('Alert me at or below'); await waitFor(()=>expect((input as HTMLInputElement).disabled).toBe(false));
 await userEvent.type(input,'3'); await userEvent.click(screen.getByRole('button',{name:'Save threshold'}));
 expect(await screen.findByRole('alert')).toBeTruthy(); expect(screen.getByDisplayValue('3')).toBeTruthy(); expect(screen.getByRole('button',{name:'Save threshold'})).toBeTruthy();
});
test('checkout uses the actual checkout_id and is_active contract for returning an item', async () => {
 const row={checkout_id:'receipt',item_id:'item',checked_out_by:'Sam',is_active:true};
 request.mockResolvedValueOnce({checkouts:[row]}).mockResolvedValueOnce({returned:true}).mockResolvedValueOnce({checkouts:[{...row,is_active:false,returned_at:'2026-11-07'}]});
 render(<ItemCheckout itemId="item" canEdit />);
 expect(await screen.findByText('Checked out to Sam')).toBeTruthy(); await userEvent.click(screen.getByRole('button',{name:'Return item'}));
 expect(await screen.findByText('Available - not checked out')).toBeTruthy();
 expect(request).toHaveBeenCalledWith('actor','/checkouts/return',{method:'POST',body:{checkout_id:'receipt'}});
});
test('checkout creation accepts the existing flat receipt and refreshes status', async () => {
 const row={checkout_id:'receipt',item_id:'item',checked_out_by:'Sam',is_active:true};
 request.mockResolvedValueOnce({checkouts:[]}).mockResolvedValueOnce(row).mockResolvedValueOnce({checkouts:[row]});
 render(<ItemCheckout itemId="item" canEdit />); await screen.findByText('Available - not checked out');
 await userEvent.click(screen.getByRole('button',{name:'Check Out'})); await userEvent.type(screen.getByLabelText('Checked out to'),'Sam');
 await userEvent.click(screen.getAllByRole('button',{name:'Check Out'})[1]); expect(await screen.findByText('Checked out to Sam')).toBeTruthy();
});
test('document failures do not masquerade as an empty collection and viewers cannot upload', async () => {
 request.mockRejectedValueOnce(new Error('Could not load documents.'));
 render(<ItemDocuments itemId="item" canEdit={false}/>);
 expect(await screen.findByRole('alert')).toBeTruthy(); expect(screen.queryByText('No documents yet')).toBeNull(); expect(screen.queryByRole('button',{name:'Add'})).toBeNull();
});
