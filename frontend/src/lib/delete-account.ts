type DeletionClient = {
 functions:{invoke:(name:string, options?:{body:Record<string,string>})=>Promise<{data:unknown;error:unknown}>};
 auth?:{getSession:()=>Promise<{data:{session:{provider_refresh_token?:string|null;user:{identities?:{provider:string}[]}}|null}}>};
};
const fallback="Account deletion did not finish. Some data may already have been removed. Try again or contact info@findez.ai.";
export async function requestAccountDeletion(client:DeletionClient):Promise<void> {
 const session=(await client.auth?.getSession())?.data.session;
 const refresh=session?.user.identities?.some(identity=>identity.provider==='apple') ? session.provider_refresh_token : null;
 const {data,error}=await client.functions.invoke('delete-user',refresh?{body:{apple_refresh_token:refresh,apple_client_id:'com.findez.app.siwa'}}:undefined);
 if(error){
  const context=(error as {context?:Response}).context;
  if(context){
   try {
    const body=await context.clone().json();
    if(['OWNERSHIP_REQUIRED','SHARED_RECORDS','APPLE_REAUTH_REQUIRED','APPLE_REVOCATION_UNAVAILABLE','APPLE_IDENTITY_MISMATCH'].includes(body.code)&&typeof body.error==='string')throw new AccountDeletionError(body.error);
   }catch(reason){if(reason instanceof AccountDeletionError)throw reason;}
  }
  throw new AccountDeletionError(fallback);
 }
 if(!data||typeof data!=='object'||!('success' in data)||data.success!==true)throw new AccountDeletionError(fallback);
}
export class AccountDeletionError extends Error {}
