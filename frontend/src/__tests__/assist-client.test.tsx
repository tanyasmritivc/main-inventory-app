/** @jest-environment jsdom */
import { fireEvent, render as rtlRender, screen, waitFor } from '@testing-library/react';
import { AssistClient } from '@/components/site/assist-client';
import { accountRequest } from '@/lib/account-request';

jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'fixture-account', error: null }) }));
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
import {AppDialogProvider} from '@/components/site/app-dialog-provider';
const render = (ui: React.ReactNode) => rtlRender(<AppDialogProvider>{ui}</AppDialogProvider>);
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

test('reopening restores the selected saved conversation and draft', async()=>{
  localStorage.setItem('findez-active-chat:fixture-account','fixture-chat');
  localStorage.setItem('findez-ask-draft:fixture-account','My unsent question');
  const view=render(<AssistClient/>);
  expect(await screen.findByText('The recorded location is Workbench.')).toBeTruthy();
  expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).value).toBe('My unsent question');
  view.unmount();
  render(<AssistClient/>);
  expect(await screen.findByText('The recorded location is Workbench.')).toBeTruthy();
});

test('New conversation clears remembered selection, so reopening stays new',async()=>{
  localStorage.setItem('findez-active-chat:fixture-account','fixture-chat');
  const view=render(<AssistClient/>);
  await screen.findByText('The recorded location is Workbench.');
  fireEvent.click(screen.getByRole('button',{name:'New conversation'}));
  expect(localStorage.getItem('findez-active-chat:fixture-account')).toBeNull();
  view.unmount();
  render(<AssistClient/>);
  await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/conversations'));
  expect(screen.queryByText('The recorded location is Workbench.')).toBeNull();
});

test('deleted and foreign-account remembered chats are not restored',async()=>{
  localStorage.setItem('findez-active-chat:fixture-account','deleted-chat');
  localStorage.setItem('findez-active-chat:other-account','fixture-chat');
  render(<AssistClient/>);
  await waitFor(()=>expect(localStorage.getItem('findez-active-chat:fixture-account')).toBeNull());
  expect(accountRequest).not.toHaveBeenCalledWith('fixture-account','/conversations/deleted-chat');
  expect(accountRequest).not.toHaveBeenCalledWith('fixture-account','/conversations/fixture-chat');
});

test('a fresh prompt does not revive the previous conversation',async()=>{
  localStorage.setItem('findez-active-chat:fixture-account','fixture-chat');
  render(<AssistClient initialQuery="Where is the drill?"/>);
  await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/conversations'));
  expect(screen.queryByText('The recorded location is Workbench.')).toBeNull();
});

 test('history Delete releases its modal so real confirmation accepts the click',async()=>{
   jest.mocked(accountRequest).mockImplementation(async (_account,path,options)=>{
     if(options?.method==='DELETE') return {deleted:true} as never;
     if(path==='/conversations') return [{id:'fixture-chat',title:'Workshop tools'}] as never;
     return {} as never;
   });
   render(<AppDialogProvider><AssistClient/></AppDialogProvider>);
   fireEvent.click(await screen.findByRole('button',{name:'History'}));
   const button = await screen.findByRole('button',{name:'Delete Workshop tools'});
   fireEvent.click(button);
   expect(screen.queryByRole('dialog',{name:'History'})).toBeNull();
   fireEvent.click(await screen.findByRole('button',{name:'Delete'}));
   await waitFor(()=>expect(accountRequest).toHaveBeenCalledWith('fixture-account','/conversations/fixture-chat',{method:'DELETE'}));
 });
