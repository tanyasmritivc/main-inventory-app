"""
Comprehensive pilot-mode tests.

Covers every enforced limit and the billing endpoints.
All Supabase I/O is stubbed — no real DB connections.

Sections
--------
A. Limit service functions (limits.py)
B. Usage service functions (usage_service.py)
C. get_limits_summary — /me/limits response shape
D. Billing routes — Stripe session creation disabled
E. Normal mode — limits re-engage when pilot_mode=False
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# Minimal env for pydantic-settings
os.environ.setdefault("SUPABASE_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_PUBLIC_URL", "https://placeholder.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "placeholder-anon")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "placeholder-service")
os.environ.setdefault(
    "SUPABASE_JWKS_URL",
    "https://placeholder.supabase.co/.well-known/jwks.json",
)
os.environ.setdefault("OPENAI_API_KEY", "placeholder-openai")

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _settings(pilot: bool):
    """Return a Settings-like object with pilot_mode preset."""
    from app.core.config import get_settings

    real = get_settings.__wrapped__() if hasattr(get_settings, "__wrapped__") else None
    mock = MagicMock()
    mock.pilot_mode = pilot
    return mock


PILOT_ON = True
PILOT_OFF = False

# All modules that call get_settings() need to be patched in their own namespace,
# because each does `from app.core.config import get_settings` at import time,
# creating a local reference that is not affected by patching the origin module.
_GET_SETTINGS_TARGETS = [
    "app.core.config.get_settings",
    "app.services.limits.get_settings",
    "app.services.usage_service.get_settings",
    "app.api.routes.billing.get_settings",
]


def _patch_settings(pilot: bool):
    """
    Patch get_settings() in every consuming module's namespace.
    Also clears the lru_cache so a warm cached value doesn't bleed through.
    """
    from contextlib import ExitStack
    from app.core.config import get_settings as _cached_gs

    mock_s = MagicMock()
    mock_s.pilot_mode = pilot
    mock_s.stripe_secret_key = None
    mock_s.stripe_webhook_secret = None
    mock_s.frontend_url = "https://www.findez.ai"

    class _PatchCtx:
        def __enter__(self):
            _cached_gs.cache_clear()
            self._stack = ExitStack()
            for target in _GET_SETTINGS_TARGETS:
                self._stack.enter_context(patch(target, return_value=mock_s))
            return mock_s

        def __exit__(self, *args):
            self._stack.close()
            _cached_gs.cache_clear()

    return _PatchCtx()


# ---------------------------------------------------------------------------
# A. Limit service functions
# ---------------------------------------------------------------------------

class TestLimitsPilotOn(unittest.TestCase):
    """Every limit function must be a no-op / return unlimited when pilot_mode=True."""

    def _patch(self):
        return _patch_settings(PILOT_ON)

    # check_and_increment_chat ------------------------------------------------

    def test_chat_no_exception(self):
        with self._patch():
            from app.services.limits import check_and_increment_chat
            # Must not raise ChatLimitExceeded
            check_and_increment_chat("any-user")

    def test_chat_returns_early_without_db(self):
        with self._patch():
            from app.services.limits import check_and_increment_chat
            with patch("app.services.limits.get_supabase_admin") as mock_db:
                check_and_increment_chat("any-user")
                mock_db.assert_not_called()

    # check_and_increment_scan ------------------------------------------------

    def test_scan_no_exception(self):
        with self._patch():
            from app.services.limits import check_and_increment_scan
            check_and_increment_scan("any-user")

    def test_scan_returns_early_without_db(self):
        with self._patch():
            from app.services.limits import check_and_increment_scan
            with patch("app.services.limits.get_supabase_admin") as mock_db:
                check_and_increment_scan("any-user")
                mock_db.assert_not_called()

    # check_and_increment_import ----------------------------------------------

    def test_import_no_exception(self):
        with self._patch():
            from app.services.limits import check_and_increment_import
            check_and_increment_import("any-user")

    def test_import_returns_early_without_db(self):
        with self._patch():
            from app.services.limits import check_and_increment_import
            with patch("app.services.limits.get_supabase_admin") as mock_db:
                check_and_increment_import("any-user")
                mock_db.assert_not_called()

    # check_item_limit --------------------------------------------------------

    def test_item_limit_allowed(self):
        with self._patch():
            from app.services.limits import check_item_limit
            result = check_item_limit("any-user")
            self.assertTrue(result["allowed"])

    def test_item_limit_max_is_none(self):
        with self._patch():
            from app.services.limits import check_item_limit
            result = check_item_limit("any-user")
            self.assertIsNone(result["limit"])

    def test_item_limit_no_db_call(self):
        with self._patch():
            from app.services.limits import check_item_limit
            with patch("app.services.limits.get_supabase_admin") as mock_db:
                check_item_limit("any-user")
                mock_db.assert_not_called()

    # resolve_effective_limits ------------------------------------------------

    def test_effective_limits_all_none(self):
        with self._patch():
            from app.services.limits import resolve_effective_limits
            limits, team_id = resolve_effective_limits("any-user")
            self.assertIsNone(limits["items"])
            self.assertIsNone(limits["spaces"])
            self.assertIsNone(limits["chats_per_month"])
            self.assertIsNone(limits["scans_per_month"])
            self.assertIsNone(limits["scans_per_day"])

    def test_effective_limits_no_team(self):
        """Pilot mode returns no team_id — the team billing path is bypassed."""
        with self._patch():
            from app.services.limits import resolve_effective_limits
            _, team_id = resolve_effective_limits("any-user")
            self.assertIsNone(team_id)


# ---------------------------------------------------------------------------
# B. Usage service functions
# ---------------------------------------------------------------------------

class TestUsageServicePilotOn(unittest.TestCase):
    """check_limit, increment_usage, get_all_usage, is_pro_user under pilot."""

    def _patch(self):
        return _patch_settings(PILOT_ON)

    def test_is_pro_user_returns_true(self):
        with self._patch():
            from app.services.usage_service import is_pro_user
            self.assertTrue(is_pro_user("any-user"))

    def test_is_pro_user_no_db_call(self):
        with self._patch():
            from app.services.usage_service import is_pro_user
            with patch("app.services.usage_service.get_supabase_admin") as mock_db:
                is_pro_user("any-user")
                mock_db.assert_not_called()

    def test_increment_usage_returns_zero(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import increment_usage
            result = asyncio.run(increment_usage("any-user", "ai_chat"))
            self.assertEqual(result, 0)

    def test_increment_usage_no_db_call(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import increment_usage
            with patch("app.services.usage_service.get_supabase_admin") as mock_db:
                asyncio.run(increment_usage("any-user", "ai_chat"))
                mock_db.assert_not_called()

    def test_check_limit_allowed(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import check_limit
            result = asyncio.run(check_limit("any-user", "ai_chat"))
            self.assertTrue(result["allowed"])

    def test_check_limit_max_is_none(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import check_limit
            result = asyncio.run(check_limit("any-user", "photo_scan"))
            self.assertIsNone(result["limit"])

    def test_check_limit_pilot_flag_present(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import check_limit
            result = asyncio.run(check_limit("any-user", "spaces"))
            self.assertTrue(result.get("pilot"))

    def test_check_limit_no_db_call(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import check_limit
            with patch("app.services.usage_service.get_supabase_admin") as mock_db:
                asyncio.run(check_limit("any-user", "barcode_scan"))
                mock_db.assert_not_called()

    def test_get_all_usage_all_unlimited(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import get_all_usage, FREE_LIMITS
            result = asyncio.run(get_all_usage("any-user"))
            for feature in FREE_LIMITS:
                self.assertTrue(result[feature]["allowed"], f"{feature} should be allowed")
                self.assertIsNone(result[feature]["limit"], f"{feature} limit should be None")

    def test_get_all_usage_plan_is_pilot(self):
        import asyncio
        with self._patch():
            from app.services.usage_service import get_all_usage
            result = asyncio.run(get_all_usage("any-user"))
            self.assertEqual(result["plan"], "pilot")


# ---------------------------------------------------------------------------
# C. get_limits_summary — /me/limits response
# ---------------------------------------------------------------------------

class TestGetLimitsSummaryPilotOn(unittest.TestCase):
    """
    /me/limits must include pilot_mode=True and null maxima.
    Supabase is fully stubbed to avoid real I/O.
    """

    def _stub_supabase(self):
        """Return a Supabase client stub with count=5 items and 2 spaces."""
        mock_client = MagicMock()
        count_resp = MagicMock()
        count_resp.count = 5
        count_resp.data = []
        # .table().select().eq().execute() → count_resp
        mock_client.table.return_value.select.return_value.eq.return_value.execute.return_value = count_resp
        mock_client.table.return_value.select.return_value.limit.return_value.eq.return_value.execute.return_value = count_resp
        return mock_client

    def _run_summary(self, pilot: bool):
        """Run get_limits_summary with pilot mode set and Supabase stubbed."""
        mock_client = self._stub_supabase()
        with _patch_settings(pilot), \
             patch("app.services.limits.get_supabase_admin", return_value=mock_client), \
             patch("app.services.limits.supabase_execute_with_retry", side_effect=lambda fn: fn()), \
             patch("app.services.limits.get_user_tier", return_value="free"), \
             patch("app.services.limits.count_spaces", return_value=2, create=True), \
             patch("app.services.spaces_repo.count_spaces", return_value=2, create=True), \
             patch("app.services.limits._get_usage_counters",
                   return_value={"chats_used": 3, "scans_used": 1, "scans_today": 0}), \
             patch("app.services.limits._get_team_usage_counters",
                   return_value={"chats_used": 0, "scans_used": 0, "imports_used": 0}), \
             patch("app.services.teams_repo.get_active_team_plan", return_value=(None, None),
                   create=True):
            from app.services.limits import get_limits_summary
            return get_limits_summary("test-user-id")

    def test_pilot_mode_field_true(self):
        result = self._run_summary(pilot=True)
        self.assertIn("pilot_mode", result)
        self.assertTrue(result["pilot_mode"])

    def test_pilot_mode_field_false_in_normal_mode(self):
        result = self._run_summary(pilot=False)
        self.assertIn("pilot_mode", result)
        self.assertFalse(result["pilot_mode"])

    def test_items_max_is_none_in_pilot(self):
        result = self._run_summary(pilot=True)
        self.assertIsNone(result["items"]["max"])

    def test_spaces_max_is_none_in_pilot(self):
        result = self._run_summary(pilot=True)
        self.assertIsNone(result["spaces"]["max"])

    def test_chats_max_is_none_in_pilot(self):
        result = self._run_summary(pilot=True)
        self.assertIsNone(result["chats"]["max"])

    def test_scans_max_is_none_in_pilot(self):
        result = self._run_summary(pilot=True)
        self.assertIsNone(result["scans"]["max"])

    def test_existing_fields_preserved(self):
        """All pre-existing top-level keys must still be present."""
        result = self._run_summary(pilot=True)
        for key in ("tier", "items", "spaces", "chats", "scans"):
            self.assertIn(key, result, f"Field '{key}' missing from /me/limits response")

    def test_tier_reflects_stored_value_not_pilot(self):
        """
        pilot_mode must NOT change the stored tier; 'tier' still shows 'free'
        so clients know the user's real subscription state.
        """
        result = self._run_summary(pilot=True)
        self.assertEqual(result["tier"], "free")

    def test_items_normal_mode_has_cap(self):
        result = self._run_summary(pilot=False)
        self.assertIsNotNone(result["items"]["max"])
        self.assertGreater(result["items"]["max"], 0)


# ---------------------------------------------------------------------------
# D. Billing routes — Stripe session creation disabled
# ---------------------------------------------------------------------------

class TestBillingPilotOn(unittest.TestCase):
    """
    /billing/checkout and /billing/portal must return the pilot message
    and must NEVER call stripe.checkout.Session.create or
    stripe.billing_portal.Session.create.
    """

    def test_checkout_returns_pilot_message(self):
        with _patch_settings(PILOT_ON):
            import stripe
            from app.api.routes.billing import create_billing_checkout, CheckoutRequest
            from app.core.auth import AuthenticatedUser

            user = AuthenticatedUser(user_id="test-user")
            payload = CheckoutRequest(
                plan="ftc_season", program="ftc", team_name="Test Team"
            )
            mock_request = MagicMock()

            with patch.object(stripe.checkout.Session, "create") as mock_create:
                result = create_billing_checkout(payload, mock_request, user)
                mock_create.assert_not_called()

            self.assertTrue(result.get("pilot"))
            self.assertIn("pilot", result.get("message", "").lower())

    def test_checkout_message_is_user_facing(self):
        with _patch_settings(PILOT_ON):
            from app.api.routes.billing import create_billing_checkout, CheckoutRequest
            from app.core.auth import AuthenticatedUser

            payload = CheckoutRequest(
                plan="frc_season", program="frc", team_name="Robots"
            )
            result = create_billing_checkout(payload, MagicMock(), AuthenticatedUser(user_id="u"))
            msg = result.get("message", "")
            self.assertNotIn("stripe", msg.lower())
            self.assertNotIn("exception", msg.lower())
            self.assertNotIn("traceback", msg.lower())
            self.assertGreater(len(msg), 10)

    def test_portal_returns_pilot_message(self):
        with _patch_settings(PILOT_ON):
            import stripe
            from app.api.routes.billing import create_billing_portal
            from app.core.auth import AuthenticatedUser

            user = AuthenticatedUser(user_id="test-user")
            mock_request = MagicMock()

            with patch.object(stripe.billing_portal.Session, "create") as mock_create:
                result = create_billing_portal(mock_request, user)
                mock_create.assert_not_called()

            self.assertTrue(result.get("pilot"))

    def test_portal_no_db_access(self):
        with _patch_settings(PILOT_ON):
            from app.api.routes.billing import create_billing_portal
            from app.core.auth import AuthenticatedUser

            with patch("app.api.routes.billing.get_supabase_admin") as mock_db:
                create_billing_portal(MagicMock(), AuthenticatedUser(user_id="u"))
                mock_db.assert_not_called()

    def test_checkout_no_stripe_init_called(self):
        """_init_stripe() must not be reached — it would fail without a key."""
        with _patch_settings(PILOT_ON):
            from app.api.routes.billing import create_billing_checkout, CheckoutRequest
            from app.core.auth import AuthenticatedUser

            # If _init_stripe() were called it would raise HTTPException(503)
            # because stripe_secret_key is unset in test env.
            # The pilot guard must short-circuit before that point.
            payload = CheckoutRequest(plan="district", program="ftc", team_name="T")
            try:
                result = create_billing_checkout(
                    payload, MagicMock(), AuthenticatedUser(user_id="u")
                )
                self.assertTrue(result.get("pilot"))
            except Exception as exc:
                self.fail(
                    f"Billing checkout raised {exc!r} — "
                    "_init_stripe() was called before the pilot guard"
                )


# ---------------------------------------------------------------------------
# E. Normal mode — limits re-engage when pilot_mode=False
# ---------------------------------------------------------------------------

class TestNormalModeUnchanged(unittest.TestCase):
    """Sanity-check that switching pilot_mode=False restores real limit behaviour."""

    def test_is_pro_user_returns_false_for_free_user(self):
        """In normal mode, a free-tier user must not be treated as pro."""
        with _patch_settings(PILOT_OFF):
            from app.services.usage_service import is_pro_user
            # get_user_tier is called via a local import inside is_pro_user.
            # Stub it in its home module so the inline import picks up the stub.
            with patch("app.services.limits.get_user_tier", return_value="free"):
                result = is_pro_user("any-user")
            self.assertFalse(result)

    def test_check_item_limit_enforced_in_normal_mode(self):
        """check_item_limit must enforce the cap (not return unlimited) in normal mode."""
        with _patch_settings(PILOT_OFF):
            from app.services.limits import check_item_limit

            count_resp = MagicMock()
            count_resp.count = 31  # over the 30-item free limit

            with patch("app.services.limits.supabase_execute_with_retry",
                       side_effect=lambda fn: count_resp), \
                 patch("app.services.limits.get_supabase_admin", return_value=MagicMock()), \
                 patch("app.services.limits.get_user_tier", return_value="free"), \
                 patch("app.services.teams_repo.get_active_team_plan",
                       return_value=(None, None), create=True):
                result = check_item_limit("any-user")

            self.assertFalse(result["allowed"])
            self.assertIsNotNone(result["limit"])

    def test_check_limit_enforced_for_barcode_in_normal_mode(self):
        """In normal mode, barcode_scan must be gated at the free limit (10/mo)."""
        import asyncio
        with _patch_settings(PILOT_OFF):
            from app.services.usage_service import check_limit

            profile_resp = MagicMock()
            profile_resp.data = [{"is_pro": False}]

            mock_client = MagicMock()
            mock_client.table.return_value.select.return_value.eq.return_value.execute.return_value = profile_resp

            with patch("app.services.usage_service.supabase_execute_with_retry",
                       side_effect=lambda fn: fn()), \
                 patch("app.services.usage_service.get_supabase_admin",
                       return_value=mock_client), \
                 patch("app.services.usage_service.get_user_plan",
                       return_value="free"), \
                 patch("app.services.usage_service.get_usage_count",
                       return_value=99):   # 99 >> free limit of 10
                result = asyncio.run(check_limit("any-user", "barcode_scan"))

            self.assertFalse(result["allowed"])


if __name__ == "__main__":
    unittest.main()
