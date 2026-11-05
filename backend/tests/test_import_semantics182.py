import json
from copy import deepcopy
from app.services.spreadsheet_import import correct_legacy_purchase_source, infer_import_mapping
from app.services.connector_tables import parse_source, review_table
from app.schemas.inventory import ImportData


def test_proven_legacy_identifier_is_not_a_purchase_destination():
    item = {'purchase_source': '3405-0005-0214', 'import_data': {'fields': [
        {'name': 'Vendor Part #', 'value': '3405-0005-0214'},
        {'name': 'Vendor Name', 'value': 'Gobilda'}]}}
    original = deepcopy(item)
    corrected = correct_legacy_purchase_source(item)
    assert corrected['purchase_source'] is None
    assert corrected['import_data'] == original['import_data']
    assert item == original
    for source in ('https://example.com/part', 'Local shop', None):
        assert correct_legacy_purchase_source({**item, 'purchase_source': source})['purchase_source'] == source
    item['import_data']['fields'].append({'name': 'Where to buy', 'value': item['purchase_source']})
    assert correct_legacy_purchase_source(item) == item
    assert correct_legacy_purchase_source({'purchase_source': '0012'}) == {'purchase_source': '0012'}


def test_duplicate_semantic_columns_are_not_silently_chosen():
    mapping = infer_import_mapping(['Name', 'Vendor Part #', 'Purchase URL', 'Purchase URL'])
    assert mapping['purchase_source_column'] is None
    assert infer_import_mapping(['Name', 'Vendor Part #'])['purchase_source_column'] is None


def test_json_review_keeps_every_typed_custom_column_without_misrouting():
    source = [{'Name': 'Pulley', 'Vendor Part #': '0012', 'Torque rating': 0,
               'Properties': {'coated': False}, 'Ports': ['A', 'B'], '空欄': None},
              {'Name': 'Belt', 'Extra': 'second row'}]
    table = parse_source(json.dumps(source).encode(), 'parts.json', 'application/json')[0]
    assert 'purchase_source' not in table['suggested_mapping']
    rows = review_table(table, filename='parts.json', columns=table['suggested_mapping'],
                        defaults={'category':'Supplies', 'location':'Storage', 'quantity':1},
                        inventory=[], locations=[{'id':'s', 'name':'Storage'}])
    assert all(not row['errors'] for row in rows)
    fields = rows[0]['item']['import_data']['fields']
    assert [f['name'] for f in fields] == list(dict.fromkeys(k for row in source for k in row))
    assert fields[1]['value'] == '0012'
    assert fields[3]['value'] == {'coated': False}
    assert fields[4]['value'] == ['A', 'B']
    assert ImportData.model_validate(rows[0]['item']['import_data']).fields[3].value == {'coated': False}
