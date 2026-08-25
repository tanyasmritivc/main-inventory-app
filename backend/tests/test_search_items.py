"""
Tests for inventory search improvements.

Covers:
  A. search_items_basic — field coverage (part_number, brand, subcategory added)
  B. search_items_basic — user_id scoping (cross-user isolation)
  C. search_items_basic — empty query falls back to list_items
  D. _merge_by_item_id — deduplication by item_id
  E. Route-level raw-query preservation and merge

All Supabase I/O is stubbed — no real DB connections.
"""

import os
import sys
import unittest
from unittest.mock import MagicMock, call, patch

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


def _make_supabase_chain(data: list) -> MagicMock:
    """Return a mock that correctly chains .table().select().eq().or_().order().execute()."""
    execute_result = MagicMock()
    execute_result.data = data
    chain = MagicMock()
    chain.table.return_value = chain
    chain.select.return_value = chain
    chain.eq.return_value = chain
    chain.or_.return_value = chain
    chain.order.return_value = chain
    chain.execute.return_value = execute_result
    return chain


ITEM_PN_F156 = {
    "item_id": "uuid-1",
    "user_id": "user-A",
    "name": "F156 Fastener",
    "part_number": "PN-F156",
    "brand": "Bosch",
    "category": "Fasteners",
    "subcategory": "Hex Bolts",
    "location": "Garage",
    "notes": "M6 x 20mm",
    "purchase_source": "McMaster-Carr",
    "barcode": "123456789",
}

ITEM_OTHER_USER = {
    "item_id": "uuid-2",
    "user_id": "user-B",
    "name": "F156 Clone",
    "part_number": "PN-F156",
}


# ── A. Field coverage ──────────────────────────────────────────────────────────

class TestSearchItemsBasicFieldCoverage(unittest.TestCase):

    def _search_and_get_or_arg(self, q: str, data: list = None) -> tuple:
        from app.services.items_repo import search_items_basic

        chain = _make_supabase_chain(data or [])
        with patch("app.services.items_repo.get_supabase_admin", return_value=chain):
            result = search_items_basic(user_id="user-A", q=q)
        or_arg = chain.or_.call_args[0][0]
        return result, or_arg

    def test_part_number_field_present_in_filter(self):
        _, or_arg = self._search_and_get_or_arg("PN-F156", [ITEM_PN_F156])
        self.assertIn("part_number.ilike.", or_arg)

    def test_brand_field_present_in_filter(self):
        _, or_arg = self._search_and_get_or_arg("Bosch")
        self.assertIn("brand.ilike.", or_arg)

    def test_subcategory_field_present_in_filter(self):
        _, or_arg = self._search_and_get_or_arg("hex bolts")
        self.assertIn("subcategory.ilike.", or_arg)

    def test_all_nine_fields_present(self):
        _, or_arg = self._search_and_get_or_arg("PN-F156")
        for field in ("name", "part_number", "brand", "category", "subcategory",
                      "location", "notes", "purchase_source", "barcode"):
            self.assertIn(f"{field}.ilike.", or_arg,
                          f"Field '{field}' missing from search filter")

    def test_exact_part_number_match_returns_item(self):
        result, _ = self._search_and_get_or_arg("PN-F156", [ITEM_PN_F156])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["part_number"], "PN-F156")

    def test_case_insensitive_pattern_lowercase(self):
        """pn-f156 should produce %pn-f156% in the filter (ilike handles case on the DB side)."""
        _, or_arg = self._search_and_get_or_arg("pn-f156")
        self.assertIn("%pn-f156%", or_arg)
        self.assertIn("part_number.ilike.", or_arg)

    def test_partial_pattern_f156(self):
        """A partial query F156 produces %F156% — a substring match that catches PN-F156."""
        result, or_arg = self._search_and_get_or_arg("F156", [ITEM_PN_F156])
        self.assertIn("%F156%", or_arg)
        self.assertEqual(result[0]["item_id"], "uuid-1")

    def test_brand_search_returns_matching_item(self):
        chain = _make_supabase_chain([ITEM_PN_F156])
        from app.services.items_repo import search_items_basic
        with patch("app.services.items_repo.get_supabase_admin", return_value=chain):
            result = search_items_basic(user_id="user-A", q="Bosch")
        self.assertEqual(result[0]["brand"], "Bosch")

    def test_subcategory_search_returns_matching_item(self):
        chain = _make_supabase_chain([ITEM_PN_F156])
        from app.services.items_repo import search_items_basic
        with patch("app.services.items_repo.get_supabase_admin", return_value=chain):
            result = search_items_basic(user_id="user-A", q="Hex Bolts")
        self.assertEqual(result[0]["subcategory"], "Hex Bolts")


