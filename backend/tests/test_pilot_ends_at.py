"""
Tests for PILOT_ENDS_AT config and the pilot_ends_at / pilot_notice fields
returned by get_limits_summary() via GET /me/limits.

Scenarios covered:
  1. Pilot active with end-date set → pilot_mode=True, pilot_ends_at filled,
     pilot_notice contains the expected text.
  2. Pilot inactive (pilot_mode=False) with end-date set → pilot_mode=False,
     pilot_ends_at still returned, pilot_notice is None.
  3. Pilot active but PILOT_ENDS_AT not configured → pilot_mode=True,
     pilot_ends_at is None, pilot_notice still returned (date is informational,
     not required for the notice).
  4. Pilot inactive and no end-date → both pilot_ends_at and pilot_notice are None.
  5. pilot_ends_at value round-trips through config unchanged.
"""

import os
import sys
import unittest
from contextlib import ExitStack
from unittest.mock import MagicMock, patch

# Minimal env so pydantic-settings can construct Settings()
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

# Stub third-party packages that aren't available in this dev venv before any
# app code is imported, so the modules load without real network dependencies.
for _mod in (
    "supabase",
    "supabase.lib",
    "supabase.lib.client_options",
    "gotrue",
    "httpx",
    "postgrest",
    "storage3",
    "realtime",
    "stripe",
    "slowapi",
    "slowapi.util",
    "slowapi.errors",
    "openai",
    "jose",
    "jose.jwt",
    "jose.exceptions",
    "cachetools",
):
    sys.modules.setdefault(_mod, MagicMock())

# Pre-import modules so patch() can resolve dotted attribute targets.
import app.core.config  # noqa: E402
import app.services.limits  # noqa: E402
import app.services.usage_service  # noqa: E402

_PILOT_END_DATE = "2026-09-11T23:59:59Z"
_EXPECTED_NOTICE = (
    "Free Pilot: Unlimited access through September 11, 2026. "
    "Standard free-plan limits and optional paid plans begin September 12. "
    "You will not be charged automatically."
)

_GET_SETTINGS_TARGETS = [
    "app.core.config.get_settings",
    "app.services.limits.get_settings",
    "app.services.usage_service.get_settings",
    "app.api.routes.billing.get_settings",
]


def _make_settings(pilot_mode: bool, pilot_ends_at: str | None):
    from app.core.config import Settings
    from app.core.config import get_settings as _cached_gs

    s = MagicMock(spec=Settings)
    s.pilot_mode = pilot_mode
    s.pilot_ends_at = pilot_ends_at
    return s, _cached_gs


class _PatchCtx:
    """Patches get_settings in all consuming module namespaces + clears lru_cache."""

    def __init__(self, pilot_mode: bool, pilot_ends_at: str | None):
        self._pilot_mode = pilot_mode
        self._pilot_ends_at = pilot_ends_at

    def __enter__(self):
        mock_s, _cached_gs = _make_settings(self._pilot_mode, self._pilot_ends_at)
        _cached_gs.cache_clear()
        self._stack = ExitStack()
        for target in _GET_SETTINGS_TARGETS:
            self._stack.enter_context(patch(target, return_value=mock_s))
        return mock_s

    def __exit__(self, *args):
        self._stack.close()
        from app.core.config import get_settings as _cached_gs
        _cached_gs.cache_clear()


def _run_summary(pilot_mode: bool, pilot_ends_at: str | None) -> dict:
    """Run get_limits_summary() with Supabase stubbed out."""
    with _PatchCtx(pilot_mode, pilot_ends_at):
        with patch("app.services.limits.get_supabase_admin") as mock_admin, \
             patch("app.services.limits.supabase_execute_with_retry") as mock_exec, \
             patch("app.services.limits.count_spaces", return_value=0, create=True), \
             patch("app.services.spaces_repo.count_spaces", return_value=0, create=True), \
             patch("app.services.teams_repo.get_active_team_plan",
                   return_value=(None, None), create=True):

            mock_resp = MagicMock()
            mock_resp.data = []
            mock_resp.count = 0
            mock_exec.return_value = mock_resp

            from app.services.limits import get_limits_summary
            return get_limits_summary("test-user-id")


