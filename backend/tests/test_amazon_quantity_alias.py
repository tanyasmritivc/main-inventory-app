"""Synthetic purchase exports only; no application server or database required."""
import csv
import io
import json
import unittest
import zipfile

from fastapi import HTTPException
from app.services.commerce.purchase_import import preview


def sample(column='Original Quantity', quantity='2', status='Shipped'):
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(['Order ID', 'Product Name', column, 'Order Date', 'ASIN', 'Billing Address', 'Payment Method Type', 'Order Status'])
    writer.writerow(['synthetic-order-1', 'Sample motor', quantity, '2026-11-01T12:00:00Z', 'B000000001', 'PRIVATE ADDRESS', 'PRIVATE PAYMENT', status])
    return output.getvalue().encode()


class AmazonQuantityAliasesTest(unittest.TestCase):
    def test_current_and_legacy_quantity_columns(self):
        for column in ['Original Quantity', 'Quantity', 'Quantity Ordered']:
            with self.subTest(column=column):
                result = preview(sample(column))
                self.assertEqual(result['count'], 1)
                self.assertEqual(result['records'][0]['quantity'], 2)
                self.assertEqual(result['stock_effect'], 'none')
                self.assertNotIn('PRIVATE', json.dumps(result))

    def test_nested_current_amazon_zip(self):
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('Your Orders/Your Amazon Orders/Order History.csv', sample())
        self.assertEqual(preview(output.getvalue())['count'], 1)

    def test_invalid_original_quantities_remain_rejected(self):
        for quantity in ['-1', '1.5', 'invalid']:
            with self.subTest(quantity=quantity):
                with self.assertRaises(HTTPException) as raised:
                    preview(sample(quantity=quantity))
                self.assertEqual(raised.exception.status_code, 422)

    def test_zero_quantity_rows_are_preserved(self):
        for status, expected in [('Cancelled', 'cancelled'), ('Closed', 'unknown')]:
            with self.subTest(status=status):
                result = preview(sample(quantity='0', status=status))
                self.assertEqual(result['count'], 1)
                self.assertEqual(result['records'][0]['quantity'], 0)
                self.assertEqual(result['records'][0]['source_status'], expected)
                self.assertEqual(result['stock_effect'], 'none')

    def test_reimport_identity_is_stable(self):
        first, second = preview(sample()), preview(sample())
        self.assertEqual(first['sha256'], second['sha256'])
        self.assertEqual(first['records'][0]['external_id'], second['records'][0]['external_id'])


if __name__ == '__main__':
    unittest.main()