# ── B. User-id scoping ─────────────────────────────────────────────────────────

class TestSearchItemsUserScoping(unittest.TestCase):

    def test_user_id_eq_applied_to_query(self):
        """The Supabase query must be scoped to the requesting user's id."""
        from app.services.items_repo import search_items_basic

        chain = _make_supabase_chain([ITEM_PN_F156])
        with patch("app.services.items_repo.get_supabase_admin", return_value=chain):
            search_items_basic(user_id="user-A", q="PN-F156")

        # Verify .eq("user_id", "user-A") was called somewhere in the chain
        eq_calls = [c for c in chain.eq.call_args_list if c == call("user_id", "user-A")]
        self.assertGreater(len(eq_calls), 0,
                           ".eq('user_id', 'user-A') not found — user scoping missing")

    def test_other_user_item_not_returned(self):
        """search_items_basic for user-A must not return items owned by user-B.

        In production this is enforced by the DB .eq("user_id") filter. Here we
        verify the scoping call is present; a mock that returns user-B data only
        if user-B is the queried user_id would be needed for a true integration test."""
        from app.services.items_repo import search_items_basic

        # DB returns nothing for user-A (user-B's item is filtered out server-side)
        chain = _make_supabase_chain([])
        with patch("app.services.items_repo.get_supabase_admin", return_value=chain):
            result = search_items_basic(user_id="user-A", q="PN-F156")

        self.assertEqual(result, [],
                         "Expected empty result when DB returns no items for user-A")
        # Also verify the eq scoping is present
        eq_calls = [c for c in chain.eq.call_args_list if c == call("user_id", "user-A")]
        self.assertTrue(eq_calls)


# ── C. Empty query falls back to list_items ────────────────────────────────────

class TestSearchItemsEmptyQuery(unittest.TestCase):

    @patch("app.services.items_repo.list_items")
    def test_empty_string_calls_list_items(self, mock_list):
        from app.services.items_repo import search_items_basic

        mock_list.return_value = [ITEM_PN_F156]
        result = search_items_basic(user_id="user-A", q="")
        mock_list.assert_called_once_with(user_id="user-A")
        self.assertEqual(result, [ITEM_PN_F156])

    @patch("app.services.items_repo.list_items")
    def test_whitespace_only_calls_list_items(self, mock_list):
        from app.services.items_repo import search_items_basic

        mock_list.return_value = []
        search_items_basic(user_id="user-A", q="   ")
        mock_list.assert_called_once_with(user_id="user-A")


# ── D. _merge_by_item_id deduplication ────────────────────────────────────────

