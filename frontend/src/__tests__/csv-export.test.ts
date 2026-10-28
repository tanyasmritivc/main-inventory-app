import {csvCell} from '@/lib/csv-export';
test.each(['=1+1','+SUM(A1:A2)','-1+1','@SUM(A1)','\t=1+1','\r=1+1','\n=1+1','\0=1+1','  =1+1','＝1+1','＋1','－1','＠SUM(A1)'])('export treats %j as text', value => {
  expect(csvCell(value)).toBe(`"'${value}"`);
});
test('CSV escaping preserves separators, quotes, newlines and numeric values',()=>{
  expect(csvCell('part,"quoted"\nline')).toBe('"part,""quoted""\nline"');
  expect(csvCell(0)).toBe('"0"');expect(csvCell(-4)).toBe('"-4"');expect(csvCell(null)).toBe('""');expect(csvCell('QA-001')).toBe('"QA-001"');
});
