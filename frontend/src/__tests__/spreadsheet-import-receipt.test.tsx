/** @jest-environment jsdom */
import {render,screen,fireEvent} from '@testing-library/react';
import {SpreadsheetImportModal} from '@/components/site/spreadsheet-import-modal';
import {importSpreadsheet} from '@/lib/api';
const push=jest.fn();
jest.mock('@/components/site/inventory-link',()=>({useInventoryRouter:()=>({push})}));
jest.mock('@/components/ui/dialog',()=>({DialogClose:({children}:{children:React.ReactNode})=><>{children}</>}));
jest.mock('@/lib/api',()=>({importSpreadsheet:jest.fn()}));
beforeEach(()=>jest.clearAllMocks());
function upload(){const onSuccess=jest.fn();const {container}=render(<SpreadsheetImportModal spaceName="QA Shelf" token="test" onSuccess={onSuccess}/>);fireEvent.change(container.querySelector('input[type=file]')!,{target:{files:[new File(['name\nWasher'],'qa.csv')]}});return onSuccess;}
test('partial import explains missing rows and View Items opens the destination',async()=>{
 jest.mocked(importSpreadsheet).mockResolvedValue({inserted:2,failures:1});const success=upload();
 expect(await screen.findByText('Import partially completed')).toBeTruthy();expect(screen.getByRole('alert').textContent).toContain('1 rows were not saved');expect(success).toHaveBeenCalledWith(2);
 fireEvent.click(screen.getByRole('button',{name:'View Items'}));expect(push).toHaveBeenCalledWith('/inventory?space=QA%20Shelf');
});
test('malformed receipt never claims success',async()=>{jest.mocked(importSpreadsheet).mockResolvedValue({} as never);const success=upload();expect(await screen.findByRole('alert')).toBeTruthy();expect(success).not.toHaveBeenCalled();expect(screen.queryByText('Import complete!')).toBeNull();});
