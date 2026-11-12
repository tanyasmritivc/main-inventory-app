/** @jest-environment jsdom */
import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { AssistClient } from '@/components/site/assist-client';
import { accountRequest } from '@/lib/account-request';
import { askQuestion } from '@/lib/ask-stream';
jest.mock('@/lib/use-api-session',()=>({useApiSession:()=>({accountId:'fixture-account',error:null})}));
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
jest.mock('@/components/site/app-dialog-provider',()=>({useAppDialog:()=>({confirmAction:jest.fn()})}));
jest.mock('next/navigation',()=>({useRouter:()=>({push:jest.fn(),refresh:jest.fn()}),usePathname:()=>'/worlds/personal'}));
jest.mock('@/lib/ask-stream',()=>({askQuestion:jest.fn()}));
const photo=()=>new File(['image'],'parts.jpg',{type:'image/jpeg'});
let pending: Parameters<typeof askQuestion>[0];
beforeEach(()=>{
 window.matchMedia=jest.fn().mockReturnValue({matches:false,addEventListener:jest.fn(),removeEventListener:jest.fn()});
 localStorage.clear();jest.clearAllMocks();URL.createObjectURL=jest.fn(()=> 'blob:fixture');URL.revokeObjectURL=jest.fn();
 jest.mocked(accountRequest).mockResolvedValue([] as never);
 jest.mocked(askQuestion).mockImplementation(options=>{pending=options;return new Promise((resolve,reject)=>{options.signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError')));(options as typeof options & {finish:()=>void}).finish=resolve;});});
});
async function finish(){await act(async()=>{pending.onDone({conversationId:'chat',content:'Ready for review.'});(pending as typeof pending & {finish:()=>void}).finish();});}
for(const entry of ['extract','library','camera','drop','paste']) for(const text of ['', 'Keep this question for later']){
 test(`${entry} starts exactly once and preserves composer ${text?'text':'empty state'}`,async()=>{
  const {container,unmount}=render(<AssistClient worldId="personal"/>);
  const composer=screen.getByRole('textbox',{name:'Your question'});fireEvent.change(composer,{target:{value:text}});
  const file=photo();
  if(entry==='paste') fireEvent.paste(composer,{clipboardData:{items:[{type:'image/jpeg',getAsFile:()=>file}]}});
  else if(entry==='drop') fireEvent.drop(container.querySelector('.ask-workspace')!,{dataTransfer:{files:[file],types:['Files']}});
  else {const inputs=container.querySelectorAll('input[type=file][accept="image/*"]');fireEvent.change(inputs[entry==='library'?0:entry==='camera'?1:2],{target:{files:[file]}});}
  await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(1));
  expect(pending.photo).toBe(file);expect(pending.autoExtract).toBe(true);expect(pending.message).toBe('Auto extract the items in this photo. Keep a draft for review before saving.');
  expect((composer as HTMLTextAreaElement).value).toBe(text);expect(screen.getByRole('button',{name:'Stop'})).toBeTruthy();
  // A second event before the first completes must not create a duplicate request.
  fireEvent.paste(composer,{clipboardData:{items:[{type:'image/jpeg',getAsFile:()=>file}]}});expect(askQuestion).toHaveBeenCalledTimes(1);
  await finish();expect((composer as HTMLTextAreaElement).value).toBe(text);expect(screen.queryByRole('button',{name:'Stop'})).toBeNull();unmount();
 });
}
test('stop aborts the same request and permits scanning again without sending the typed question',async()=>{
 const {container}=render(<AssistClient worldId="personal"/>);const composer=screen.getByRole('textbox',{name:'Your question'});fireEvent.change(composer,{target:{value:'My unsent question'}});
 fireEvent.change(container.querySelectorAll('input[type=file][accept="image/*"]')[2],{target:{files:[photo()]}});
 await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(1));fireEvent.click(screen.getByRole('button',{name:'Stop'}));
 await waitFor(()=>expect(screen.getByRole('button',{name:'Scan again'})).toBeTruthy());expect(pending.signal.aborted).toBe(true);expect((composer as HTMLTextAreaElement).value).toBe('My unsent question');
 fireEvent.click(screen.getByRole('button',{name:'Scan again'}));await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(2));await finish();
});
test('closing an active extraction aborts it and leaves the regular composer available',async()=>{
 const {container}=render(<AssistClient worldId="personal"/>);fireEvent.change(container.querySelectorAll('input[type=file][accept="image/*"]')[2],{target:{files:[photo()]}});
 await waitFor(()=>expect(askQuestion).toHaveBeenCalledTimes(1));fireEvent.click(screen.getByRole('button',{name:'Close extraction'}));
 await waitFor(()=>expect((screen.getByRole('textbox',{name:'Your question'}) as HTMLTextAreaElement).disabled).toBe(false));expect(pending.signal.aborted).toBe(true);expect(screen.queryByRole('region',{name:'Review extraction'})).toBeNull();
});
