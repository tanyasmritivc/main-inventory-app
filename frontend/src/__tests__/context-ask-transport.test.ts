import { askQuestion } from '@/lib/ask-stream';
import { accountToken } from '@/lib/account-request';
import { selectInventory, type InventorySelection } from '@/lib/inventory-selection';
jest.mock('@/lib/account-request',()=>({accountToken:jest.fn()}));
const selected:InventorySelection={accountId:'actor',inventory_id:'space-a',owner_user_id:'owner',team_id:null,is_default:false,name:'Hardware',can_edit:true,workspace:{workspace_id:'team',team_id:'team',role:'member',kind:'team',name:'Robotics',organization_id:'org-a'}};
const fetchMock=jest.fn();
function response(events:object[]){return {ok:true,body:new ReadableStream({start(c){c.enqueue(new TextEncoder().encode(events.map(e=>'data: '+JSON.stringify(e)+'\n\n').join('')));c.close();}})};}
beforeEach(()=>{jest.clearAllMocks();selectInventory(selected);jest.mocked(accountToken).mockResolvedValue('fixture-token');global.fetch=fetchMock;});
afterEach(()=>selectInventory(null));
const options=()=>({accountId:'actor',worldId:'org-a',message:'Were are my gears',signal:new AbortController().signal,onDelta:jest.fn(),onReset:jest.fn(),onStatus:jest.fn(),onDone:jest.fn()});
test('contextual lookup binds organization and entry Space and replaces a failed attempt',async()=>{
 fetchMock.mockResolvedValue(response([{type:'delta',delta:'old answer'},{type:'reset'},{type:'delta',delta:'**Gears**\n\n|Part|Qty|Space|\n|---|---|---|\n|Gear|2|Workshop|'},{type:'done',conversation_id:'conversation',assistant_message:'final'}]));
 let visible='';const opts=options();
 await askQuestion({...opts,contextual:true,onDelta:d=>{visible+=d;},onReset:()=>{visible='';}});
 const [url,request]=fetchMock.mock.calls[0];
 expect(url).toContain('/worlds/org-a/ai_command');
 expect(JSON.parse(request.body)).toMatchObject({context_inventory_id:'space-a'});
 expect(visible).not.toContain('old answer');expect(visible).toContain('**Gears**');
 expect(opts.onDone).toHaveBeenCalledWith(expect.objectContaining({conversationId:'conversation'}));
});
test('main chat keeps its existing request contract without contextual formatting',async()=>{
 fetchMock.mockResolvedValue(response([{type:'done',conversation_id:'c'}]));
 await askQuestion(options());
 expect(JSON.parse(fetchMock.mock.calls[0][1].body)).not.toHaveProperty('context_inventory_id');
});
test('changing the selected Space during a request discards its late reply',async()=>{
 fetchMock.mockImplementation(async()=>{selectInventory({...selected,inventory_id:'space-b',workspace:{...selected.workspace,organization_id:'org-b'}});return response([{type:'delta',delta:'org-a records'},{type:'done',conversation_id:'c'}]);});
 const opts=options();await expect(askQuestion({...opts,contextual:true})).rejects.toThrow('inventory changed');
 expect(opts.onDelta).not.toHaveBeenCalled();expect(opts.onDone).not.toHaveBeenCalled();
});
test('interruption remains an error with no fabricated completion',async()=>{
 fetchMock.mockResolvedValue(response([{type:'delta',delta:'partial'},{type:'error',code:'world_chat_failed',message:'Could not finish'}]));
 const opts=options();await expect(askQuestion({...opts,contextual:true})).rejects.toThrow('Could not finish');
 expect(opts.onDone).not.toHaveBeenCalled();
});
