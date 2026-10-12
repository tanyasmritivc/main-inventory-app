/** @jest-environment jsdom */
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TeamsClient } from '@/components/site/teams-client';
import { createTeam } from '@/lib/api';

jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ token: 'test-token', accountId: 'owner' }) }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: jest.fn(), promptValue: jest.fn() }) }));
jest.mock('@/lib/api', () => ({ ...jest.requireActual('@/lib/api'), getMyTeams: jest.fn(async () => ({ teams: [] })), createTeam: jest.fn() }));

test('alphabetized general categories start unselected and custom drafts survive a failed save', async () => {
  const user = userEvent.setup();
  jest.mocked(createTeam).mockRejectedValueOnce(new Error('Could not save team.')).mockResolvedValueOnce({ team: { team_id: 't', name: 'Costumes' } });
  render(<TeamsClient />);
  await user.click(await screen.findByRole('button', { name: /New team/ }));
  const category = screen.getByRole('combobox', { name: 'Team category' });
  expect((category as HTMLSelectElement).value).toBe('');
  const labels = Array.from(category.querySelectorAll('option')).slice(1).map(option => option.textContent!);
  expect(labels).toEqual([...labels].sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())));
  expect(labels).toEqual(expect.arrayContaining(['Household', 'Laboratory', 'Factory & manufacturing', 'Business', 'FIRST Tech Challenge']));
  await user.type(screen.getByPlaceholderText('Team name'), 'Costumes');
  fireEvent.change(category, { target: { value: 'custom' } });
  await user.type(screen.getByRole('textbox', { name: 'Custom category' }), ' Costume department ');
  await user.click(screen.getByRole('button', { name: 'Save' }));
  await screen.findByText('That team change could not be saved.');
  expect((screen.getByRole('textbox', { name: 'Custom category' }) as HTMLInputElement).value).toBe(' Costume department ');
  await user.click(screen.getByRole('button', { name: 'Save' }));
  await waitFor(() => expect(createTeam).toHaveBeenCalledTimes(2));
  expect(createTeam).toHaveBeenLastCalledWith({ token: 'test-token', name: 'Costumes', program: 'custom', custom_category: 'Costume department' });
  await waitFor(() => expect(screen.queryByRole('textbox', { name: 'Custom category' })).toBeNull());
});