class TestPilotEndsAtConfig(unittest.TestCase):

    def test_settings_has_pilot_ends_at_field(self):
        from app.core.config import Settings
        import inspect
        fields = Settings.model_fields
        self.assertIn(
            "pilot_ends_at", fields,
            "Settings must declare pilot_ends_at",
        )

    def test_pilot_ends_at_defaults_to_none(self):
        from app.core.config import Settings
        field = Settings.model_fields["pilot_ends_at"]
        self.assertIsNone(
            field.default,
            "pilot_ends_at should default to None when env var not set",
        )

    def test_pilot_ends_at_round_trips(self):
        """Value set in config is returned unchanged in the summary."""
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self.assertEqual(result["pilot_ends_at"], _PILOT_END_DATE)


class TestPilotSummaryFields(unittest.TestCase):
    """get_limits_summary() must always include all three pilot fields."""

    def _assert_pilot_fields_present(self, result: dict) -> None:
        for key in ("pilot_mode", "pilot_ends_at", "pilot_notice"):
            self.assertIn(key, result, f"Missing field: {key}")

    def test_active_pilot_with_end_date(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self._assert_pilot_fields_present(result)
        self.assertTrue(result["pilot_mode"])
        self.assertEqual(result["pilot_ends_at"], _PILOT_END_DATE)
        self.assertEqual(result["pilot_notice"], _EXPECTED_NOTICE)

    def test_inactive_pilot_with_end_date(self):
        result = _run_summary(pilot_mode=False, pilot_ends_at=_PILOT_END_DATE)
        self._assert_pilot_fields_present(result)
        self.assertFalse(result["pilot_mode"])
        self.assertEqual(result["pilot_ends_at"], _PILOT_END_DATE)
        self.assertIsNone(result["pilot_notice"])

    def test_active_pilot_without_end_date(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=None)
        self._assert_pilot_fields_present(result)
        self.assertTrue(result["pilot_mode"])
        self.assertIsNone(result["pilot_ends_at"])
        # Notice is still included when pilot_mode is true, even without the date.
        self.assertEqual(result["pilot_notice"], _EXPECTED_NOTICE)

    def test_inactive_pilot_without_end_date(self):
        result = _run_summary(pilot_mode=False, pilot_ends_at=None)
        self._assert_pilot_fields_present(result)
        self.assertFalse(result["pilot_mode"])
        self.assertIsNone(result["pilot_ends_at"])
        self.assertIsNone(result["pilot_notice"])


class TestPilotNoticeContent(unittest.TestCase):
    """Spot-check the exact notice text required by the spec."""

    def setUp(self):
        self.result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)

    def test_notice_mentions_sep_11(self):
        self.assertIn("September 11, 2026", self.result["pilot_notice"])

    def test_notice_mentions_sep_12(self):
        self.assertIn("September 12", self.result["pilot_notice"])

    def test_notice_mentions_no_automatic_charge(self):
        self.assertIn("not be charged automatically", self.result["pilot_notice"])

    def test_notice_mentions_unlimited_access(self):
        self.assertIn("Unlimited access", self.result["pilot_notice"])

    def test_notice_mentions_free_pilot(self):
        self.assertIn("Free Pilot", self.result["pilot_notice"])

    def test_full_notice_exact_match(self):
        self.assertEqual(self.result["pilot_notice"], _EXPECTED_NOTICE)


class TestPilotLimitsUnchanged(unittest.TestCase):
    """Verify unlimited limits still flow through during active pilot."""

    def test_items_max_is_null_during_pilot(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self.assertIsNone(result["items"]["max"])

    def test_spaces_max_is_null_during_pilot(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self.assertIsNone(result["spaces"]["max"])

    def test_chats_max_is_null_during_pilot(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self.assertIsNone(result["chats"]["max"])

    def test_scans_max_is_null_during_pilot(self):
        result = _run_summary(pilot_mode=True, pilot_ends_at=_PILOT_END_DATE)
        self.assertIsNone(result["scans"]["max"])


if __name__ == "__main__":
    unittest.main()
