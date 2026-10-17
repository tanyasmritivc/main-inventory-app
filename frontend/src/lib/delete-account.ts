type DeletionClient = {functions:{invoke:(name:string)=>Promise<{data:unknown;error:unknown}>}};
const fallback="Account deletion did not finish. Some data may already have been removed. Try again or contact info@findez.ai.";
export async function requestAccountDeletion(client:DeletionClient):Promise<void> {
 const {data,error}=await client.functions.invoke('delete-user');
 if(error){
  const context=(error as {context?:Response}).context;
  if(context){
   try {
    const body=await context.clone().json();
    if(['OWNERSHIP_REQUIRED','SHARED_RECORDS'].includes(body.code)&&typeof body.error==='string')throw new AccountDeletionError(body.error);
   }catch(reason){if(reason instanceof AccountDeletionError)throw reason;}
  }
  throw new AccountDeletionError(fallback);
 }
 if(!data||typeof data!=='object'||!('success' in data)||data.success!==true)throw new AccountDeletionError(fallback);
}
export class AccountDeletionError extends Error {}
