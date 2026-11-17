/** @jest-environment jsdom */
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(process.cwd(),'../integrations/findez-fusion/FindEZ');
const html=fs.readFileSync(path.join(root,'palette.html'),'utf8');
const script=fs.readFileSync(path.join(root,'palette.js'),'utf8');
const host=window as typeof window & { adsk:{fusionSendData:jest.Mock}; fusionJavaScriptHandler:{handle:(action:string,raw:string)=>string} };
const receive=(action:string,data:unknown)=>host.fusionJavaScriptHandler.handle(action,JSON.stringify(data));
beforeEach(()=>{
 document.body.innerHTML=html.match(/<body>([\s\S]*)<\/body>/)![1].replace(/<script[\s\S]*?<\/script>/g,'');
 host.adsk={fusionSendData:jest.fn()};
 new Function(script)();
});
test('inventory quantities, catalog identity and insertion stay separate',()=>{
 receive('connected',{inventory_name:'Team A',workspace_name:'Robotics'});
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('inventory',JSON.stringify({q:'',offset:0}));
 receive('inventory',{items:[{item_id:'owned',name:'<img src=x onerror=alert(1)>',on_hand:42,reserved:10,checked_out:2,available:30,availability_known:true}],locations:[],offset:0,total:1,next_offset:null});
 expect(document.querySelector('#parts img')).toBeNull();
 expect(document.getElementById('parts')!.textContent).toContain('30 available');
 document.querySelector<HTMLButtonElement>('#parts button')!.click();
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('models',JSON.stringify({id:'owned',mode:'design',folder_id:null,offset:0}));
 document.getElementById('catalog-tab')!.click();
 receive('catalog',{parts:[{catalog_id:'public',canonical_name:'Motor',specifications:{voltage:12}}],offset:0,total:1,next_offset:null});
 expect(document.getElementById('parts')!.textContent).toContain('Not a stock record');
 expect(document.getElementById('parts')!.textContent).not.toContain('30 available');
});
test('comparison reports uncertain lines and disconnect removes prior inventory',()=>{
 receive('connected',{inventory_name:'Team A',workspace_name:'Robotics'});
 receive('comparison',{document:{name:'Robot'},summary:{covered_units:4,required_units:6},warnings:['Check the configuration'],items:[{name:'Bearing',status:'needs_review',required:6,assigned:4,missing:2,matches:[]}]});
 expect(document.getElementById('results')!.textContent).toContain('Confirm the exact part');
 document.getElementById('export')!.click();
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('export','{}');
 receive('disconnected',{});
 expect(document.getElementById('results')!.children.length).toBe(0);
 expect(document.getElementById('session')!.hidden).toBe(true);
});
test('busy requests disable actions but always allow disconnect',()=>{
 receive('busy',{busy:true});
 expect((document.getElementById('compare') as HTMLButtonElement).disabled).toBe(true);
 expect((document.getElementById('disconnect') as HTMLButtonElement).disabled).toBe(false);
 document.getElementById('disconnect')!.click();
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('disconnect','{}');
});

test('AI search uses scoped source and distinguishes stock from uncertain specifications',()=>{
 receive('connected',{inventory_name:'Lab',workspace_name:'Team'});
 (document.getElementById('query') as HTMLInputElement).value='Find 12 bearings for an 8mm shaft';
 document.getElementById('search')!.dispatchEvent(new Event('submit',{cancelable:true}));
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('search',JSON.stringify({query:'Find 12 bearings for an 8mm shaft',source:'inventory'}));
 receive('search',{source:'inventory',interpreted:{terms:['bearing'],constraints:['8mm']},notice:'Check compatibility.',truncated:false,
  items:[{item_id:'a',name:'Bearing',available:3,on_hand:5,reserved:2,checked_out:0,availability_known:true,requested_quantity:12,shortage_for_request:9,
   search_evidence:{matched_terms:['bearing'],unverified_constraints:['8mm']}}],total:1});
 expect(document.getElementById('parts')!.textContent).toContain('9 short for this record');
 expect(document.getElementById('parts')!.textContent).toContain('Not established by saved records: 8mm');
 expect(document.getElementById('search-explanation')!.textContent).toContain('AI searched: bearing');
});
test('Fusion model insertion requires confirmation without requesting a local path',()=>{
 receive('connected',{inventory_name:'Lab',workspace_name:'Team'});
 receive('models',{part_id:'bearing',part_name:'Bearing',mode:'project',folder:'Parts',note:'Copy model',parent:null,folder_id:'folder',offset:0,next_offset:null,folders:[],
  models:[{id:'opaque',name:'Bearing geometry',source:'Fusion project',version:2}]});
 const button=document.querySelector<HTMLButtonElement>('[data-model-insert]')!;
 expect(button.disabled).toBe(true);
 const checkbox=document.querySelector<HTMLInputElement>('#model-entries input')!;
 checkbox.checked=true;checkbox.dispatchEvent(new Event('change'));
 expect(button.disabled).toBe(false);button.click();
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('insert_model',JSON.stringify({id:'bearing',model_id:'opaque',confirmed:true}));
 receive('busy',{busy:true});expect(button.disabled).toBe(true);
 receive('disconnected',{});expect(document.getElementById('model-entries')!.children.length).toBe(0);
});
test('keyword mode remains available when AI is unavailable',()=>{
 receive('connected',{inventory_name:'Lab',workspace_name:'Team'});
 (document.getElementById('search-mode') as HTMLSelectElement).value='keyword';
 (document.getElementById('query') as HTMLInputElement).value='REV-21-1650';
 document.getElementById('search')!.dispatchEvent(new Event('submit',{cancelable:true}));
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('inventory',JSON.stringify({q:'REV-21-1650',offset:0}));
});

