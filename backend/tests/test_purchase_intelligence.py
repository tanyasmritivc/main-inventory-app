"""Synthetic, read-only purchase evidence. No live database or model calls."""
import json
import sys
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from fastapi import HTTPException
from pydantic import ValidationError
from app.services.commerce import purchase_intelligence as service
from app.services.commerce import repository as repo
from app.services import assistant_tool_safety
import app.services

ORG = '11111111-1111-4111-8111-111111111111'


def connection(id='mine', owner='alice', scope='personal', org=None, inventory=None):
    return dict(id=id, owner_user_id=owner, actor_id=owner, scope_type=scope, organization_id=org,
                inventory_id=inventory, provider='amazon_consumer', status='connected', created_at='2026-01-01')


def record(id='mine', order='order-1', title='NEMA 17 motor', asin='B000000001', qty=2, status='delivered'):
    return dict(connection_id=id, external_id=order, kind='purchase_line', observed_at='2026-11-01',
                data=dict(order_id=order, title=title, asin=asin, quantity=qty, ordered_at='2026-11-01',
                          source_status=status, address='PRIVATE ADDRESS', payment='PRIVATE PAYMENT'))


class Query:
    def __init__(self, rows): self.rows = list(rows)
    def select(self, *_): return self
    def eq(self, key, value): self.rows = [r for r in self.rows if r.get(key) == value]; return self
    def in_(self, key, values): self.rows = [r for r in self.rows if r.get(key) in values]; return self
    def order(self, *_): return self
    def limit(self, n): self.rows = self.rows[:n]; return self
    def range(self, a, b): self.rows = self.rows[a:b+1]; return self
    def execute(self): return SimpleNamespace(data=self.rows)


