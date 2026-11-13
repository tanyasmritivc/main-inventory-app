import { importedSheetFor, importedSheetCsv, importedCellText } from '@/lib/imported-spreadsheet';
import type { InventoryItem } from '@/lib/api';
const row: InventoryItem = { item_id:'1', name:'Part', quantity:99, category:'Supplies', location:'Shelf', created_at:'', import_data: {filename:'orders.xlsx',sheet:'Orders',fields:[{name:'SKU',value:'00123'},{name:'Qty',value:2},{name:'Status',value:'CANCELLED'},{name:'',value:null},{name:'Status',value:'processing'}]} };
test('keeps original columns, blanks, duplicate headings and ordered quantities independent of stock', () => {
 const sheet = importedSheetFor([row, {...row,item_id:'2'}])!;
 expect(sheet.headers).toEqual(['SKU','Qty','Status','','Status']);
 expect(importedSheetCsv(sheet,[row,{...row,item_id:'2'}])).toBe('"SKU","Qty","Status","","Status"\n"00123","2","CANCELLED","","processing"\n"00123","2","CANCELLED","","processing"');
 expect(row.quantity).toBe(99);
});
test('never presents mixed source schemas or manual rows under another sheet headers', () => {
 expect(importedSheetFor([])).toBeNull();
 expect(importedSheetFor([row,{...row,import_data:null}])).toBeNull();
 expect(importedSheetFor([row,{...row,import_data:{...row.import_data!,filename:'other.xlsx'}}])).toBeNull();
 expect(importedSheetFor([row,{...row,import_data:{...row.import_data!,fields:[{name:'Other',value:3}]}}])).toBeNull();
});
test('exports safely with original scalar types, multiline text and formula protection', () => {
 const item={...row,import_data:{filename:'x',sheet:'s',fields:[{name:'=heading',value:'=HYPERLINK("bad")'},{name:'Number',value:-2},{name:'Boolean',value:false},{name:'Notes',value:'a, b\nc'}]}};
 expect(importedSheetCsv(importedSheetFor([item])!,[item])).toBe('"\'=heading","Number","Boolean","Notes"\n"\'=HYPERLINK(""bad"")","-2","false","a, b\nc"');
 expect(importedCellText(0)).toBe('0');expect(importedCellText(false)).toBe('false');expect(importedCellText(null)).toBe('');
});
