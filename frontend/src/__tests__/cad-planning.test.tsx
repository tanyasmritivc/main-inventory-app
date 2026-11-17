/** @jest-environment jsdom */
import { fireEvent, render, screen } from '@testing-library/react';
import { CadPlanning } from '@/components/cad/cad-planning';
import { accountRequest } from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
jest.mock('@/lib/inventory-selection',()=>({activeInventory:()=>({accountId:'actor',inventory_id:'inventory'})}));
const versions=[{id:'a',project_id:'one',version:1,document:{name:'Robot A'}},{id:'b',project_id:'two',version:1,document:{name:'Robot B'}},{id:'a2',project_id:'one',version:2,document:{name:'Robot A'}}];
beforeEach(()=>jest.clearAllMocks());
test('planning sends priority order, excludes another version of the same project and never writes stock',async()=>{
 (accountRequest as jest.Mock).mockResolvedValue({inventory_id:'inventory',note:'Preview only',inventory_as_of:'2026-11-16T00:00:00Z',warnings:[],projects:[],incoming:[]});
 render(<CadPlanning versions={versions}/>);
 fireEvent.click(screen.getByRole('checkbox',{name:'Robot A / BOM 1'}));
 expect((screen.getByRole('checkbox',{name:'Robot A / BOM 2'}) as HTMLInputElement).disabled).toBe(true);
 fireEvent.click(screen.getByRole('checkbox',{name:'Robot B / BOM 1'}));fireEvent.click(screen.getByText('Move earlier'));
 fireEvent.click(screen.getByText('Compare shared stock'));await screen.findByText('Preview only');
 expect(accountRequest).toHaveBeenCalledTimes(1);
 expect(accountRequest).toHaveBeenCalledWith('actor','/cad/planning',expect.objectContaining({method:'POST',body:{version_ids:['b','a']}}));
});
test('foreign inventory result is rejected',async()=>{
 (accountRequest as jest.Mock).mockResolvedValue({inventory_id:'foreign',note:'Private'});render(<CadPlanning versions={versions}/>);
 fireEvent.click(screen.getByRole('checkbox',{name:'Robot A / BOM 1'}));fireEvent.click(screen.getByText('Compare shared stock'));
 await screen.findByRole('alert');expect(screen.queryByText('Private')).toBeNull();
});
