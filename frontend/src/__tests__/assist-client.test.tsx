/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AssistClient } from '@/components/site/assist-client';
import { accountRequest } from '@/lib/account-request';
import { selectInventory, type InventorySelection } from '@/lib/inventory-selection';
afterEach(() => selectInventory(null));

jest.mock('next/navigation',()=>({useRouter:()=>({push:jest.fn()})}));
jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'fixture-account', error: null }) }));
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: jest.fn() }) }));
jest.mock('@/lib/ask-stream', () => ({ askQuestion: jest.fn() }));

beforeEach(() => {
  jest.clearAllMocks();
  localStorage.clear();
  jest.mocked(accountRequest).mockImplementation(async (_account, path) => {
    if (path === '/conversations') return [{ id: 'fixture-chat', title: 'Workshop tools' }] as never;
    if (path === '/conversations/fixture-chat') return { messages: [{ id: 'question', role: 'user', content: 'Where are my tools?', created_at: '2026-10-15T00:00:00Z' }, { id: 'answer', role: 'assistant', content: 'The recorded location is Workbench.', created_at: '2026-10-15T00:00:00Z' }] } as never;
    throw new Error(`Unexpected fixture request: ${path}`);
  });
});

test('history stays accessible without displacing the centered composer, and opening it retains the draft', async () => {
  render(<AssistClient />);
  await waitFor(() => expect(accountRequest).toHaveBeenCalledWith('fixture-account', '/conversations'));
  expect(screen.queryByRole('dialog')).toBeNull();
  fireEvent.change(screen.getByRole('textbox', { name: 'Your question' }), { target: { value: 'Where is my drill?' } });
  fireEvent.click(screen.getByRole('button', { name: 'History' }));
  expect(await screen.findByRole('dialog', { name: 'History' })).toBeTruthy();
  fireEvent.click(screen.getByRole('button', { name: 'Workshop tools' }));
  expect(await screen.findByText('The recorded location is Workbench.')).toBeTruthy();
  expect(screen.queryByRole('dialog')).toBeNull();
  expect((screen.getByRole('textbox', { name: 'Your question' }) as HTMLTextAreaElement).value).toBe('Where is my drill?');
  fireEvent.click(screen.getByRole('button', { name: 'New conversation' }));
  expect(screen.queryByText('The recorded location is Workbench.')).toBeNull();
  expect((screen.getByRole('textbox', { name: 'Your question' }) as HTMLTextAreaElement).value).toBe('');
});


test('organization history and drafts are isolated, and retry retains the durable request identity', async () => {
 const {askQuestion}=await import('@/lib/ask-stream');
 jest.mocked(accountRequest).mockResolvedValue([]);
 jest.mocked(askQuestion).mockRejectedValue(new Error('Connection interrupted'));
 const view=render(<AssistClient worldId="org-a"/>);
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/worlds/org-a/conversations'));
 fireEvent.change(screen.getByRole('textbox',{name:'Your question'}),{target:{value:'Add five bolts'}});
 fireEvent.click(screen.getByRole('button',{name:'Ask'}));await screen.findByRole('alert');
 const first=jest.mocked(askQuestion).mock.calls.at(-1)![0];
 fireEvent.click(screen.getByRole('button',{name:'Ask'}));await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(2));
 expect(jest.mocked(askQuestion).mock.calls[1][0].requestId).toBe(first.requestId);
 expect(first.worldId).toBe('org-a');expect(first.requestId).toBeTruthy();
 view.rerender(<AssistClient worldId="org-b"/>);
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/worlds/org-b/conversations'));
 expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('');

 view.rerender(<AssistClient worldId="org-a"/>);
 await waitFor(()=>expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('Add five bolts'));
});

