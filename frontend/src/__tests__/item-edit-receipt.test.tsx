/** @jest-environment jsdom */
import { mockBrowserTopLayer } from './mock-browser-top-layer';
mockBrowserTopLayer();
import { render, screen, within, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HomeInventoryClient } from '@/components/site/home-inventory-client';
import { accountRequest } from '@/lib/account-request';
import * as api from '@/lib/api';

jest.mock('@/lib/session', () => ({ getAccessToken: async () => 'token' }));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'actor' }) }));
jest.mock('next/navigation', () => ({ useRouter: () => ({ push: jest.fn() }) }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: async () => true, promptValue: async () => null }) }));
jest.mock('@/lib/api', () => ({ ...jest.requireActual('@/lib/api'), searchItems: jest.fn(), getSpaces: jest.fn(), getActiveCheckouts: jest.fn(), getReviewItems: jest.fn(), getMyShares: jest.fn(), getJoinedShares: jest.fn(), updateItem: jest.fn() }));
jest.mock('@/lib/account-request', () => ({accountRequest:jest.fn()}));
jest.mock('@/components/site/item-photo-gallery',()=>({ItemPhotoGallery:()=>null}));
const item = { item_id: 'qa-item', name: 'Washer', category: 'Hardware', quantity: 7, location: 'Shelf', space_id: 's', created_at: '2026-10-19' };
beforeEach(() => {
  jest.clearAllMocks(); localStorage.clear();
  jest.mocked(api.searchItems).mockResolvedValue({ items: [item], parsed: {} });
  jest.mocked(api.getSpaces).mockResolvedValue([{ id: 's', name: 'Shelf', created_at: null }]);
  jest.mocked(api.getActiveCheckouts).mockResolvedValue({ checkouts: [] });
  jest.mocked(api.getReviewItems).mockResolvedValue({ items: [], pending_count: 0 } as never);
  jest.mocked(api.getMyShares).mockResolvedValue({ shares: [] });
  jest.mocked(api.getJoinedShares).mockResolvedValue({ shares: [] });
});
test('failed edits keep the labelled form and draft open until a confirmed save', async () => {
  render(<HomeInventoryClient mode="inventory" />);
  await userEvent.click(await screen.findByRole('button', { name: 'Washer' }));
  await userEvent.click(screen.getByRole('button', { name: 'Edit Part number' }));
  const dialog = screen.getByRole('dialog', { name: 'Item details' });
  await userEvent.type(within(dialog).getByLabelText('Part number'), '001-QA');
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error('The save is unavailable.'));
  await userEvent.click(within(dialog).getByRole('button', { name: /^Save$/ }));
  await waitFor(() => expect(within(dialog).getByRole('alert').textContent).toBeTruthy());
  expect(within(dialog).getByLabelText('Part number')).toHaveProperty('value', '001-QA');
  jest.mocked(accountRequest).mockResolvedValueOnce({ item: { ...item, part_number: '001-QA' } });
  await userEvent.click(within(dialog).getByRole('button', { name: /^Save$/ }));
  await waitFor(() => expect(within(dialog).queryByLabelText('Part number')).toBeNull());
  expect(within(dialog).getByRole('button', {name:'Edit Part number'}).textContent).toBe('001-QA');
});
test('Space part-number search is immediate and clearing restores the complete list', async () => {
  jest.mocked(api.searchItems).mockResolvedValue({items:[{...item,part_number:'QA-001'}, {...item,item_id:'qa-other',name:'Bolt',part_number:'QA-002'}],parsed:{}});
  render(<HomeInventoryClient mode="inventory" locationFilter="Shelf" />);
  await screen.findByText('QA-001');
  const search=screen.getByPlaceholderText('Search items…');
  await userEvent.type(search,'QA-002');
  expect(screen.queryByText('QA-001')).toBeNull();expect(screen.getByText('QA-002')).toBeTruthy();
  await userEvent.clear(search);expect(screen.getByText('QA-001')).toBeTruthy();expect(screen.getByText('QA-002')).toBeTruthy();
  expect(api.searchItems).toHaveBeenCalledTimes(1);
});

test('category selector filters and clears without a wall of category buttons', async () => {
 jest.mocked(api.searchItems).mockResolvedValue({items:[item,{...item,item_id:'second',name:'Cable',category:'Electronics'}],parsed:{}});
 render(<HomeInventoryClient mode="inventory" />);
 await screen.findByRole('button',{name:'Washer'});
 await userEvent.selectOptions(screen.getByRole('combobox',{name:'Category'}),'Electronics');
 expect(screen.queryByRole('button',{name:'Washer'})).toBeNull();
 expect(screen.getByRole('button',{name:'Cable'})).toBeTruthy();
 await userEvent.click(screen.getByRole('button',{name:'Clear filter'}));
 expect(screen.getByRole('button',{name:'Washer'})).toBeTruthy();
});


test('inline edits display the server-normalized category from the saved receipt', async () => {
  render(<HomeInventoryClient mode="inventory" />);
  await userEvent.click(await screen.findByRole('button', {name: 'Washer'}));
  await userEvent.click(screen.getByRole('button', {name: 'Edit Category'}));
  const dialog = screen.getByRole('dialog', {name: 'Item details'});
  await userEvent.clear(within(dialog).getByLabelText('Category'));
  await userEvent.type(within(dialog).getByLabelText('Category'), 'fasteners');
  jest.mocked(accountRequest).mockResolvedValueOnce({item: {...item, category:'Hardware'}});
  await userEvent.click(within(dialog).getByRole('button', {name:/^Save$/}));
  await waitFor(() => expect(within(dialog).queryByLabelText('Category')).toBeNull());
  expect(within(dialog).getByRole('button', {name:'Edit Category'}).textContent).toBe('Hardware');
});
