import io
import json
from types import SimpleNamespace
from unittest.mock import patch

import openpyxl

from app.services.spreadsheet_import import build_import_items, parse_import_tables
from app.services import items_repo


def parse(raw, name):
    return build_import_items(parse_import_tables(raw, name), filename=name, location='Cabinet')


def test_workbook_maps_each_sheet_and_preserves_duplicate_and_blank_headers():
    workbook = openpyxl.Workbook()
    sheet = workbook.active
    sheet.append([8, 'Shaft', '   ', 'Screw Length', 'Description', 'Vendor Part #', 'Vendor Name', 'Quantity'])
    sheet.append(['PN-F1', 'Screw', 'M2', 12, 'M2 screw', '0012', 'Acme', 0])
    belts = workbook.create_sheet('5mm Timing Belts')
    belts.append(['Tooth Count', 'Length', 'Quantity'])
    belts.append([43, None, 16])
    stream = io.BytesIO()
    workbook.save(stream)
    items = parse(stream.getvalue(), 'parts.xlsx')
    assert len(items) == 2
    assert items[0]['quantity'] == 0
    assert items[0]['part_number'] == 'PN-F1'
    assert items[0]['purchase_source'] is None  # Vendor part numbers are not purchasing destinations.
    assert items[0]['brand'] == 'Acme'
    assert items[0]['import_data']['fields'] == [
        {'name': '8', 'value': 'PN-F1'}, {'name': 'Shaft', 'value': 'Screw'},
        {'name': '   ', 'value': 'M2'}, {'name': 'Screw Length', 'value': 12},
        {'name': 'Description', 'value': 'M2 screw'}, {'name': 'Vendor Part #', 'value': '0012'},
        {'name': 'Vendor Name', 'value': 'Acme'}, {'name': 'Quantity', 'value': 0},
    ]
    assert items[1]['name'] == '5mm Timing Belts - Tooth Count 43'
    assert items[1]['quantity'] == 16
    assert items[1]['import_data']['fields'][1] == {'name': 'Length', 'value': None}


def test_csv_keeps_order_exact_labels_whitespace_duplicate_and_unnamed_values():
    row = parse(b'Name, Exact Label ,Size,Size,,Qty\nBolt,  keep spaces  ,M2,12,blue,3\n', 'parts.csv')[0]
    assert row['import_data']['fields'] == [
        {'name': 'Name', 'value': 'Bolt'}, {'name': ' Exact Label ', 'value': '  keep spaces  '},
        {'name': 'Size', 'value': 'M2'}, {'name': 'Size', 'value': '12'},
        {'name': '', 'value': 'blue'}, {'name': 'Qty', 'value': '3'},
    ]


def test_json_retains_objects_arrays_false_zero_null_and_later_keys():
    rows = [{'Name': 'Sensor', 'Specs': {'voltage': 0, 'active': False}, 'Ports': ['A', 'B'], '備考': None},
            {'Name': 'Relay', 'Only on row two': '0012'}]
    items = parse(json.dumps(rows).encode(), 'parts.json')
    fields = items[0]['import_data']['fields']
    assert fields[1]['value'] == rows[0]['Specs']
    assert fields[2]['value'] == ['A', 'B']
    assert fields[3] == {'name': '備考', 'value': None}
    assert items[1]['import_data']['fields'][-1] == {'name': 'Only on row two', 'value': '0012'}


class MemoryItems:
    def __init__(self):
        self.rows = []

    def table(self, name):
        assert name == 'items'
        self.pending = None
        self.owner = None
        return self

    def insert(self, rows):
        self.pending = json.loads(json.dumps(rows))
        return self

    def select(self, columns):
        assert columns == '*'
        return self

    def eq(self, field, value):
        assert field == 'user_id'
        self.owner = value
        return self

    def order(self, *args, **kwargs):
        return self

    def execute(self):
        if self.pending is not None:
            self.rows.extend(self.pending)
            return SimpleNamespace(data=self.pending)
        return SimpleNamespace(data=[r for r in self.rows if r['user_id'] == self.owner])


def test_distinct_source_fields_survive_save_reload_without_name_only_merging():
    items = parse(b'Name,Thread,Qty\nBolt,M2,3\nBolt,M3,5\n', 'parts.csv')
    store = MemoryItems()
    items_repo.invalidate_inventory_cache('import-owner')
    items_repo.invalidate_inventory_cache('other-owner')
    with (
        patch.object(items_repo, 'get_supabase_admin', return_value=store),
        patch.object(items_repo, '_resolve_space_id', return_value=None),
        patch('app.services.catalog_service.verified_catalog_id_for_identity', return_value=None),
    ):
        saved, failures = items_repo.bulk_create_items(user_id='import-owner', items=items)
        assert not failures
        assert len(saved) == 2
        reloaded = items_repo.list_items(user_id='import-owner')
        assert [r['import_data'] for r in reloaded] == [r['import_data'] for r in items]
        assert [r['quantity'] for r in reloaded] == [3, 5]
        assert items_repo.list_items(user_id='other-owner') == []
    items_repo.invalidate_inventory_cache('import-owner')
    items_repo.invalidate_inventory_cache('other-owner')
