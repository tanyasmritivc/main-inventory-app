import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch
from fastapi import HTTPException

from app.services.catalog_service import (
    barcode_candidates, link_verified_barcode_alias, save_to_catalog,
)
from app.services.inventory_scope import InventoryScope, scoped_client, current_inventory


class CatalogBarcodeAliasTests(unittest.TestCase):
    def test_upca_ean_and_gtin_are_equivalent_without_losing_real_zero(self):
        self.assertEqual(barcode_candidates('0841298115072'),
                         ['0841298115072', '841298115072', '00841298115072'])
        self.assertEqual(barcode_candidates('841298115072'),
                         ['841298115072', '0841298115072', '00841298115072'])
        self.assertEqual(barcode_candidates('00841298115072'),
                         ['00841298115072', '841298115072', '0841298115072'])
        self.assertEqual(barcode_candidates('0012345678905'),
                         ['0012345678905', '012345678905', '00012345678905'])

    def test_sku_and_nonzero_gtin_are_not_rewritten(self):
        for value in ('3802-0102-0300', '1234567890123', '12345678901234'):
            self.assertEqual(barcode_candidates(value), [value])

    @patch('app.services.catalog_service.get_supabase_admin')
    def test_alias_uses_transaction_and_only_accepts_true_receipt(self, admin):
        for receipt, accepted in ((True, True), (False, False), (None, False), ({'ok': True}, False)):
            with self.subTest(receipt=receipt):
                admin.return_value.rpc.return_value.execute.return_value.data = receipt
                self.assertIs(link_verified_barcode_alias(barcode=' label ', catalog_id='verified-id'), accepted)
                admin.return_value.rpc.assert_called_with('findez_link_verified_barcode_alias', {
                    'p_barcode': 'label', 'p_catalog_id': 'verified-id',
                })
        admin.return_value.table.assert_not_called()

    @patch('app.services.catalog_service.get_supabase_admin')
    def test_optional_learning_drops_authoritative_and_private_fields(self, admin):
        admin.return_value.rpc.return_value.execute.return_value.data = True
        self.assertTrue(save_to_catalog('new-code', {
            'name': 'User label', 'brand': 'Brand', 'quantity': 9, 'location': 'Private bench',
            'verification_status': 'verified', 'catalog_id': 'forged', 'source': 'manufacturer',
        }))
        admin.return_value.rpc.assert_called_once_with('findez_save_community_catalog', {
            'p_barcode': 'new-code', 'p_source': 'user',
            'p_data': {'name': 'User label', 'brand': 'Brand', 'category': None,
                       'subcategory': None, 'part_number': None},
        })
        admin.return_value.table.assert_not_called()

    @patch('app.services.catalog_service.get_supabase_admin')
    def test_catalog_rejection_or_outage_never_falls_back_to_direct_writes(self, admin):
        admin.return_value.rpc.return_value.execute.return_value.data = False
        self.assertFalse(save_to_catalog('known-code', {'name': 'Correction'}))
        admin.return_value.rpc.side_effect = RuntimeError('private upstream detail')
        with self.assertLogs('app.services.catalog_service', level='WARNING') as logs:
            self.assertFalse(save_to_catalog('new-code', {'name': 'Correction'}))
        self.assertNotIn('private upstream detail', ''.join(logs.output))
        admin.return_value.table.assert_not_called()

    @patch('app.services.catalog_service.get_supabase_admin')
    def test_empty_catalog_input_does_not_contact_database(self, admin):
        self.assertFalse(save_to_catalog('', {'name': 'Label'}))
        self.assertFalse(save_to_catalog('code', {}))
        self.assertFalse(link_verified_barcode_alias(barcode=' ', catalog_id='id'))
        self.assertFalse(link_verified_barcode_alias(barcode='code', catalog_id=''))
        admin.assert_not_called()

    def test_scoped_viewer_can_use_only_the_two_validated_global_catalog_transactions(self):
        raw = Mock()
        raw.rpc.return_value.execute.return_value = SimpleNamespace(data=True)
        token = current_inventory.set(InventoryScope('inventory', 'actor', 'owner', None, 'viewer'))
        try:
            client = scoped_client(raw)
            with patch('app.services.catalog_service.get_supabase_admin', return_value=client):
                self.assertTrue(link_verified_barcode_alias(barcode='label', catalog_id='verified-id'))
                self.assertTrue(save_to_catalog('new-code', {'name': 'Label'}))
            with self.assertRaises(HTTPException) as rejected:
                client.rpc('unapproved_global_write', {})
            self.assertEqual(rejected.exception.status_code, 403)
            self.assertEqual(raw.rpc.call_count, 2)
        finally:
            current_inventory.reset(token)


if __name__ == '__main__':
    unittest.main()
