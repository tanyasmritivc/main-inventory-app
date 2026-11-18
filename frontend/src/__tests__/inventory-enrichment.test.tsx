/** @jest-environment jsdom */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { InventoryEnrichmentClient } from '@/components/site/inventory-enrichment-client';
import { intelligenceRequest, configuredLowStock, type EnrichmentReview } from '@/lib/inventory-intelligence';
import { ItemClassification } from '@/components/site/item-classification';
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'account-a', loading: false }) }));
jest.mock('@/components/site/inventory-link', () => ({ __esModule: true, default: (props: React.AnchorHTMLAttributes<HTMLAnchorElement>) => <a {...props} /> }));
jest.mock('@/lib/inventory-intelligence', () => ({
  ...jest.requireActual('@/lib/inventory-intelligence'), intelligenceRequest: jest.fn(), suggestionPhoto: jest.fn(),
}));
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn(), accountToken: jest.fn() }));
const request = jest.mocked(intelligenceRequest);
const fixture = (edit = true): EnrichmentReview => ({
  can_edit: edit, next_offset: null, settings: { timezone: 'America/Los_Angeles', images_enabled: true },
  items: [{ id: 'classification-1', item_id: 'item-1', name: 'iPhone', kind: 'classification', status: 'ready', due_at: '2026-11-16T10:00:00Z', has_preview: false, result: { role: 'personal_asset', confidence: 'low', reason: 'Confirm how you use this phone.' } },
    { id: 'image-1', item_id: 'item-2', name: 'M4 screw', kind: 'image', status: 'no_match', due_at: '2026-11-16T10:00:00Z', has_preview: false, result: { reason: 'Add an exact part number.' } }],
});
beforeEach(() => { request.mockReset(); request.mockResolvedValue(fixture()); });

test('ready classification, uncertain photo and schedule have distinct actions', async () => {
  render(<InventoryEnrichmentClient />);
  await screen.findByText('Personal asset');
  expect(screen.getByText('low confidence')).toBeTruthy();
  expect(screen.getByRole('button', { name: 'Retry' })).toBeTruthy();
  expect(screen.getByRole('link', { name: 'Upload my photo' }).getAttribute('href')).toBe('/inventory?item=item-2');
  expect(screen.getByRole('button', { name: 'Approve' })).toBeTruthy();
  expect(screen.getByText(/Stock alert settings|Classification does not enable alerts/)).toBeTruthy();
});

test('bulk approval submits only selected ready IDs and shows the server receipt', async () => {
  request.mockImplementation(async (path) => path === '/decisions' ? { results: [{ status: 'approved' }] } : fixture());
  render(<InventoryEnrichmentClient />);
  fireEvent.click(await screen.findByLabelText('Select ready on this page'));
  fireEvent.click(screen.getByRole('button', { name: 'Approve selected (1)' }));
  await screen.findByText('1 suggestion approved.');
  expect(request).toHaveBeenCalledWith('/decisions', { method: 'POST', body: { ids: ['classification-1'], decision: 'approve' } });
});

test('viewers can inspect but cannot approve, retry or change settings', async () => {
  request.mockResolvedValue(fixture(false));
  render(<InventoryEnrichmentClient />);
  await screen.findByText(/View only/);
  expect(screen.queryByRole('button', { name: 'Approve' })).toBeNull();
  expect(screen.queryByRole('button', { name: 'Retry' })).toBeNull();
  expect((screen.getByLabelText('Suggest photos for new imports') as HTMLInputElement).disabled).toBe(true);
});

test('classification override writes the role without quantity or reorder changes', async () => {
  request.mockResolvedValue({ inventory_role: 'equipment' });
  const changed = jest.fn();
  render(<ItemClassification itemId="phone" role="unclassified" canEdit onChanged={changed} />);
  fireEvent.change(screen.getByLabelText('Inventory classification'), { target: { value: 'equipment' } });
  fireEvent.click(screen.getByRole('button', { name: 'Save classification' }));
  await waitFor(() => expect(changed).toHaveBeenCalledWith('equipment'));
  expect(request).toHaveBeenCalledWith('/items/phone/classification', { method: 'PUT', body: { role: 'equipment' } });
});

test('quantity alone never activates a home low-stock warning', () => {
  expect(configuredLowStock({ quantity: 1 })).toBe(false);
  expect(configuredLowStock({ quantity: 0, reorder_enabled: false, reorder_threshold: 5 })).toBe(false);
  expect(configuredLowStock({ quantity: 1, reorder_enabled: true, reorder_threshold: 2 })).toBe(true);
  expect(configuredLowStock({ quantity: 1, reorder_enabled: true })).toBe(false);
});
