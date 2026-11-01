/** @jest-environment jsdom */
import {render,screen,waitFor} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {mockBrowserTopLayer} from './mock-browser-top-layer';
mockBrowserTopLayer();
import {ResourceSettings} from '@/components/site/resource-settings';
import {WorkspaceLeaveDialog} from '@/components/site/workspace-leave-dialog';
import {OrganizationDirectory} from '@/components/site/organization-directory';
import {organizationNavigation} from '@/lib/context-navigation';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/use-api-session',()=>({useApiSession:()=>({accountId:'admin',error:null})}));
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
jest.mock('@/components/site/app-shell',()=>({AppShell:({children}:{children:React.ReactNode})=><main>{children}</main>}));
jest.mock('next/navigation',()=>({useRouter:()=>({push:jest.fn(),replace:jest.fn()})}));
const props={id:'test',scope:'workspace' as const,name:'Workspace',role:'viewer',canRename:false,canTransfer:false,canDelete:false,isOwner:false,onRename:jest.fn(),onDelete:jest.fn(),onLeave:jest.fn(),onTransferred:jest.fn()};
beforeEach(()=>jest.clearAllMocks());
test('workspace Viewer has useful destinations but no administrative controls',()=>{
 render(<ResourceSettings {...props}/>);
 expect(screen.getByRole('link',{name:/People and invitations/}).getAttribute('href')).toBe('/workspaces/test?view=people');
 expect(screen.getByRole('link',{name:/Tasks and assignments/}).getAttribute('href')).toBe('/workspaces/test?view=board');
 expect(screen.queryByRole('button',{name:/Rename|Delete|Transfer/})).toBeNull();
 expect(screen.getByRole('button',{name:'Leave workspace'})).toBeTruthy();
});
test('organization Admin settings expose rename and transfer but no delete',async()=>{
 jest.mocked(accountRequest).mockResolvedValue({organization:{organization_id:'org',name:'Sample org',role:'admin',owner_user_id:'owner'},workspaces:[],members:[]});
 render(<OrganizationDirectory organizationId="org" view="settings"/>);
 expect(await screen.findByRole('button',{name:'Rename organization'})).toBeTruthy();
 expect(screen.getByRole('button',{name:'Transfer ownership'})).toBeTruthy();
 expect(screen.queryByRole('button',{name:'Delete organization'})).toBeNull();
 expect(screen.queryByRole('searchbox')).toBeNull();
 expect(organizationNavigation('org','Sample org','settings').activeRoute).toBe('/organizations/org?view=settings');
});
test('effective organization administrator is directed to organization membership to leave',()=>{
 render(<ResourceSettings {...props} role="mentor" inheritedAdmin canRename canTransfer canDelete/>);
 expect(screen.getByText(/access comes from the organization/)).toBeTruthy();
 expect(screen.queryByRole('button',{name:'Leave workspace'})).toBeNull();
});
test('leave requires confirmation and a positive server receipt',async()=>{
 const onLeft=jest.fn();jest.mocked(accountRequest).mockResolvedValue({left:false});
 render(<WorkspaceLeaveDialog accountId="admin" workspace={{workspace_id:'test',name:'Test'}} onClose={jest.fn()} onLeft={onLeft}/>);
 expect(accountRequest).not.toHaveBeenCalled();
 await userEvent.click(screen.getByRole('button',{name:'Leave workspace'}));
 await screen.findByRole('alert');expect(onLeft).not.toHaveBeenCalled();
 jest.mocked(accountRequest).mockResolvedValue({left:true});await userEvent.click(screen.getByRole('button',{name:'Leave workspace'}));
 await waitFor(()=>expect(onLeft).toHaveBeenCalledTimes(1));
});
