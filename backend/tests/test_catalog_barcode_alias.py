import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.services.catalog_service import link_verified_barcode_alias


class _Query:
    def __init__(self, tables, name, operation="select", payload=None):
        self.tables = tables
        self.name = name
        self.operation = operation
        self.payload = payload
        self.filters = []

    def select(self, *_args):
        return self

    def insert(self, payload):
        return _Query(self.tables, self.name, "insert", payload)

    def eq(self, field, value):
        self.filters.append((field, value))
        return self

    def limit(self, _value):
        return self

    def execute(self):
        rows = self.tables[self.name]
        if self.operation == "insert":
            rows.append(dict(self.payload))
            return SimpleNamespace(data=[dict(self.payload)])
        matches = [
            dict(row)
            for row in rows
            if all(row.get(field) == value for field, value in self.filters)
        ]
        return SimpleNamespace(data=matches)


class _Client:
    def __init__(self, tables):
        self.tables = tables

    def table(self, name):
        return _Query(self.tables, name)


class CatalogBarcodeAliasTests(unittest.TestCase):
    @patch("app.services.catalog_service.get_supabase_admin")
    def test_confirmed_label_adds_alias_to_verified_catalog_row(self, admin) -> None:
        tables = {
            "parts_catalog": [],
            "part_catalog_barcodes": [],
        }
        admin.return_value = _Client(tables)

        self.assertTrue(link_verified_barcode_alias(barcode=" 12345 ", catalog_id="known"))
        self.assertEqual(tables["part_catalog_barcodes"], [{
            "barcode": "12345",
            "catalog_id": "known",
            "source": "user_confirmed_label",
        }])

    @patch("app.services.catalog_service.get_supabase_admin")
    def test_confirmed_label_never_steals_existing_alias(self, admin) -> None:
        tables = {
            "parts_catalog": [],
            "part_catalog_barcodes": [{"barcode": "12345", "catalog_id": "first"}],
        }
        admin.return_value = _Client(tables)

        self.assertFalse(link_verified_barcode_alias(barcode="12345", catalog_id="second"))
        self.assertEqual(tables["part_catalog_barcodes"][0]["catalog_id"], "first")


if __name__ == "__main__":
    unittest.main()
