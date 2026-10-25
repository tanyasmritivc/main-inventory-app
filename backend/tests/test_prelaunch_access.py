"""Pre-launch has no cumulative plan cutoff, even with a stale display date."""
import asyncio
from types import SimpleNamespace
from unittest.mock import patch
from app.services import limits, usage_service


def test_prelaunch_continues_past_every_planned_allowance_without_quota_writes():
    settings = SimpleNamespace(pilot_mode=True, pilot_ends_at='2000-01-01T00:00:00Z')
    async def use_features():
        for _ in range(101):
            limits.check_and_increment_chat('tester')
            limits.check_and_increment_scan('tester')
            limits.check_and_increment_import('tester')
            assert limits.check_item_limit('tester')['allowed'] is True
        for feature in usage_service.FREE_LIMITS:
            status = await usage_service.check_limit('tester', feature)
            assert status['allowed'] is True
            assert status['limit'] is None
            assert await usage_service.increment_usage('tester', feature) == 0
    with patch.object(limits, 'get_settings', return_value=settings), \
         patch.object(usage_service, 'get_settings', return_value=settings), \
         patch.object(limits, 'get_supabase_admin') as db, \
         patch.object(usage_service, 'get_supabase_admin') as old_db:
        asyncio.run(use_features())
        db.assert_not_called()
        old_db.assert_not_called()
