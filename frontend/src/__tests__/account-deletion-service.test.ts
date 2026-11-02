import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import ts from 'typescript';
import {requestAccountDeletion,AccountDeletionError} from '@/lib/delete-account';

function service({owned='',lookupError=false,authError=false,deleteError=false}={}) {
 const calls:string[]=[];
 const client={
  auth:{getUser:async()=>({data:{user:authError?null:{id:'actor'}},error:authError}),admin:{deleteUser:async()=>{calls.push('auth-delete');return {error:deleteError};}}},
  rpc:async(name:string)=>{calls.push(name);return {data:name==='findez_prepare_account_deletion'?{ready:!owned,...(owned?{code:'OWNERSHIP_REQUIRED',error:'Transfer ownership first'}:{})}:true,error:lookupError};},
  from:(table:string)=>{
   let action='read';const q:Record<string,unknown>={};
   for(const method of ['select','eq','neq','limit','range'])q[method]=()=>q;
   q.delete=()=>{action='delete';return q;};
   q.then=(resolve:(value:unknown)=>unknown)=>{calls.push(`${table}:${action}`);return Promise.resolve(resolve({data:table===owned?[{owner_user_id:'actor'}]:[],error:lookupError}));};
   return q;
  },
  storage:{from:()=>({list:async()=>{calls.push('storage-list');return {data:[],error:null};},remove:async()=>{calls.push('storage-delete');return {error:null};}})},
 };
 let handler!:(request:Request)=>Promise<Response>;
 const source=fs.readFileSync(path.join(process.cwd(),'../backend/supabase/functions/delete-user/index.ts'),'utf8').replace(/^import .*$/gm,'');
 const code=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
 vm.runInNewContext(code,{serve:(h:typeof handler)=>handler=h,createClient:()=>client,Deno:{env:{get:()=> 'test'}},Request,Response,console:{error:()=>undefined}});
 return {calls,run:(method='POST')=>handler(new Request('https://functions.test/delete-user',{method,headers:{Authorization:'Bearer test'}}))};
}
test.each(['app_organizations','teams'])('ownership in %s blocks before any file or row deletion',async(owned)=>{
 const s=service({owned});const response=await s.run();expect(response.status).toBe(409);
 expect((await response.json()).code).toBe('OWNERSHIP_REQUIRED');
 expect(s.calls.some(c=>c.includes('delete')||c.includes('storage'))).toBe(false);
});
test('failed preflight and invalid auth perform no cleanup',async()=>{
 for(const options of [{lookupError:true},{authError:true}]){
  const s=service(options);expect((await s.run()).status).toBe(options.authError?401:503);expect(s.calls.some(c=>c.includes('delete')||c.includes('storage'))).toBe(false);
 }
});
test('only final auth success confirms account deletion and unsafe methods are rejected',async()=>{
 const s=service();const response=await s.run();expect(response.status).toBe(200);expect(await response.json()).toEqual({success:true,file_cleanup_pending:true});expect(s.calls.indexOf('auth-delete')).toBeLessThan(s.calls.indexOf('findez_finish_account_deletion'));
 expect((await service().run('GET')).status).toBe(405);
 const failed=service({deleteError:true});expect((await failed.run()).status).toBe(409);expect(failed.calls).not.toContain('findez_finish_account_deletion');expect(failed.calls).not.toContain('storage-delete');
});
test('web rejects unconfirmed account responses and displays ownership blocker',async()=>{
 const client={functions:{invoke:jest.fn()}};
 client.functions.invoke.mockResolvedValue({data:{},error:null});await expect(requestAccountDeletion(client)).rejects.toBeInstanceOf(AccountDeletionError);
 client.functions.invoke.mockResolvedValue({data:null,error:{context:new Response(JSON.stringify({code:'OWNERSHIP_REQUIRED',error:'Transfer your organization first'}),{status:409})}});
 await expect(requestAccountDeletion(client)).rejects.toThrow('Transfer your organization first');
 client.functions.invoke.mockResolvedValue({data:{success:true},error:null});await expect(requestAccountDeletion(client)).resolves.toBeUndefined();
});
