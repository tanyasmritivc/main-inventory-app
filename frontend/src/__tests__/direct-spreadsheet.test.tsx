/** @jest-environment jsdom */
import {StrictMode} from 'react';
import {render, screen, fireEvent, waitFor} from '@testing-library/react';
import {DirectSpreadsheetImport} from '@/components/site/direct-spreadsheet-import';
const counts = (n:number, pending=0) => ({imported:n,failed:0,skipped:0,pending,total:n+pending});
test('selected file imports immediately into the fixed Space with no review and no duplicate upload', async()=>{
 const request=jest.fn().mockResolvedValueOnce({id:'s',status:'review',counts:counts(0,2)}).mockResolvedValueOnce({id:'s',status:'importing',counts:counts(1,1)}).mockResolvedValueOnce({id:'s',status:'complete',counts:counts(2)});
 const done=jest.fn();
 render(<StrictMode><DirectSpreadsheetImport spaceName="Garage" spaceId="space-a" initialFile={new File(['Name,Qty\nA,1'],'a.csv')} request={request} onSuccess={done}/></StrictMode>);
 await waitFor(()=>expect(done).toHaveBeenCalledWith(2));
 expect(request).toHaveBeenCalledTimes(3);
 const form=request.mock.calls[0][1] as FormData;
 expect(form.get('space_id')).toBe('space-a');expect(form.get('direct')).toBe('true');
 expect(request.mock.calls[1][0]).toBe('/connectors/imports/s/import');
 expect(screen.queryByText('Review')).toBeNull();
});
test('lost response resumes the same session and never claims success early',async()=>{
 const request=jest.fn().mockResolvedValueOnce({id:'s',status:'review',counts:counts(0,2)}).mockRejectedValueOnce(new Error('Connection interrupted')).mockResolvedValueOnce({id:'s',status:'complete',counts:counts(2)});
 const done=jest.fn();render(<DirectSpreadsheetImport spaceName="Garage" request={request} onSuccess={done}/>);
 fireEvent.change(screen.getByLabelText('Choose spreadsheet'),{target:{files:[new File(['[]'],'a.json')]}});
 await screen.findByRole('alert');expect(done).not.toHaveBeenCalled();
 fireEvent.click(screen.getByRole('button',{name:'Resume import'}));await waitFor(()=>expect(done).toHaveBeenCalledWith(2));
 expect(request.mock.calls.filter(c=>c[0]==='/connectors/imports')).toHaveLength(1);
});
test('partial and malformed receipts cannot claim completion',async()=>{
 const done=jest.fn();const request=jest.fn().mockResolvedValueOnce({id:'s',status:'review',counts:counts(0,2)}).mockResolvedValueOnce({id:'s',status:'complete',counts:{...counts(1),total:2,failed:1}});
 render(<DirectSpreadsheetImport spaceName="Garage" request={request} onSuccess={done}/>);
 fireEvent.change(screen.getByLabelText('Choose spreadsheet'),{target:{files:[new File(['Name\nA'],'a.csv')]}});
 expect((await screen.findByRole('alert')).textContent).toContain('1 items saved');expect(done).not.toHaveBeenCalled();
});
