/** @jest-environment jsdom */
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AgentApprovalClient } from '@/components/site/agent-approval-client';
import { useApiSession } from '@/lib/use-api-session';

jest.mock('@/lib/use-api-session');
const id = '90000000-0000-0000-0000-000000000001';
const getSession = jest.fn();
const fetchMock = jest.fn();
const approval = { id, kind: 'space', key_name: 'Claude', key_revoked: false, expires_at: '2099-10-19T23:00:00Z', status: 'pending', preview: { name: 'Parts shelf', impact: { spaces: 1, items: 7 } } };
const response = (body: unknown, status = 200) => ({ ok: status === 200, status, json: async () => body });

beforeEach(() => {
  jest.clearAllMocks();
  global.fetch = fetchMock;
  getSession.mockResolvedValue({ data: { session: { access_token: 'session-only', user: { id: 'owner' } } } });
  jest.mocked(useApiSession).mockReturnValue({ token: 'session-only', accountId: 'owner', loading: false, error: null, supabase: { auth: { getSession } } } as unknown as ReturnType<typeof useApiSession>);
  fetchMock.mockResolvedValue(response(approval));
  AbortSignal.timeout = jest.fn(() => new AbortController().signal);
});

test('opening a review link only reads and requires the exact name before deletion', async () => {
  const user = userEvent.setup(); render(<AgentApprovalClient approvalId={id} />);
  const input = await screen.findByLabelText('Type “Parts shelf” to confirm');
  expect(fetchMock).toHaveBeenCalledTimes(1);
  expect(fetchMock.mock.calls[0][1].method).toBe('GET');
  const button = screen.getByRole('button', { name: 'Permanently delete' });
  expect((button as HTMLButtonElement).disabled).toBe(true);
  await user.type(input, 'Parts shelf');
  fetchMock.mockResolvedValue(response({ id, status: 'confirmed', receipt: { deleted: true } }));
  await user.click(button);
  expect(await screen.findByText('Deletion completed')).toBeTruthy();
  const posted = fetchMock.mock.calls[1][1];
  expect(posted.method).toBe('POST');
  expect(posted.headers.Authorization).toBe('Bearer session-only');
  expect(JSON.parse(posted.body)).toEqual({ decision: 'confirm', name: 'Parts shelf' });
});

test('cancel requires no typed name and never submits confirmation', async () => {
  const user = userEvent.setup(); render(<AgentApprovalClient approvalId={id} />);
  const cancel = await screen.findByRole('button', { name: 'Cancel request' });
  fetchMock.mockResolvedValue(response({ id, status: 'cancelled' })); await user.click(cancel);
  expect(await screen.findByText('Request cancelled')).toBeTruthy();
  expect(JSON.parse(fetchMock.mock.calls[1][1].body).decision).toBe('cancel');
});

test.each([{ expires_at: '2000-01-01T00:00:00Z' }, { key_revoked: true }])('expired or revoked request has no delete button', async (changes) => {
  fetchMock.mockResolvedValue(response({ ...approval, ...changes }));
  render(<AgentApprovalClient approvalId={id} />);
  await screen.findByRole('alert'); expect(screen.queryByRole('button', { name: 'Permanently delete' })).toBeNull();
  expect(fetchMock).toHaveBeenCalledTimes(1);
});

test('a changed account cannot submit the prior account approval', async () => {
  const user = userEvent.setup(); render(<AgentApprovalClient approvalId={id} />);
  await user.type(await screen.findByLabelText('Type “Parts shelf” to confirm'), 'Parts shelf');
  getSession.mockResolvedValue({ data: { session: { access_token: 'other', user: { id: 'other' } } } });
  await user.click(screen.getByRole('button', { name: 'Permanently delete' }));
  expect((await screen.findByRole('alert')).textContent).toContain('Your account changed');
  expect(fetchMock).toHaveBeenCalledTimes(1);
});

test('an uncertain decision requires a status refresh before retry', async () => {
  const user = userEvent.setup(); render(<AgentApprovalClient approvalId={id} />);
  await user.type(await screen.findByLabelText('Type “Parts shelf” to confirm'), 'Parts shelf');
  fetchMock.mockRejectedValueOnce(new Error('Connection lost'));
  await user.click(screen.getByRole('button', { name: 'Permanently delete' }));
  await screen.findByRole('alert');
  expect((screen.getByRole('button', { name: 'Permanently delete' }) as HTMLButtonElement).disabled).toBe(true);
  fetchMock.mockResolvedValue(response({ ...approval, status: 'confirmed', receipt: {deleted: true} }));
  await user.click(screen.getByRole('button', { name: 'Refresh status' }));
  await waitFor(() => expect(screen.getByText('Deletion completed')).toBeTruthy());
});


test('a confirmed status without a deletion receipt is not displayed as success', async () => {
  fetchMock.mockResolvedValue(response({ ...approval, status: 'confirmed' }));
  render(<AgentApprovalClient approvalId={approval.id} />);
  await screen.findByRole('alert');
  expect(screen.queryByText('Deletion completed')).toBeNull();
});
