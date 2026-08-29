import unittest

from app.services.openai_service import (
    _MULTI_SCAN_SYSTEM_PROMPT,
    _MULTI_SCAN_USER_PROMPT,
)


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


if __name__ == "__main__":
    unittest.main()
