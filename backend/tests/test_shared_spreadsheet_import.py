import os
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_PUBLIC_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.api.routes.imports import _resolve_import_target
from app.services import sharing_service


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


class TestSharedImportMembership(unittest.TestCase):
    @patch("app.services.sharing_service.get_supabase_admin")
    def test_share_access_requires_active_membership(self, get_admin):
        share_query = MagicMock()
        share_query.select.return_value = share_query
        share_query.eq.return_value = share_query
        share_query.execute.return_value = SimpleNamespace(
            data=[
                {
                    "share_id": "share-1",
                    "owner_user_id": "owner-1",
                    "permission": "edit",
                    "is_active": True,
                }
            ]
        )

        membership_query = MagicMock()
        membership_query.select.return_value = membership_query
        membership_query.eq.return_value = membership_query
        membership_query.execute.return_value = SimpleNamespace(data=[])

        client = get_admin.return_value
        client.table.side_effect = [share_query, membership_query]

        with self.assertRaisesRegex(ValueError, "Not authorized"):
            sharing_service.get_share_access(
                requesting_user_id="inactive-member",
                share_id="share-1",
            )

        membership_query.eq.assert_any_call("is_active", True)


if __name__ == "__main__":
    unittest.main()
