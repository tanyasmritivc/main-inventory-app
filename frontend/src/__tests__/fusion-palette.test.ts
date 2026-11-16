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
 expect(host.adsk.fusionSendData).toHaveBeenLastCalledWith('insert',JSON.stringify({id:'owned'}));
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
