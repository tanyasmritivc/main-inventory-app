import { isInventoryPage } from '@/lib/inventory-selection';
test.each(['/inventory/connect','/inventory/connect/','/inventory/connect?inventory=old-id','/settings/connections'])('Connections route %s needs no inventory',path=>expect(isInventoryPage(path)).toBe(false));
test.each(['/inventory','/inventory/item','/inventory-access','/spaces','/scan'])('inventory route %s still requires inventory',path=>expect(isInventoryPage(path)).toBe(true));
