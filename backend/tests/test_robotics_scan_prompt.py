import unittest

from app.services.openai_service import (
    _MULTI_SCAN_SYSTEM_PROMPT,
    _MULTI_SCAN_USER_PROMPT,
)
from app.services.items_repo import _normalize_category


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


if __name__ == "__main__":
    unittest.main()
