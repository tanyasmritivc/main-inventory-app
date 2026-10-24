/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AssistClient } from '@/components/site/assist-client';
import { accountRequest } from '@/lib/account-request';

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
