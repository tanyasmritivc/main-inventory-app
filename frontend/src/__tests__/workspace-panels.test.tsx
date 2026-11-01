/** @jest-environment jsdom */
import {fireEvent,render,screen,waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {TeamsClient} from '@/components/site/teams-client';
import * as api from '@/lib/api';
jest.mock('@/lib/api',()=>({...jest.requireActual('@/lib/api'),getMyTeams:jest.fn(),getTeamWorkspace:jest.fn(),getTeamMembers:jest.fn(),getTeamBoard:jest.fn(),getTeamSpaces:jest.fn(),getTeamDocuments:jest.fn(),getTeamActivity:jest.fn(),getSpaces:jest.fn(),emailTeamInvite:jest.fn(),getTeamInvite:jest.fn()}));
jest.mock('@/lib/use-api-session',()=>({useApiSession:()=>({accountId:'qa',token:'qa-token'})}));
jest.mock('next/navigation',()=>({useRouter:()=>({push:jest.fn()})}));
jest.mock('@/components/site/app-dialog-provider',()=>({useAppDialog:()=>({confirmAction:async()=>true,promptValue:async()=> 'person@example.invalid'})}));
beforeEach(()=>{jest.clearAllMocks();jest.mocked(api.getMyTeams).mockResolvedValue({teams:[{team_id:'qa-team',name:'QA'}]} as never);jest.mocked(api.getTeamWorkspace).mockResolvedValue({team:{team_id:'qa-team',name:'QA'},role:'mentor'} as never);jest.mocked(api.getTeamMembers).mockResolvedValue([]);jest.mocked(api.getTeamBoard).mockResolvedValue({tasks:[{task_id:'t',title:'Review robot',status:'todo',task_type:'task',priority:'normal'}],role:'mentor'});jest.mocked(api.getTeamDocuments).mockResolvedValue({documents:[],role:'mentor'});});
test('tasks load independently of unrelated spaces, files and activity services',async()=>{
 render(<TeamsClient selectedTeamId="qa-team" panel="board"/>);
 await screen.findByText('Review robot');
 for(const fn of [api.getTeamSpaces,api.getTeamDocuments,api.getTeamActivity,api.getSpaces])expect(fn).not.toHaveBeenCalled();
 expect(screen.getByRole('combobox',{name:'Status for Review robot'})).toBeTruthy();
});
test('revoked workspace access clears stale tasks and edit controls immediately',async()=>{
 render(<TeamsClient selectedTeamId="qa-team" panel="board"/>);await screen.findByText('Review robot');
 jest.mocked(api.getTeamWorkspace).mockRejectedValue(new Error('Access removed'));
 fireEvent(window,new Event('findez-permissions-changed'));
 await screen.findByRole('alert');expect(screen.queryByText('Review robot')).toBeNull();expect(screen.queryByRole('button',{name:'New'})).toBeNull();
});
test('failed invite delivery is visible and never reported sent',async()=>{
 jest.mocked(api.emailTeamInvite).mockResolvedValue({sent:false,email:'person@example.invalid'});
 render(<TeamsClient selectedTeamId="qa-team" panel="people"/>);
 await userEvent.click(await screen.findByRole('button',{name:'Invite'}));
 await screen.findByRole('alert');expect(screen.queryByText('Invitation email sent.')).toBeNull();
 expect(api.emailTeamInvite).toHaveBeenCalledWith({token:'qa-token',teamId:'qa-team',email:'person@example.invalid'});
});
test('file loading errors surface with a retry instead of an unhandled promise',async()=>{
 jest.mocked(api.getTeamDocuments).mockRejectedValue(new Error('Files unavailable'));
 render(<TeamsClient selectedTeamId="qa-team" panel="files"/>);
 await screen.findByRole('alert');expect(screen.queryByRole('button',{name:'Upload'})).toBeNull();
 jest.mocked(api.getTeamDocuments).mockResolvedValue({documents:[],role:'mentor'});
 await userEvent.click(screen.getByRole('button',{name:'Retry'}));
 await waitFor(()=>expect(screen.queryByRole('alert')).toBeNull());expect(screen.getByRole('button',{name:'Upload'})).toBeTruthy();
});
