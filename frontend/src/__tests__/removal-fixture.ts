import {accountRequest} from '@/lib/account-request';
export const preview = (kind: string, id: string, name: string) => ({kind,id,name,workspaces:0,inventories:0,spaces:1,items:2,can_move:true,destinations:[{id:'personal',name:'Personal'}]});
export const receipt = (kind: string, id: string) => ({kind,id,action:'delete',deleted:true,moved:false});
export const mutations = () => jest.mocked(accountRequest).mock.calls.filter(call => call[2]?.method);
