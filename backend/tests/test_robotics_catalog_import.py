import unittest
from types import SimpleNamespace
from unittest.mock import patch

from scripts.import_robotics_catalog import CatalogProduct, parse_product_page, upsert_product


PAGE = r'''
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":[
 {"item":{"name":"Home"}}, {"item":{"name":"ELECTRONICS"}},
 {"item":{"name":"Wiring"}}, {"item":{"name":"Cable"}}]}
</script>
<meta itemprop="weight" content="16g">
<meta itemprop="gtin" content="841298115072">
<script type="application/ld+json">
{"@type":"Product","name":"XT30 Extension","sku":"3802-0102-0300",
 "url":"https://www.gobilda.com/cable/","description":"Connector: XT30\nWire Gauge: 16 AWG"}
</script>
<script>var BCData = {"product_attributes":{"sku":"3802-0102-0300","upc":"841298115072"}};</script>
'''


class _Query:
    def __init__(self, database, table, operation="select", payload=None):
        self.database = database
        self.table = table
        self.operation = operation
        self.payload = payload
        self.filters = []

    def select(self, *_args):
        return self

    def insert(self, payload):
        return _Query(self.database, self.table, "insert", payload)

    def update(self, payload):
        return _Query(self.database, self.table, "update", payload)

    def eq(self, field, value):
        self.filters.append((field, value, False))
        return self

    def ilike(self, field, value):
        self.filters.append((field, value, True))
        return self

    def limit(self, _value):
        return self

    def _matches(self, row):
        for field, value, insensitive in self.filters:
            actual = row.get(field)
            if insensitive:
                if str(actual or "").lower() != str(value).lower():
                    return False
            elif actual != value:
                return False
        return True

    def execute(self):
        rows = self.database[self.table]
        if self.operation == "select":
            return SimpleNamespace(data=[dict(row) for row in rows if self._matches(row)])
        if self.operation == "insert":
            row = dict(self.payload)
            row.setdefault("catalog_id", f"catalog-{len(rows) + 1}")
            rows.append(row)
            return SimpleNamespace(data=[dict(row)])
        for row in rows:
            if self._matches(row):
                row.update(self.payload)
        return SimpleNamespace(data=[dict(row) for row in rows if self._matches(row)])


class _Client:
    def __init__(self, database):
        self.database = database

    def table(self, name):
        return _Query(self.database, name)


class RoboticsCatalogImportTests(unittest.TestCase):
    def test_parses_official_product_identity_and_barcode(self) -> None:
        product = parse_product_page(
            PAGE,
            brand="goBILDA",
            product_url="https://www.gobilda.com/cable/",
        )

        self.assertIsNotNone(product)
        assert product is not None
        self.assertEqual(product.part_number, "3802-0102-0300")
        self.assertEqual(product.barcode, "841298115072")
        self.assertEqual(product.category, "Electronics")
        self.assertEqual(product.subcategory, "Wiring")
        self.assertEqual(product.specifications["weight"], "16g")
        self.assertEqual(product.specifications["wire_gauge"], "16 AWG")

    def test_rejects_non_product_pages(self) -> None:
        self.assertIsNone(
            parse_product_page("<html></html>", brand="REV Robotics", product_url="https://example.com")
        )

    @patch("scripts.import_robotics_catalog.create_supabase_admin")
    def test_duplicate_upc_keeps_first_owner_and_imports_second_by_sku(self, admin) -> None:
        database = {
            "parts_catalog": [{
                "catalog_id": "first",
                "brand": "goBILDA",
                "part_number": "3118-0808-0001",
                "barcode": "841298139894",
                "verification_status": "verified",
            }],
            "part_catalog_barcodes": [{
                "barcode": "841298139894",
                "catalog_id": "first",
                "source": "manufacturer",
            }],
        }
        admin.return_value = _Client(database)
        product = CatalogProduct(
            brand="goBILDA",
            part_number="3118-0808-0003",
            name="Second LED variant",
            barcode="841298139894",
            category="Electronics",
            subcategory="Lights",
            description=None,
            image_url=None,
            product_url="https://www.gobilda.com/second-led/",
            specifications={},
        )

        self.assertEqual(upsert_product(product), "inserted")
        imported = database["parts_catalog"][1]
        self.assertEqual(imported["barcode"], "3118-0808-0003")
        self.assertEqual(database["part_catalog_barcodes"][0]["catalog_id"], "first")
        self.assertTrue(any(
            alias["barcode"] == "3118-0808-0003" and alias["catalog_id"] == imported["catalog_id"]
            for alias in database["part_catalog_barcodes"]
        ))


if __name__ == "__main__":
    unittest.main()
