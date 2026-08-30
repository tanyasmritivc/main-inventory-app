import unittest

from scripts.import_robotics_catalog import parse_product_page


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


if __name__ == "__main__":
    unittest.main()
