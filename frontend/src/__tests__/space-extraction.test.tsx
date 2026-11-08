/** @jest-environment jsdom */
import {render,screen,waitFor} from '@testing-library/react';
import {SpaceExtraction} from '@/components/site/space-extraction';
import {askQuestion} from '@/lib/ask-stream';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/ask-stream',()=>({askQuestion:jest.fn()}));
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
jest.mock('@/lib/inventory-selection',()=>({activeInventory:()=>({inventory_id:'inventory'}),assertInventory:jest.fn()}));
jest.mock('@/components/site/chat-capture-card',()=>({CaptureScan:()=> <p>Scanning</p>,ChatCaptureCard:({capture,fixedDestination}: {capture:{space_id:string},fixedDestination:{spaceId:string}})=><p>Draft: {capture.space_id} / {fixedDestination.spaceId}</p>}));
const draft={id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',revision:1,status:'draft',items:[{index:0,selected:true,item:{name:'Cable',category:'Tools',quantity:2}}]};
beforeEach(()=>{jest.clearAllMocks();URL.createObjectURL=jest.fn(()=>'/photo');URL.revokeObjectURL=jest.fn();Object.defineProperty(globalThis.crypto,'randomUUID',{value:()=> 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',configurable:true});});
test('Space extraction uses main photo service and binds the draft before exposing save controls',async()=>{
 jest.mocked(askQuestion).mockImplementation(async opts=>{opts.onDone?.({conversationId:'chat',context:{capture:draft} as never});});
 jest.mocked(accountRequest).mockResolvedValue({capture:{...draft,revision:2,inventory_id:'inventory',space_id:'garage'}});
 render(<SpaceExtraction file={new File(['photo'],'photo.png',{type:'image/png'})} accountId="actor" worldId="world" inventoryId="inventory" spaceId="garage" spaceName="Garage" onClose={()=>{}} onSaved={()=>{}}/>);
 expect(await screen.findByText('Draft: garage / garage')).toBeTruthy();
 expect(askQuestion).toHaveBeenCalledWith(expect.objectContaining({autoExtract:true,worldId:'world'}));
 expect(accountRequest).toHaveBeenCalledWith('actor',expect.stringContaining('/captures/'),expect.objectContaining({method:'PATCH',body:{revision:1,changes:{inventory_id:'inventory',space_id:'garage'}}}));
});
test('a missing or changed destination cannot expose save controls',async()=>{
 jest.mocked(askQuestion).mockImplementation(async opts=>{opts.onDone?.({conversationId:'chat',context:{capture:draft} as never});});
 jest.mocked(accountRequest).mockResolvedValue({capture:{...draft,inventory_id:'other',space_id:'other'}});
 render(<SpaceExtraction file={new File(['photo'],'photo.png',{type:'image/png'})} accountId="actor" worldId="world" inventoryId="inventory" spaceId="garage" spaceName="Garage" onClose={()=>{}} onSaved={()=>{}}/>);
 await waitFor(()=>expect(screen.getByRole('alert')).toBeTruthy());expect(screen.queryByText(/Draft:/)).toBeNull();
});
