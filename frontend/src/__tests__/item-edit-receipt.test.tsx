/** @jest-environment jsdom */
import { mockBrowserTopLayer } from './mock-browser-top-layer';
mockBrowserTopLayer();
import { render, screen, within, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HomeInventoryClient } from '@/components/site/home-inventory-client';
import * as api from '@/lib/api';

jest.mock('@/lib/session', () => ({ getAccessToken: async () => 'token' }));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'actor' }) }));
jest.mock('next/navigation', () => ({ useRouter: () => ({ push: jest.fn() }) }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: async () => true, promptValue: async () => null }) }));
jest.mock('@/lib/api', () => ({ ...jest.requireActual('@/lib/api'), searchItems: jest.fn(), getSpaces: jest.fn(), getActiveCheckouts: jest.fn(), getReviewItems: jest.fn(), getMyShares: jest.fn(), getJoinedShares: jest.fn(), updateItem: jest.fn() }));
jest.mock('@/components/site/item-details', () => ({ ItemDetails: () => <p>Item details fixture</p> }));
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
  await userEvent.click(screen.getByRole('button', { name: 'Edit item' }));
  const dialog = screen.getByRole('dialog', { name: 'Edit Item' });
  await userEvent.type(within(dialog).getByLabelText('Part number'), '001-QA');
  jest.mocked(api.updateItem).mockRejectedValueOnce(new Error('The save is unavailable.'));
  await userEvent.click(within(dialog).getByRole('button', { name: /^Save$/ }));
  await waitFor(() => expect(within(dialog).getByRole('alert').textContent).toBeTruthy());
  expect(within(dialog).getByLabelText('Part number')).toHaveProperty('value', '001-QA');
  jest.mocked(api.updateItem).mockResolvedValueOnce({ item: { ...item, part_number: '001-QA' } });
  await userEvent.click(within(dialog).getByRole('button', { name: /^Save$/ }));
  await waitFor(() => expect(screen.queryByRole('dialog', { name: 'Edit Item' })).toBeNull());
  expect(await screen.findByRole('button', { name: '001-QA' })).toBeTruthy();
});
