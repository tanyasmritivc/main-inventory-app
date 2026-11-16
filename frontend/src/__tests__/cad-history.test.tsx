/** @jest-environment jsdom */
import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { CadHistory } from '@/components/cad/cad-history';
import { accountRequest } from '@/lib/account-request';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/inventory-selection', () => ({ activeInventory: () => ({ accountId:'actor', inventory_id:'inventory' }) }));
jest.mock('@/components/cad/cad-results', () => ({ CadResults: () => <p>Saved comparison</p> }));
beforeEach(() => jest.clearAllMocks());
test('history loads explicitly, remains inventory scoped and labels old stock', async () => {
 (accountRequest as jest.Mock).mockResolvedValueOnce({inventory_id:'inventory',versions:[{id:'v',project_id:'p',version:2,created_at:'2026-11-16T00:00:00Z',document:{name:'Robot'}}],next_offset:null})
 .mockResolvedValueOnce({inventory_id:'inventory',version:2,created_at:'2026-11-16T00:00:00Z',comparison:{}});
 render(<CadHistory />); expect(accountRequest).not.toHaveBeenCalled();
 fireEvent.click(screen.getByText('Load saved versions'));
 fireEvent.click(await screen.findByRole('button',{name:/Robot \/ BOM 2/}));
 expect(await screen.findByText(/This is not current stock availability/)).not.toBeNull();
 expect(accountRequest).toHaveBeenLastCalledWith('actor','/cad/versions/v',expect.any(Object));
});
test('a response for another inventory is rejected', async () => {
 (accountRequest as jest.Mock).mockResolvedValue({inventory_id:'other',versions:[{document:{name:'Private robot'}}]});
 render(<CadHistory />);fireEvent.click(screen.getByText('Load saved versions'));
 expect((await screen.findByRole('alert')).textContent).toContain('inventory changed');
 expect(screen.queryByText('Private robot')).toBeNull();
});
