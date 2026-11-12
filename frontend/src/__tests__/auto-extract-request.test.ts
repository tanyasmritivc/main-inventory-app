import { File as NodeFile } from 'node:buffer';
import { askQuestion } from '@/lib/ask-stream';
jest.mock('@/lib/account-request',()=>({accountToken:async()=> 'fixture-session'}));
jest.mock('@/lib/inventory-selection',()=>({activeInventory:()=>undefined,assertInventory:()=>{},inventoryApiPath:(p:string)=>p}));
test('automatic extraction retains the Send multipart contract and makes one request',async()=>{
 const done={type:'done',conversation_id:'fixture-chat',assistant_message:'Review the draft.'};
 const fetchMock=jest.fn().mockResolvedValue({ok:true,body:new ReadableStream({start(controller){controller.enqueue(new TextEncoder().encode(`data: ${JSON.stringify(done)}\n\n`));controller.close();}})});
 const previous=global.fetch;global.fetch=fetchMock;
 try {
  await askQuestion({accountId:'fixture-account',worldId:'personal',requestId:'fixture-request',message:'Auto extract the items in this photo. Keep a draft for review before saving.',photo:new NodeFile(['photo-bytes'],'parts.jpg',{type:'image/jpeg'}) as unknown as File,autoExtract:true,sources:[],conversationId:null,signal:new AbortController().signal,onDelta:()=>{},onStatus:()=>{},onDone:()=>{}});
  expect(fetchMock).toHaveBeenCalledTimes(1);
  const [url,options]=fetchMock.mock.calls[0];expect(url).toMatch(/\/worlds\/personal\/ai_photo_question$/);expect(options.method).toBe('POST');
  const form=options.body as FormData;expect(Array.from(form.keys())).toEqual(['file','sources','auto_extract','preview_only','message','supports_item_actions','supports_item_management','supports_task_actions','supports_capture','request_id']);
  expect(form.get('sources')).toBe('[]');expect(form.get('auto_extract')).toBe('true');expect(form.get('preview_only')).toBe('true');expect(form.get('message')).toBe('Auto extract the items in this photo. Keep a draft for review before saving.');expect(form.get('request_id')).toBe('fixture-request');expect((form.get('file') as File).name).toBe('parts.jpg');expect(await (form.get('file') as File).text()).toBe('photo-bytes');
 }finally{global.fetch=previous;}
});
