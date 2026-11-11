/** @jest-environment jsdom */
import { act, fireEvent, render, screen } from '@testing-library/react';
import { SettingsConnections } from '@/components/site/settings-connections';
import { ScopedCommerce } from '@/components/site/commerce-client';
import { accountRequest } from '@/lib/account-request';
import { useApiSession } from '@/lib/use-api-session';
import { activeInventory, selectInventory } from '@/lib/inventory-selection';
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: jest.fn() }));
jest.mock('@/components/site/commerce-client', () => ({ ScopedCommerce: jest.fn(() => <div>Connection controls</div>) }));
beforeEach(() => {
  jest.clearAllMocks(); selectInventory(null); window.history.replaceState(null, '', '/settings/connections');
  jest.mocked(useApiSession).mockReturnValue({accountId:'actor',loading:false,error:null} as ReturnType<typeof useApiSession>);
  jest.mocked(accountRequest).mockResolvedValue({organizations:[{organization_id:'org',name:'Robotics',role:'admin'},{organization_id:'member',name:'Member only',role:'member'}]});
});
test('personal imports need no inventory and do not change active inventory', async () => {
  render(<SettingsConnections />); await screen.findByText('Robotics · organization');
  expect(ScopedCommerce).toHaveBeenLastCalledWith(expect.objectContaining({accountId:'actor',scope:{scope_type:'personal'}}),undefined);
  expect(accountRequest).toHaveBeenCalledWith('actor','/organizations');
  expect(accountRequest).toHaveBeenCalledTimes(1); expect(activeInventory()).toBeNull();
  expect(screen.queryByLabelText('Inventory')).toBeNull(); expect(screen.queryByText('Member only · organization')).toBeNull();
});
test('organization choice passes explicit owner and keeps personal data separate', async () => {
  render(<SettingsConnections />); await screen.findByText('Robotics · organization');
  fireEvent.change(screen.getByLabelText('Connection owner'),{target:{value:'org'}});
  expect(ScopedCommerce).toHaveBeenLastCalledWith(expect.objectContaining({scope:{scope_type:'organization',organization_id:'org'},ownerName:'Robotics'}),undefined);
  expect(window.location.search).toBe('?organization=org');
  fireEvent.change(screen.getByLabelText('Connection owner'),{target:{value:'personal'}});
  expect(window.location.search).toBe('');
});
test('organization deep link waits for authorization and never opens personal records', async () => {
  window.history.replaceState(null,'','/settings/connections?organization=unknown');
  let resolve!: (value: unknown)=>void;
  jest.mocked(accountRequest).mockImplementationOnce(()=>new Promise(done=>{resolve=done;}));
  render(<SettingsConnections />); expect(ScopedCommerce).not.toHaveBeenCalled();
  await act(async()=>resolve({organizations:[]}));
  expect((await screen.findByRole('alert')).textContent).toContain('administrator access');
  expect(ScopedCommerce).not.toHaveBeenCalled();
});
test('organization failure does not block personal import and instructions remain available', async () => {
  jest.mocked(accountRequest).mockRejectedValueOnce(new Error('Unavailable'));
  render(<SettingsConnections />); await screen.findByRole('alert');
  expect(screen.getByText('Connection controls')).toBeTruthy();
  expect(screen.getByText('How to use Connections')).toBeTruthy();
  expect(screen.getByText(/Imported purchases do not automatically create/)).toBeTruthy();
});
