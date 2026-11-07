/** @jest-environment jsdom */
import {render,screen,fireEvent,waitFor} from '@testing-library/react';
import {SpreadsheetImportModal} from '@/components/site/spreadsheet-import-modal';
import {apiRequest} from '@/lib/api';
jest.mock('@/components/site/inventory-link',()=>({useInventoryRouter:()=>({push:jest.fn()})}));
jest.mock('@/lib/api',()=>({apiRequest:jest.fn()}));
beforeEach(()=>jest.clearAllMocks());
function upload(){const onSuccess=jest.fn();render(<SpreadsheetImportModal spaceName="QA Shelf" spaceId="qa-space" token="test" onSuccess={onSuccess}/>);fireEvent.change(screen.getByLabelText('Choose spreadsheet'),{target:{files:[new File(['name\nWasher'],'qa.csv')]}});return onSuccess;}
test('inventory modal imports directly to its Space and reports verified completion',async()=>{
 jest.mocked(apiRequest).mockResolvedValueOnce({id:'session',status:'review',counts:{total:2,imported:0,pending:2,failed:0,skipped:0}}).mockResolvedValueOnce({id:'session',status:'complete',counts:{total:2,imported:2,pending:0,failed:0,skipped:0}});
 const success=upload();await waitFor(()=>expect(success).toHaveBeenCalledWith(2));expect(apiRequest).toHaveBeenCalledWith('/connectors/imports/session/import',expect.objectContaining({method:'POST',token:'test'}));
});
test('malformed receipt never claims success',async()=>{jest.mocked(apiRequest).mockResolvedValue({});const success=upload();expect(await screen.findByRole('alert')).toBeTruthy();expect(success).not.toHaveBeenCalled();});
