/** @jest-environment jsdom */
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AssistClient } from '@/components/site/assist-client';
import { accountRequest } from '@/lib/account-request';

jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ accountId: 'fixture-account', error: null }) }));
jest.mock('@/lib/account-request', () => ({ accountRequest: jest.fn() }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: jest.fn() }) }));
jest.mock('@/lib/ask-stream', () => ({ askQuestion: jest.fn() }));

beforeEach(() => {
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
