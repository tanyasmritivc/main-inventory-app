import os
import sys
import unittest
from unittest.mock import patch

from fastapi import HTTPException

os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_PUBLIC_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.api.routes.imports import _resolve_import_target


class TestSharedSpreadsheetImportTarget(unittest.TestCase):
    def test_personal_import_is_unchanged(self):
        target = _resolve_import_target(
            requesting_user_id="user-1",
            location="Garage",
            share_id=None,
        )
        self.assertEqual(target, ("user-1", "Garage"))

    @patch("app.api.routes.imports.sharing_service.get_share_access")
    def test_editable_share_uses_owner_and_server_space_name(self, get_access):
        get_access.return_value = (
            {"owner_user_id": "owner-1", "share_name": " Workshop "},
            True,
        )

        target = _resolve_import_target(
            requesting_user_id="member-1",
            location="Untrusted phone value",
            share_id="share-1",
        )

        self.assertEqual(target, ("owner-1", "Workshop"))

    @patch("app.api.routes.imports.sharing_service.get_share_access")
    def test_view_only_share_is_rejected(self, get_access):
        get_access.return_value = (
            {"owner_user_id": "owner-1", "share_name": "Workshop"},
            False,
        )

        with self.assertRaises(HTTPException) as raised:
            _resolve_import_target(
                requesting_user_id="member-1",
                location="Workshop",
                share_id="share-1",
            )

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(
            raised.exception.detail,
            "You only have view access to this space.",
        )

    @patch("app.api.routes.imports.sharing_service.get_share_access")
    def test_non_member_is_rejected(self, get_access):
        get_access.side_effect = ValueError("Not authorized")

        with self.assertRaises(HTTPException) as raised:
            _resolve_import_target(
                requesting_user_id="stranger-1",
                location="Workshop",
                share_id="share-1",
            )

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail, "Not authorized")
if __name__ == "__main__":
    unittest.main()
