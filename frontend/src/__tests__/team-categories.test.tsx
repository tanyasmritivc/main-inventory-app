/** @jest-environment jsdom */
jest.mock("next/navigation", () => ({ useRouter: () => ({ push: jest.fn() }) }));
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TeamsClient } from '@/components/site/teams-client';
import { createTeam } from '@/lib/api';
import * as api from '@/lib/api';

jest.mock('@/lib/use-api-session', () => ({ useApiSession: () => ({ token: 'test-token', accountId: 'owner' }) }));
jest.mock('@/components/site/app-dialog-provider', () => ({ useAppDialog: () => ({ confirmAction: jest.fn(), promptValue: jest.fn() }) }));
jest.mock('@/lib/api', () => ({ ...jest.requireActual('@/lib/api'), getMyTeams: jest.fn(async () => ({ teams: [] })), createTeam: jest.fn(), getTeamWorkspace: jest.fn(async()=>({team:{team_id:'ftc',name:'Robotics'},role:'owner'})), getTeamSpaces: jest.fn(async()=>({spaces:[]})), getTeamBoard: jest.fn(async()=>({tasks:[]})), getTeamMembers: jest.fn(async()=>[]), getTeamDocuments: jest.fn(async()=>({documents:[]})), getTeamActivity: jest.fn(async()=>({activity:[]})), getSpaces: jest.fn(async()=>[]) }));

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

test('workspace board opens only its selected panel without a second workspace chooser',async()=>{
 jest.mocked(api.getMyTeams).mockResolvedValue({teams:[{team_id:'ftc',name:'Robotics'}]} as never);
 render(<TeamsClient selectedTeamId="ftc" panel="board"/>);
 await screen.findByRole('button',{name:/New/});
 expect(api.getTeamBoard).toHaveBeenCalledWith({token:'test-token',teamId:'ftc'});
 expect(screen.queryByRole('combobox',{name:'Current team'})).toBeNull();
 expect(screen.queryByRole('button',{name:/Spaces/})).toBeNull();
 expect(screen.queryByRole('heading',{level:1})).toBeNull();
});
test('workspace documents preserve view-only permissions',async()=>{
 jest.mocked(api.getMyTeams).mockResolvedValue({teams:[{team_id:'ftc',name:'Robotics'}]} as never);
 jest.mocked(api.getTeamWorkspace).mockResolvedValue({team:{team_id:'ftc',name:'Robotics'},role:'viewer'} as never);
 jest.mocked(api.getTeamDocuments).mockResolvedValue({documents:[{team_document_id:'doc',filename:'Wiring guide.pdf',mime_type:'application/pdf',uploaded_by:'owner',created_at:'2026-10-15T00:00:00Z'}]} as never);
 render(<TeamsClient selectedTeamId="ftc" panel="files"/>);
 await screen.findByText('Wiring guide.pdf');
 expect(screen.queryByRole('button',{name:/Upload/})).toBeNull();
 expect(api.getTeamDocuments).toHaveBeenCalledWith({token:'test-token',teamId:'ftc'});
});
