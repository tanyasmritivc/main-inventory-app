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
const organizations=[{organization_id:'team',name:'Team',role:'admin'},{organization_id:'restricted',name:'Restricted',role:'member'}];
beforeEach(() => {
 jest.resetAllMocks();selectInventory(null);window.history.replaceState(null,'','/settings');
 jest.mocked(ScopedCommerce).mockImplementation(()=> <div>Connection controls</div>);
 jest.mocked(useApiSession).mockReturnValue({accountId:'actor',loading:false,error:null} as ReturnType<typeof useApiSession>);
 jest.mocked(accountRequest).mockResolvedValue({organizations});
});
test('personal connections do not change the active inventory boundary',async()=>{
 render(<SettingsConnections/>);await screen.findByRole('option',{name:'Team · organization'});
 expect(ScopedCommerce).toHaveBeenCalledWith(expect.objectContaining({accountId:'actor',scope:{scope_type:'personal'},ownerName:'Personal',embedded:true}),undefined);
 expect(activeInventory()).toBeNull();
});
test('only authorized organization owners can mount organization connections',async()=>{
 render(<SettingsConnections/>);await screen.findByRole('option',{name:'Team · organization'});
 expect(screen.queryByRole('option',{name:/Restricted/})).toBeNull();
 fireEvent.change(screen.getByLabelText('Connection owner'),{target:{value:'team'}});
 expect(ScopedCommerce).toHaveBeenLastCalledWith(expect.objectContaining({scope:{scope_type:'organization',organization_id:'team'},ownerName:'Team'}),undefined);
 expect(window.location.search).toBe('?organization=team');
});
test('an unauthorized organization URL cannot mount connection controls',async()=>{
 window.history.replaceState(null,'','/settings?organization=restricted');
 render(<SettingsConnections/>);expect((await screen.findByRole('alert')).textContent).toContain('do not have administrator access');
 expect(ScopedCommerce).not.toHaveBeenCalled();
 fireEvent.change(screen.getByLabelText('Connection owner'),{target:{value:'personal'}});
 expect(ScopedCommerce).toHaveBeenLastCalledWith(expect.objectContaining({scope:{scope_type:'personal'}}),undefined);
});
test('an account change discards late organization permissions',async()=>{
 window.history.replaceState(null,'','/settings?organization=team');let finish!:(value:unknown)=>void;
 jest.mocked(accountRequest).mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve;})).mockResolvedValue({organizations:[]});
 const view=render(<SettingsConnections/>);
 jest.mocked(useApiSession).mockReturnValue({accountId:'other',loading:false,error:null} as ReturnType<typeof useApiSession>);
 view.rerender(<SettingsConnections/>);await screen.findByRole('alert');
 await act(async()=>finish({organizations}));
 expect(ScopedCommerce).not.toHaveBeenCalled();
});
