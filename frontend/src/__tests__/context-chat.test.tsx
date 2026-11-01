/** @jest-environment jsdom */
import { fireEvent, render, screen } from '@testing-library/react';
import { ContextChat, hasContextChat } from '@/components/site/context-chat';
import { activeInventory, selectInventory, type InventorySelection } from '@/lib/inventory-selection';

jest.mock('@/components/site/assist-client',()=>({AssistClient:({worldId,title}:{worldId?:string;title?:string})=><div data-testid="scoped-chat" data-world={worldId || ''} data-inventory={activeInventory()?.inventory_id}>{title}</div>}));
const inventory:InventorySelection={accountId:'account',inventory_id:'hardware',name:'Hardware',owner_user_id:'account',team_id:null,is_default:false,can_edit:true,workspace:{workspace_id:'personal',name:'Personal',kind:'personal',team_id:null,role:'owner'}};
afterEach(()=>selectInventory(null));

test('contextual chat is available only on inventory work pages',()=>{
 for(const path of ['/inventory','/spaces/a','/documents','/restock','/checkout','/review','/project-kits/a']) expect(hasContextChat(path)).toBe(true);
 for(const path of ['/worlds/personal','/settings','/inventory-access','/login','/docs/api']) expect(hasContextChat(path)).toBe(false);
});

test('floating chat keeps the current inventory and never supplies organization scope',()=>{
 selectInventory(inventory);
 render(<ContextChat inventory={inventory}/>);
 expect(screen.queryByTestId('scoped-chat')).toBeNull();
 fireEvent.click(screen.getByRole('button',{name:'Ask FindEZ about Hardware'}));
 expect(screen.getByRole('dialog',{name:'Ask FindEZ'})).toBeTruthy();
 expect(screen.getByText('Only in Hardware')).toBeTruthy();
 expect(screen.getByTestId('scoped-chat').getAttribute('data-inventory')).toBe('hardware');
 expect(screen.getByTestId('scoped-chat').getAttribute('data-world')).toBe('');
 fireEvent.click(screen.getByRole('button',{name:'Close contextual chat'}));
 expect(screen.queryByTestId('scoped-chat')).toBeNull();
});

test('stale or inaccessible inventory cannot open a fallback chat',()=>{
 selectInventory({...inventory,inventory_id:'other'});
 const view=render(<ContextChat inventory={inventory}/>);
 expect(view.container.innerHTML).toBe('');
 const revoked={...inventory,can_open:false};selectInventory(revoked);
 view.rerender(<ContextChat inventory={revoked}/>);
 expect(view.container.innerHTML).toBe('');
});