class TestMergeByItemId(unittest.TestCase):

    def test_no_overlap_appends_all(self):
        from app.services.items_repo import _merge_by_item_id

        a = [{"item_id": "1", "name": "A"}]
        b = [{"item_id": "2", "name": "B"}]
        result = _merge_by_item_id(a, b)
        self.assertEqual([r["item_id"] for r in result], ["1", "2"])

    def test_duplicate_item_id_not_repeated(self):
        from app.services.items_repo import _merge_by_item_id

        a = [{"item_id": "1", "name": "A"}]
        b = [{"item_id": "1", "name": "A-copy"}, {"item_id": "2", "name": "B"}]
        result = _merge_by_item_id(a, b)
        ids = [r["item_id"] for r in result]
        self.assertEqual(ids, ["1", "2"])

    def test_primary_order_preserved(self):
        from app.services.items_repo import _merge_by_item_id

        a = [{"item_id": "2"}, {"item_id": "1"}]
        b = [{"item_id": "3"}, {"item_id": "1"}]
        result = _merge_by_item_id(a, b)
        self.assertEqual([r["item_id"] for r in result], ["2", "1", "3"])

    def test_empty_secondary_returns_primary(self):
        from app.services.items_repo import _merge_by_item_id

        a = [{"item_id": "1"}]
        result = _merge_by_item_id(a, [])
        self.assertEqual(result, a)

    def test_empty_primary_returns_secondary(self):
        from app.services.items_repo import _merge_by_item_id

        b = [{"item_id": "1"}]
        result = _merge_by_item_id([], b)
        self.assertEqual(result, b)

    def test_both_empty(self):
        from app.services.items_repo import _merge_by_item_id

        self.assertEqual(_merge_by_item_id([], []), [])


# ── E. Route-level raw-query preservation ────────────────────────────────────

class TestRouteRawQueryMerge(unittest.TestCase):
    """
    When the NL parser rewrites the query, the route must also call
    search_items_basic with the original raw text and merge the results.

    The route function is wrapped by slowapi's rate-limiter decorator, which
    requires a real Starlette Request.  We call __wrapped__ to access the
    original handler directly, bypassing the rate-limiter check in tests.
    """

    @staticmethod
    def _unwrapped():
        """Return the original route function, skipping the slowapi wrapper."""
        from app.api.routes.items import search_items_route
        return getattr(search_items_route, "__wrapped__", search_items_route)

    @patch("app.api.routes.items.search_items_basic")
    @patch("app.api.routes.items.parse_search_query_to_keywords")
    def test_raw_query_searched_when_parser_rewrites(self, mock_parse, mock_search):
        """Parser strips 'PN-' prefix; raw 'PN-F156' must still be searched."""
        mock_parse.return_value = {"text": "F156", "category": None, "location": None}
        item_parsed = {"item_id": "a", "part_number": "PN-F156", "name": "Widget"}
        item_raw_only = {"item_id": "b", "part_number": "PN-F156B", "name": "Other"}
        # First call (parsed q="F156") → item_parsed
        # Second call (raw q="PN-F156") → both items (item_b is unique to raw)
        mock_search.side_effect = [[item_parsed], [item_parsed, item_raw_only]]

        from app.core.auth import AuthenticatedUser
        from app.api.routes.items import SearchItemsRequest

        user = AuthenticatedUser(user_id="user-A")
        payload = SearchItemsRequest(query="PN-F156")

        fn = self._unwrapped()
        with patch("app.api.routes.items.create_activity"):
            response = fn(request=MagicMock(), payload=payload, user=user)

        # Both items should appear, deduplicated
        result_ids = {i["item_id"] for i in response.items}
        self.assertIn("a", result_ids)
        self.assertIn("b", result_ids)

        # search_items_basic must have been called twice
        self.assertEqual(mock_search.call_count, 2)
        calls = mock_search.call_args_list
        qs = {c[1]["q"] for c in calls}
        self.assertIn("F156", qs)    # parsed text
        self.assertIn("PN-F156", qs) # raw original

    @patch("app.api.routes.items.search_items_basic")
    @patch("app.api.routes.items.parse_search_query_to_keywords")
    def test_no_double_search_when_parser_preserves_query(self, mock_parse, mock_search):
        """When parsed text == raw query, only one search_items_basic call."""
        mock_parse.return_value = {"text": "PN-F156", "category": None, "location": None}
        mock_search.return_value = [{"item_id": "a"}]

        from app.api.routes.items import SearchItemsRequest
        from app.core.auth import AuthenticatedUser

        user = AuthenticatedUser(user_id="user-A")
        payload = SearchItemsRequest(query="PN-F156")

        fn = self._unwrapped()
        with patch("app.api.routes.items.create_activity"):
            fn(request=MagicMock(), payload=payload, user=user)

        self.assertEqual(mock_search.call_count, 1)


if __name__ == "__main__":
    unittest.main()
