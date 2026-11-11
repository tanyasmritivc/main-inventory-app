"""Run against the complete deployed backend package, with all external I/O mocked."""
import json
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from app.services import world_chat
from app.services.commerce import purchase_intelligence as service
from app.api.routes import commerce
from app.core.auth import AuthenticatedUser, get_current_user


class PurchaseChatIntegrationTest(unittest.TestCase):
    def test_real_dispatch_binds_owner_and_rejects_extra_arguments(self):
        for name, target in [('world_purchases','library'),('world_purchase_check','check')]:
            with patch.object(service,target,return_value={'stock_effect':'none'}) as read:
                self.assertEqual(world_chat.execute('alice','personal',name,{'query':'motor'})['stock_effect'],'none')
                read.assert_called_once_with('alice','personal',query='motor')
                with self.assertRaises(ValueError): world_chat.execute('alice','personal',name,{'query':'motor','actor':'bob'})
                self.assertEqual(read.call_count,1)

    def test_chat_round_trip_uses_purchase_evidence(self):
        evidence={'summary':{'products':1,'orders':1},'ownership':'unconfirmed','live_amazon_access':False,'products':[{'title':'Sample motor','ordered_units':2}]}
        call=SimpleNamespace(id='synthetic-call',function=SimpleNamespace(name='world_purchases',arguments='{"query":"motor"}'))
        events=iter([[{'type':'done','content':'','tool_calls':[call]}],
                     [{'type':'done','content':'Your saved import includes two motor units ordered. Check whether you still have them.','tool_calls':[]}]])
        with patch('app.core.config.get_settings',return_value=SimpleNamespace(findez_chat_vision_model='synthetic-model')), \
             patch('app.services.agent_gateway_client.gateway_completion') as gateway, \
             patch('app.services.completion_stream.completion_events',side_effect=lambda *a,**k:next(events)), \
             patch.object(service,'library',return_value=evidence) as read:
            result=list(world_chat.stream_turn('alice','personal','Did I buy a motor before?',[], 'synthetic-conversation'))
        read.assert_called_once_with('alice','personal',query='motor')
        self.assertEqual(result[-1]['type'],'done')
        self.assertIn('two motor',result[-1]['assistant_message'])
        messages=gateway.call_args.kwargs['messages']
        self.assertIn('not live Amazon',messages[0]['content'])
        self.assertTrue(any(m['role']=='tool' and 'Sample motor' in m['content'] for m in messages))
        operations=result[-1]['answer_context']['operation_diagnostics']
        self.assertTrue(operations[0]['read_only'])
        self.assertFalse(result[-1]['answer_context']['pending_actions'])

    def test_api_validates_scope_and_binds_signed_in_user(self):
        app=FastAPI(); app.include_router(commerce.router)
        app.dependency_overrides[get_current_user]=lambda:AuthenticatedUser(user_id='alice')
        client=TestClient(app)
        with patch.object(service,'library',return_value={'products':[]}) as read:
            self.assertEqual(client.get('/commerce/purchases').status_code,200)
            read.assert_called_once_with('alice','personal','', 'all',0)
            for query in ('scope_type=organization','scope_type=personal&organization_id=11111111-1111-4111-8111-111111111111','offset=-1','status=invalid'):
                self.assertEqual(client.get('/commerce/purchases?'+query).status_code,422)
        with patch.object(service,'check',return_value={'stock_effect':'none'}) as check:
            response=client.post('/commerce/purchase-check',json={'query':'motor'})
            self.assertEqual(response.status_code,200)
            check.assert_called_once_with('alice','personal','motor')
            self.assertEqual(client.post('/commerce/purchase-check',json={'query':'motor','actor':'bob'}).status_code,422)
        def denied(): raise HTTPException(401,'Sign in')
        app.dependency_overrides[get_current_user]=denied
        self.assertEqual(client.get('/commerce/purchases').status_code,401)
        self.assertEqual(client.post('/commerce/purchase-check',json={'query':'motor'}).status_code,401)


if __name__ == '__main__': unittest.main()
