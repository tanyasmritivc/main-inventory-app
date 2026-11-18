/** @jest-environment jsdom */
import { fireEvent, render, screen, cleanup } from '@testing-library/react';
import { ContextChat } from '@/components/site/context-chat';
import { selectInventory, type InventorySelection } from '@/lib/inventory-selection';
const mockAssist=jest.fn();
jest.mock('@/components/site/assist-client',()=>({AssistClient:(props:unknown)=>{mockAssist(props);return <div>Assistant fixture</div>;}}));
const inventory:InventorySelection={accountId:'actor',inventory_id:'hardware',owner_user_id:'owner',team_id:null,is_default:false,name:'Hardware',can_edit:true,workspace:{workspace_id:'team',team_id:'team',role:'member',kind:'team',name:'Robotics',organization_name:'Robotics Club',organization_id:'org-a'}};
afterEach(()=>{cleanup();selectInventory(null);mockAssist.mockClear();});
test('Space Ask opens the selected organization, not just the entry inventory',()=>{
 selectInventory(inventory);render(<ContextChat inventory={inventory}/>);
 fireEvent.click(screen.getByRole('button',{name:'Ask FindEZ about Robotics Club'}));
 expect(screen.getByText('Across accessible Spaces in Robotics Club')).toBeTruthy();
 expect(mockAssist).toHaveBeenLastCalledWith(expect.objectContaining({worldId:'org-a',contextual:true}));
});
test('switching organization retires the prior panel and uses the new organization',()=>{
 selectInventory(inventory);const view=render(<ContextChat key="a" inventory={inventory}/>);
 fireEvent.click(screen.getByRole('button',{name:/Ask FindEZ about/}));
 const other={...inventory,inventory_id:'other',workspace:{...inventory.workspace,organization_id:'org-b',organization_name:'Other Team'}};
 selectInventory(other);view.rerender(<ContextChat key="b" inventory={other}/>);
 expect(screen.queryByText('Assistant fixture')).toBeNull();
 fireEvent.click(screen.getByRole('button',{name:'Ask FindEZ about Other Team'}));
 expect(mockAssist).toHaveBeenLastCalledWith(expect.objectContaining({worldId:'org-b'}));
});
test('Personal never falls back to a remembered team organization',()=>{
 const personal={...inventory,workspace:{...inventory.workspace,world_key:'personal',organization_id:'private-org',organization_name:'Personal'}};
 selectInventory(personal);render(<ContextChat inventory={personal}/>);
 fireEvent.click(screen.getByRole('button',{name:'Ask FindEZ about Personal'}));
 expect(mockAssist).toHaveBeenLastCalledWith(expect.objectContaining({worldId:'personal'}));
});
test('legacy selection with no organization stays scoped; unavailable or stale selection renders nothing',()=>{
 const legacy={...inventory,workspace:{...inventory.workspace,organization_id:null,organization_name:undefined}};
 selectInventory(legacy);const view=render(<ContextChat inventory={legacy}/>);
 fireEvent.click(screen.getByRole('button',{name:'Ask FindEZ about Hardware'}));
 expect(mockAssist).toHaveBeenLastCalledWith(expect.objectContaining({worldId:undefined}));
 selectInventory(null);view.rerender(<ContextChat inventory={legacy}/>);
 expect(screen.queryByText('Assistant fixture')).toBeNull();
 const denied={...inventory,can_open:false};selectInventory(denied);view.rerender(<ContextChat inventory={denied}/>);
 expect(screen.queryByRole('button')).toBeNull();
});
