import { escapeLabel, itemLabel, labelImage } from '@/lib/item-label';
import { selectInventory } from '@/lib/inventory-selection';
import type { InventoryItem } from '@/lib/api';
const item={item_id:'item-id',name:'5mm Timing Belts - Tooth Count 120.0',location:'Fastener DB',quantity:1} as InventoryItem;
afterEach(()=>selectInventory(null));
test('item label preserves the selected inventory in the QR destination',()=>{
 selectInventory({inventory_id:'inventory-id'} as never);
 expect(itemLabel(item).data).toBe('https://findez.ai/inventory?item=item-id&inventory=inventory-id');
 expect(itemLabel(item).details).toEqual(['Qty: 1']);
});
test('SVG label keeps long titles, whitespace and markup safe with a scalable QR quiet zone',async()=>{
 const svg=await labelImage({...itemLabel(item),title:'<script>alert("x")</script> '+ 'W'.repeat(200)});
 expect(svg).not.toContain('<script>'); expect(svg).toContain('&lt;script&gt;');
 expect(svg).toContain('FindEZ AI'); expect(svg).toContain('findez.ai');
 expect(svg).toContain('width="680"'); expect(svg.match(/<text /g)!.length).toBeGreaterThan(10);
 expect(escapeLabel('a&b"<>')).toBe('a&amp;b&quot;&lt;&gt;');
});