test('spreadsheet uploads create reviewable drafts without calling the chat model and stay in their originating chat', async () => {
 const {askQuestion}=await import('@/lib/ask-stream');
 let finish!:(r:unknown)=>void;
 const capture={id:'11111111-1111-4111-8111-111111111111',revision:1,status:'draft',source_kind:'spreadsheet',items:[{index:0,selected:true,item:{name:'M3 screws',category:'Hardware',quantity:20}}]};
 jest.mocked(accountRequest).mockImplementation(async(_actor,path)=>{
  if(path.endsWith('/captures/spreadsheet'))return new Promise(resolve=>{finish=resolve;}) as never;
  if(path.endsWith('/spaces'))return {inventories:[]} as never;
  return [] as never;
 });
 const view=render(<AssistClient worldId="org-a"/>);
 await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/worlds/org-a/conversations'));
 fireEvent.change(view.container.querySelector('input[accept=".csv,.xlsx"]')!,{target:{files:[new File(['name,quantity\nM3 screws,20'],'items.csv',{type:'text/csv'})]}});
 await waitFor(()=>expect(finish).toBeDefined());
 fireEvent(window,new Event('findez-new-world-chat'));
 await import('@testing-library/react').then(({act})=>act(async()=>finish({conversation_id:'chat',capture})));
 await screen.findByRole('region',{name:'Extraction draft'});
 expect(screen.getByRole('textbox',{name:'Name for row 1'})).toHaveProperty('value','M3 screws');
 expect(screen.getByRole('button',{name:'Add to chat'})).toHaveProperty('disabled',false);
 expect(askQuestion).not.toHaveBeenCalled();
 expect(screen.getByRole('button',{name:'Confirm and save'})).toHaveProperty('disabled',true);
});

test('received deltas are visible before done and reset removes superseded text', async () => {
 const {askQuestion}=await import('@/lib/ask-stream');
 jest.mocked(accountRequest).mockResolvedValue([]);
 let callbacks!: Parameters<typeof askQuestion>[0];
 let finish!: () => void;
 jest.mocked(askQuestion).mockImplementation(options => { callbacks=options; return new Promise<void>(resolve => {finish=resolve;}); });
 const view=render(<AssistClient worldId="org-a"/>);
 fireEvent.change(screen.getByRole('textbox',{name:'Your question'}),{target:{value:'Where are the bolts?'}});
 fireEvent.click(screen.getByRole('button',{name:'Ask'}));
 const {act}=await import('@testing-library/react');
 await act(async()=>callbacks.onDelta('Bolts are on shelf 2.'));
 expect(view.container.textContent).toContain('Bolts are on shelf 2.');
 expect(screen.getByRole('button',{name:'Stop'})).toBeTruthy();
 await act(async()=>callbacks.onReset?.());
 expect(view.container.textContent).not.toContain('Bolts are on shelf 2.');
 await act(async()=>callbacks.onDelta('The current location is shelf 3.'));
 expect(view.container.textContent).toContain('The current location is shelf 3.');
 await act(async()=>{callbacks.onDone({conversationId:'saved',content:'The current location is shelf 3.'});finish();});
 expect(view.container.textContent).toContain('The current location is shelf 3.');
});


test('inventory drafts are separate from each other and organization chat', async () => {
 jest.mocked(accountRequest).mockResolvedValue([]);
 const inventory: InventorySelection = {accountId:'fixture-account',inventory_id:'hardware',name:'Hardware',owner_user_id:'fixture-account',team_id:null,is_default:false,can_edit:true,workspace:{workspace_id:'personal',name:'Personal',kind:'personal',team_id:null,role:'owner'}};
 selectInventory(inventory);
 const view = render(<AssistClient contextual/>);
 fireEvent.change(screen.getByRole('textbox',{name:'Your question'}),{target:{value:'Hardware draft'}});
 selectInventory({...inventory,inventory_id:'bathroom'});
 view.rerender(<AssistClient contextual/>);
 expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('');
 view.rerender(<AssistClient worldId="personal"/>);
 expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('');
 selectInventory(inventory);
 view.rerender(<AssistClient contextual/>);
 await waitFor(()=>expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('Hardware draft'));
});


test('interrupted streaming retains received text and marks it incomplete', async () => {
 const {askQuestion}=await import('@/lib/ask-stream');
 jest.mocked(accountRequest).mockResolvedValue([]);
 jest.mocked(askQuestion).mockImplementation(async options => {
   options.onDelta('The charger is on shelf 2.');
   throw new Error('Connection interrupted');
 });
 const view=render(<AssistClient worldId="org-a"/>);
 fireEvent.change(screen.getByRole('textbox',{name:'Your question'}),{target:{value:'Where is the charger?'}});
 fireEvent.click(screen.getByRole('button',{name:'Ask'}));
 await screen.findByRole('alert');
 expect(view.container.textContent).toContain('The charger is on shelf 2.');
 expect(view.container.textContent).toContain('This answer was interrupted.');
});