class PurchaseIntelligenceTest(unittest.TestCase):
    def setUp(self):
        self.tables = {'commerce_connections': [connection(), connection('other', 'bob'), connection('legacy', inventory='old')],
                       'commerce_source_records': [record(), record('other', title='PRIVATE OTHER'), record('legacy', title='LEGACY')],
                       'app_organization_members': []}
        self.db = SimpleNamespace(table=lambda name: Query(self.tables[name]))
        self.patch = patch.object(repo, 'get_supabase_raw', return_value=self.db); self.patch.start()
    def tearDown(self): self.patch.stop()

    def test_personal_scope_and_sanitization(self):
        result = service.library('alice', 'personal')
        self.assertEqual(result['summary']['records'], 1)
        self.assertNotIn('PRIVATE', json.dumps(result))
        self.assertNotIn('LEGACY', json.dumps(result))
        self.assertEqual(result['ownership'], 'unconfirmed')
        self.assertEqual(result['stock_effect'], 'none')
        self.assertEqual(service.library('bob', 'personal')['summary']['records'], 1)

    def test_org_access_never_falls_back_to_personal(self):
        self.tables['commerce_connections'].append(connection('org', scope='organization', org=ORG))
        self.tables['commerce_source_records'].append(record('org', title='Team motor'))
        for role in (None, 'member'):
            self.tables['app_organization_members'] = [] if role is None else [dict(user_id='alice', organization_id=ORG, role=role)]
            with self.assertRaises(HTTPException) as error: service.library('alice', ORG)
            self.assertEqual(error.exception.status_code, 403)
        self.tables['app_organization_members'] = [dict(user_id='alice', organization_id=ORG, role='admin')]
        result = service.library('alice', ORG)
        self.assertEqual(result['summary']['records'], 1)
        self.assertEqual(result['products'][0]['title'], 'Team motor')

    def test_reauthorize_after_read(self):
        with patch.object(repo, 'connection', side_effect=HTTPException(404, 'Removed')):
            with self.assertRaises(HTTPException): service.library('alice', 'personal')
        with patch.object(repo, 'connection', return_value=connection(scope='organization', org=ORG)):
            with self.assertRaises(HTTPException) as error: service.library('alice', 'personal')
            self.assertEqual(error.exception.status_code, 409)

    def test_group_history_without_counting_excluded_stock(self):
        self.tables['commerce_source_records'] = [record(order='one', qty=2), record(order='two', qty=3),
            record(order='three', qty=8, status='cancelled'), record(order='four', qty=4, status='returned'),
            record(order='five', qty=0, status='unknown')]
        result = service.library('alice', 'personal')
        product = result['products'][0]
        self.assertEqual((product['ordered_units'], product['excluded_units'], product['order_count']), (5,12,5))
        self.assertEqual(product['ownership'], 'unconfirmed')
        self.assertEqual(service.library('alice', 'personal', status='cancelled')['products'][0]['ordered_units'],0)
        self.assertEqual(service.library('alice', 'personal', status='unknown')['products'][0]['ordered_units'],0)
        self.assertEqual(len(service.library('alice', 'personal', status='active')['products'][0]['orders']),2)

    def test_links_search_and_pagination(self):
        self.assertEqual(service.search_term('https://www.amazon.com/example/dp/B000000001?tag=x'), 'B000000001')
        for url in ('https://amazon.com.evil.com/dp/B000000001','https://example.com/a', 'https://www.amazon.com/'):
            with self.assertRaises(HTTPException): service.search_term(url)
        self.assertEqual(service.library('alice','personal',query='motor nema')['matched_products'],1)
        self.assertEqual(service.library('alice','personal',query='unknown')['matched_products'],0)
        self.tables['commerce_source_records'] = [record(order=str(n), asin=f'B{n:09d}') for n in range(35)]
        first=service.library('alice','personal'); second=service.library('alice','personal',offset=first['next_offset'])
        self.assertEqual(len(first['products']),30); self.assertEqual(len(second['products']),5)
        self.assertFalse(set(p['key'] for p in first['products']) & set(p['key'] for p in second['products']))
        with patch.object(service,'MAX_RECORDS',2):
            self.assertFalse(service.library('alice','personal')['complete'])

    def check(self, query, inventory=None):
        fake = SimpleNamespace(execute=lambda actor, world, name, args: {'items': inventory or [], 'complete': False})
        with patch.dict(sys.modules, {'app.services.world_chat': fake}), patch.object(app.services,'world_chat',fake,create=True):
            return service.check('alice','personal',query)

    def test_check_evidence_and_no_match(self):
        result=self.check('B000000001')
        self.assertEqual(result['result'],'review_before_buying')
        self.assertEqual(result['purchase_match_basis'],'exact_asin')
        self.assertFalse(result['inventory_matches'])
        self.assertEqual(result['stock_effect'],'none')
        self.tables['commerce_source_records']=[record(status='cancelled')]
        self.assertEqual(self.check('motor')['result'],'history_only')
        self.assertEqual(self.check('unknown')['result'],'no_match_in_checked_records')
        result=self.check('unknown',[{'name':'Unknown motor','quantity':0,'location':'Bin A','secret':'PRIVATE'}])
        self.assertEqual(result['result'],'recorded_zero_stock')
        self.assertNotIn('PRIVATE',json.dumps(result))
        self.assertIn('missing records',json.dumps(self.check('absent')))

    def test_exact_identifier_is_not_inferred_from_length(self):
        self.tables['commerce_source_records']=[record(title='abcdefghij motor')]
        self.assertEqual(self.check('abcdefghij')['purchase_match_basis'],'text_candidate')

    def test_check_reports_truncated_candidates(self):
        self.tables['commerce_source_records']=[record(order=str(n),asin=f'B{n:09d}') for n in range(12)]
        result=self.check('motor')
        self.assertEqual(len(result['purchase_matches']),10)
        self.assertFalse(result['purchases_complete'])

    def test_tool_arguments_cannot_choose_another_owner(self):
        for model in (service.PurchaseQuery,service.PurchaseCheck):
            with self.assertRaises(ValidationError): model.model_validate({'query':'motor','actor':'bob'},strict=True)
        self.assertTrue({'world_purchases','world_purchase_check'} <= assistant_tool_safety.READ_TOOLS)


if __name__ == '__main__': unittest.main()
