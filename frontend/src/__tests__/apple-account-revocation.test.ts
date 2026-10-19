import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { webcrypto } from 'node:crypto';
import ts from 'typescript';
import { requestAccountDeletion } from '@/lib/delete-account';

let privateKey: string;
beforeAll(async () => {
  const key = await webcrypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
  privateKey = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(await webcrypto.subtle.exportKey('pkcs8',key.privateKey)).toString('base64')}\n-----END PRIVATE KEY-----`;
});
function service(options: {apple?:boolean;blocked?:boolean;configured?:boolean;exchange?:number;revoke?:number;subject?:string;audience?:string;expired?:boolean;authDeleteFails?:boolean}={}) {
 const calls:string[]=[];const forms:URLSearchParams[]=[];
 const user={id:'actor',identities:options.apple===false?[]:[{provider:'apple',identity_data:{sub:'apple-actor'}}]};
 const client={auth:{getUser:async()=>({data:{user},error:null}),admin:{deleteUser:async()=>{calls.push('auth-delete');return {error:options.authDeleteFails??false};}}},
  rpc:async(name:string)=>{calls.push(name);return {data:name==='findez_prepare_account_deletion'?{ready:!options.blocked}:true,error:null};},
  storage:{from:()=>({list:async()=>({data:[],error:null})})}};
 const env:Record<string,string>={APPLE_CLIENT_IDS:'com.findez.app,com.findez.app.siwa',APPLE_SIGN_IN_PRIVATE_KEY:privateKey,APPLE_SIGN_IN_KEY_ID:'TESTKEY',APPLE_TEAM_ID:'TESTTEAM'};
 if(options.configured===false)delete env.APPLE_SIGN_IN_PRIVATE_KEY;
 const fetchMock=async(url:string,init:{body:URLSearchParams})=>{
  const form=init.body;forms.push(form);
  if(url==='https://appleid.apple.com/auth/token'){
   calls.push('apple-exchange');
   const secret=JSON.parse(Buffer.from(form.get('client_secret')!.split('.')[1],'base64url').toString());
   expect(secret.sub).toBe(form.get('client_id'));expect(secret.exp-secret.iat).toBe(300);
   const claims={sub:options.subject??'apple-actor',aud:options.audience??form.get('client_id'),iss:'https://appleid.apple.com',exp:options.expired?1:Math.floor(Date.now()/1000)+300};
   return new Response(JSON.stringify({id_token:`header.${Buffer.from(JSON.stringify(claims)).toString('base64url')}.signature`,refresh_token:'apple-refresh'}),{status:options.exchange??200});
  }
  expect(url).toBe('https://appleid.apple.com/auth/revoke');calls.push('apple-revoke');
  expect(form.get('token')).toBe('apple-refresh');expect(form.get('token_type_hint')).toBe('refresh_token');
  return new Response('',{status:options.revoke??200});
 };
 let handler!:(request:Request)=>Promise<Response>;
 const source=fs.readFileSync(path.join(process.cwd(),'../backend/supabase/functions/delete-user/index.ts'),'utf8').replace(/^import .*$/gm,'');
 const code=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
 vm.runInNewContext(code,{serve:(h:typeof handler)=>handler=h,createClient:()=>client,Deno:{env:{get:(name:string)=>env[name]}},Request,Response,URLSearchParams,TextEncoder,Uint8Array,AbortSignal,atob,btoa,crypto:webcrypto,fetch:fetchMock});
 return {calls,forms,run:(body:unknown={apple_authorization_code:'fresh-code',apple_client_id:'com.findez.app'})=>handler(new Request('https://functions.test/delete-user',{method:'POST',headers:{Authorization:'Bearer test','Content-Type':'application/json'},body:JSON.stringify(body)}))};
}
test('native authorization is verified and revoked before account identity deletion',async()=>{
 const s=service();expect((await s.run()).status).toBe(200);
 expect(s.forms[0].get('code')).toBe('fresh-code');
 expect(s.calls.indexOf('apple-exchange')).toBeLessThan(s.calls.indexOf('apple-revoke'));
 expect(s.calls.indexOf('apple-revoke')).toBeLessThan(s.calls.indexOf('auth-delete'));
 expect(s.calls.indexOf('auth-delete')).toBeLessThan(s.calls.indexOf('findez_finish_account_deletion'));
});
test('web refresh authorization uses its configured website client',async()=>{
 const s=service();expect((await s.run({apple_refresh_token:'web-refresh',apple_client_id:'com.findez.app.siwa'})).status).toBe(200);
 expect(s.forms[0].get('grant_type')).toBe('refresh_token');expect(s.forms[0].get('refresh_token')).toBe('web-refresh');
});
test.each([{},null,[],{apple_authorization_code:'x',apple_client_id:'attacker.app'},{apple_authorization_code:'x'.repeat(4097),apple_client_id:'com.findez.app'}])('missing or invalid Apple confirmation fails closed: %j',async body=>{
 const s=service();expect((await s.run(body)).status).toBe(409);expect(s.calls).not.toContain('auth-delete');expect(s.calls).not.toContain('apple-exchange');
});
test.each([{subject:'different-apple-user'},{audience:'different-client'},{expired:true}])('wrong or expired Apple identity never deletes the FindEZ account: %j',async options=>{
 const s=service(options);expect((await s.run()).status).toBe(403);expect(s.calls).not.toContain('apple-revoke');expect(s.calls).not.toContain('auth-delete');
});
test.each([{configured:false},{exchange:400},{revoke:500}])('provider or configuration failure preserves account and files: %j',async options=>{
 const s=service(options);expect((await s.run()).status).toBe(options.exchange?409:503);expect(s.calls).not.toContain('auth-delete');expect(s.calls).not.toContain('findez_finish_account_deletion');
});
test('ownership blocker runs before contacting Apple',async()=>{
 const s=service({blocked:true});expect((await s.run()).status).toBe(409);expect(s.calls).not.toContain('apple-exchange');
});
test('ordinary email accounts keep the existing deletion behavior',async()=>{
 const s=service({apple:false});expect((await s.run({})).status).toBe(200);expect(s.calls).not.toContain('apple-exchange');expect(s.calls).toContain('auth-delete');
});
test('failed Auth deletion never starts file cleanup even after Apple revocation',async()=>{
 const s=service({authDeleteFails:true});expect((await s.run()).status).toBe(409);expect(s.calls).toContain('apple-revoke');expect(s.calls).not.toContain('findez_finish_account_deletion');
});
test('web forwards only an Apple session refresh token to the authenticated deletion service',async()=>{
 const client={auth:{getSession:async()=>({data:{session:{provider_refresh_token:'private-refresh',user:{identities:[{provider:'apple'}]}}}})},functions:{invoke:jest.fn().mockResolvedValue({data:{success:true},error:null})}};
 await requestAccountDeletion(client);expect(client.functions.invoke).toHaveBeenCalledWith('delete-user',{body:{apple_refresh_token:'private-refresh',apple_client_id:'com.findez.app.siwa'}});
});
