import asyncio
import io
import json
import unittest
from unittest.mock import AsyncMock, patch

import openpyxl
from fastapi import UploadFile

from app.api.routes.imports import import_spreadsheet_route
from app.core.auth import AuthenticatedUser
from app.services.spreadsheet_import import infer_import_mapping, parse_import_tables


class TestSpreadsheetImportFormats(unittest.TestCase):
    def test_csv_bom_and_common_headers_map_without_a_gateway(self):
        tables = parse_import_tables(
            b'\xef\xbb\xbfPart #,Description,Qty,Vendor\nPN-F17,0-80 Screw,50,Acme\n',
            'parts.csv',
        )
        self.assertEqual(tables[0]['rows'][0], ['PN-F17', '0-80 Screw', '50', 'Acme'])
        mapping = infer_import_mapping(tables[0]['headers'])
        self.assertEqual(mapping['name_columns'], ['Description'])
        self.assertEqual(mapping['part_number_column'], 'Part #')
        self.assertEqual(mapping['quantity_column'], 'Qty')
        self.assertEqual(mapping['brand_column'], 'Vendor')

    def test_xlsx_reads_rows_and_maps_fields_locally(self):
        workbook = openpyxl.Workbook()
        sheet = workbook.active
        sheet.append(['Name', 'Quantity', 'Category'])
        sheet.append(['Screwdriver', 2, 'Tools'])
        stream = io.BytesIO()
        workbook.save(stream)

        tables = parse_import_tables(stream.getvalue(), 'items.xlsx')

        self.assertEqual(tables[0]['rows'], [['Screwdriver', '2', 'Tools']])
        self.assertEqual(infer_import_mapping(tables[0]['headers'])['name_columns'], ['Name'])

    def test_json_accepts_inventory_objects(self):
        raw = json.dumps({'items': [
            {'name': 'Screwdriver', 'quantity': 2},
            {'name': 'Wrench', 'quantity': 1},
        ]}).encode()

        tables = parse_import_tables(raw, 'items.json')

        self.assertEqual(len(tables[0]['rows']), 2)
        self.assertEqual(infer_import_mapping(tables[0]['headers'])['name_columns'], ['name'])

    def test_json_rejects_unstructured_values(self):
        with self.assertRaisesRegex(ValueError, 'list of inventory objects'):
            parse_import_tables(b'{"items": ["not an object"]}', 'items.json')


if __name__ == '__main__':
    unittest.main()


def test_import_common_csv_does_not_wait_for_gateway():
    upload = UploadFile(
        filename='parts.csv',
        file=io.BytesIO(b'Part #,Description,Qty\nPN-F17,0-80 Screw,50\n'),
    )
    with (
        patch('app.api.routes.imports.gateway_completion') as gateway,
        patch('app.api.routes.imports.check_and_increment_import'),
        patch('app.api.routes.imports.check_limit', new_callable=AsyncMock) as limit,
        patch('app.api.routes.imports.increment_usage', new_callable=AsyncMock),
        patch('app.api.routes.imports.bulk_create_items') as bulk,
        patch('app.api.routes.imports.create_activity'),
    ):
        limit.return_value = {'allowed': True}
        bulk.return_value = ([{'item_id': 'item-1'}], [])
        result = asyncio.run(
            import_spreadsheet_route.__wrapped__(
                request=None,
                file=upload,
                location='Fastener',
                share_id=None,
                user=AuthenticatedUser(user_id='user-1'),
            )
        )

    gateway.assert_not_called()
    self_items = bulk.call_args.kwargs['items']
    assert self_items[0]['name'] == '0-80 Screw'
    assert self_items[0]['part_number'] == 'PN-F17'
    assert self_items[0]['quantity'] == 50
    assert result['inserted'] == 1
