import { purchaseSource, purchaseLink } from '@/lib/purchase-source';
import type { InventoryItem } from '@/lib/api';
const item = (source:string, fields: {name:string,value:string}[] = []) => ({purchase_source:source,import_data:{fields}} as InventoryItem);
test('numeric vendor codes remain original fields, not purchasing destinations',()=>{
 expect(purchaseSource(item('0012'))).toBeNull();
 expect(purchaseSource(item('PART-12',[{name:'Vendor Part #',value:'PART-12'}]))).toBeNull();
 expect(purchaseSource(item('Acme Supplies'))).toBe('Acme Supplies');
 expect(purchaseSource(item('https://shop.example/part/0012'))).toBe('https://shop.example/part/0012');
 expect(purchaseLink('javascript:alert(1)')).toBeNull();
 expect(purchaseLink('https://shop.example/part/0012')).toBe('https://shop.example/part/0012');
});
