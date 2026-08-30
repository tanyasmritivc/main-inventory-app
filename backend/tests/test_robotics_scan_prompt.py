import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.services.openai_service import (
    _MULTI_SCAN_SYSTEM_PROMPT,
    _MULTI_SCAN_USER_PROMPT,
)
from app.services.items_repo import _normalize_category
from app.services.catalog_service import enrich_scan_items_from_verified_catalog
from app.schemas.inventory import ExtractedInventoryItem


class _CatalogQuery:
    def __init__(self, rows: list[dict]):
        self.rows = rows

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, *_args, **_kwargs):
        return self

    def ilike(self, *_args, **_kwargs):
        return self

    def execute(self):
        return SimpleNamespace(data=self.rows)


class _CatalogClient:
    def __init__(self, rows: list[dict]):
        self.rows = rows

    def table(self, _name: str):
        return _CatalogQuery(self.rows)


class RoboticsScanPromptTests(unittest.TestCase):
    def test_multi_scan_prioritizes_robotics_identification(self) -> None:
        prompt = f"{_MULTI_SCAN_SYSTEM_PROMPT}\n{_MULTI_SCAN_USER_PROMPT}"

        self.assertIn("robotics", prompt.lower())
        self.assertIn("REV Robotics", prompt)
        self.assertIn("goBILDA", prompt)
        self.assertIn("part_number", prompt)
        self.assertIn("Robot Parts", prompt)

    def test_multi_scan_forbids_unverifiable_part_details(self) -> None:
        prompt = _MULTI_SCAN_SYSTEM_PROMPT.lower()


        self.assertIn("never invent", prompt)
        self.assertIn("compatibility claim", prompt)
        self.assertIn("return null", prompt)

    def test_robotics_categories_survive_bulk_create_normalization(self) -> None:
        expected = {
            "robot drivetrain": "Robot Parts",
            "fasteners": "Hardware",
            "aluminum extrusion stock": "Raw Materials",
            "battery chargers": "Batteries",
            "safety goggles": "Safety",
            "power tools": "Tools",
        }

        for raw, normalized in expected.items():
            with self.subTest(raw=raw):
                self.assertEqual(_normalize_category(raw), normalized)

    @patch("app.services.catalog_service.get_supabase_admin")
    def test_verified_catalog_match_overlays_authoritative_identity(self, admin) -> None:
        admin.return_value = _CatalogClient([{
            "catalog_id": "known-part",
            "canonical_name": "NEO Brushless Motor V1.1",
            "brand": "REV Robotics",
            "category": "Robot Parts",
            "subcategory": "Motors",
            "part_number": "REV-21-1650",
            "verification_status": "verified",
            "product_url": "https://www.revrobotics.com/rev-21-1650/",
            "source_url": "https://www.revrobotics.com/rev-21-1650/",
            "specifications": {"nominal_voltage": "12 V"},
            "compatibility": {"motor_controllers": ["REV SPARK MAX"]},
        }])

        result = enrich_scan_items_from_verified_catalog([{
            "name": "black motor",
            "brand": "REV",
            "part_number": "rev-21-1650",
            "category": "Other",
            "quantity": 1,
        }])[0]

        self.assertEqual(result["name"], "NEO Brushless Motor V1.1")
        self.assertEqual(result["category"], "Robot Parts")
        self.assertTrue(result["catalog_match"]["verified"])
        self.assertEqual(result["catalog_match"]["specifications"]["nominal_voltage"], "12 V")

    @patch("app.services.catalog_service.get_supabase_admin")
    def test_catalog_does_not_match_wrong_manufacturer(self, admin) -> None:
        admin.return_value = _CatalogClient([{
            "brand": "REV Robotics",
            "part_number": "REV-21-1650",
            "verification_status": "verified",
        }])

        original = {"name": "Motor", "brand": "Other", "part_number": "REV-21-1650"}
        result = enrich_scan_items_from_verified_catalog([original])[0]

        self.assertNotIn("catalog_match", result)
        self.assertEqual(result["name"], "Motor")

    def test_catalog_match_survives_api_response_validation(self) -> None:
        item = ExtractedInventoryItem.model_validate({
            "name": "SPARK MAX Motor Controller",
            "category": "Electronics",
            "quantity": 1,
            "catalog_match": {
                "verified": True,
                "source": "manufacturer",
                "product_url": "https://www.revrobotics.com/rev-11-2158/",
                "specifications": {"communication": ["PWM", "CAN", "USB-C"]},
                "compatibility": {"motors": ["REV NEO"]},
            },
        })

        self.assertTrue(item.catalog_match and item.catalog_match.verified)
        self.assertEqual(item.catalog_match.specifications["communication"][1], "CAN")


if __name__ == "__main__":
    unittest.main()