test('design questions open the real BOM view and clear old results',()=>{
 receive('connected',{inventory_name:'Lab',workspace_name:'Team'});
 document.getElementById('results')!.textContent='Old design';
 receive('comparison_started',{name:'Current robot'});
 expect(document.getElementById('browser')!.hidden).toBe(true);
 expect(document.getElementById('bom')!.hidden).toBe(false);
 expect(document.getElementById('bom-tab')!.getAttribute('aria-pressed')).toBe('true');
 expect(document.getElementById('results')!.textContent).toBe('');
 expect(document.getElementById('message')!.textContent).toContain('Comparing Current robot');
});
test('vague AI questions show clarification without claiming no parts exist',()=>{
 receive('search',{intent:'clarify',notice:'Name a part or ask about the current design.'});
 expect(document.getElementById('search-explanation')!.textContent).toContain('Name a part');
 expect(document.getElementById('parts')!.textContent).not.toContain('No matching parts');
 expect((document.getElementById('next') as HTMLButtonElement).disabled).toBe(true);
});

test('generation retries preserve request identity and insertion requires explicit review',()=>{
 receive('connected',{inventory_name:'Lab',allow_cad_writes:true,generation_enabled:true,saved_bom_enabled:true});
 (document.getElementById('generation-name') as HTMLInputElement).value='Plate';
 (document.getElementById('generation-prompt') as HTMLTextAreaElement).value='60 x 40 x 5 mm plate';
 const submit=()=>document.getElementById('generation-form')!.dispatchEvent(new Event('submit',{cancelable:true}));
 host.adsk.fusionSendData.mockClear(); submit(); expect(host.adsk.fusionSendData).not.toHaveBeenCalled();
 (document.getElementById('generation-consent') as HTMLInputElement).checked=true;
 submit(); const first=host.adsk.fusionSendData.mock.calls[0]; submit();
 expect(host.adsk.fusionSendData.mock.calls[1]).toEqual(first);
 expect(first[0]).toBe('generate'); expect(JSON.parse(first[1]).request_id).toMatch(/^[a-f0-9-]{36}$/);
 receive('generation_job',{id:'job',name:'Plate',state:'succeeded'});
 const insert=document.querySelector<HTMLButtonElement>('[data-generated-insert]')!;
 expect(insert.disabled).toBe(true); receive('busy',{busy:false}); expect(insert.disabled).toBe(true);
 const check=document.querySelector<HTMLInputElement>('#generation-job input')!;
 check.checked=true;check.dispatchEvent(new Event('change'));insert.click();
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('generation_insert',JSON.stringify({id:'job',confirmed:true}));
 receive('busy',{busy:true});expect(insert.disabled).toBe(true);
});

test('read-only sessions cannot submit generation or save BOMs and disconnect clears jobs',()=>{
 receive('connected',{inventory_name:'Lab',allow_cad_writes:false});
 expect((document.getElementById('save-version') as HTMLButtonElement).disabled).toBe(true);
 expect((document.getElementById('generation-submit') as HTMLButtonElement).disabled).toBe(true);
 receive('generation_job',{id:'job',name:'Plate',state:'needs_input',version:3,question:{id:'q',text:'Thickness?'}});
 expect((document.querySelector('#generation-job button[data-cad-write]') as HTMLButtonElement).disabled).toBe(true);
 receive('disconnected',{});expect(document.getElementById('generation-job')!.textContent).toBe('');
});


test('server capability flags disable unavailable features even for editors',()=>{
 receive('connected',{inventory_name:'Lab',allow_cad_writes:true,generation_enabled:false,saved_bom_enabled:false});
 for (const id of ['generation-submit','generation-history','save-version','load-versions']) expect((document.getElementById(id) as HTMLButtonElement).disabled).toBe(true);
 expect(document.getElementById('generation-note')!.textContent).toContain('unavailable on this server');
});
test('errors remain visible after a request unlocks the controls',()=>{
 receive('busy',{busy:true}); receive('error',{message:'Connection failed. Try again.'}); receive('busy',{busy:false});
 expect(document.getElementById('message')!.dataset.kind).toBe('error');
 expect(document.getElementById('message')!.textContent).toContain('Connection failed');
 expect(document.getElementById('message')!.compareDocumentPosition(document.getElementById('session')!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
});
