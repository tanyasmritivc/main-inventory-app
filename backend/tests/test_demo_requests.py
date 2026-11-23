import asyncio
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from uuid import uuid4

from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.api.routes.demo_requests import router
from app.services import demo_requests as inbox


class DemoRequestsTest(unittest.TestCase):
    def test_all_answers_reach_inbox_and_team_email(self):
        answers = {
            "name": "Test Visitor", "organization": "Hardware Lab", "role": "Design lead",
            "organization_type": "Hardware startup", "team_size": "11 to 50", "referral": "A colleague",
            "interests": ["AI inventory search", "Other"], "other_interest": "Trace assemblies",
            "cad_software": "Autodesk Fusion", "problem": "Check stock & compare assemblies", "comments": "Please include the lab manager.",
        }
        with TemporaryDirectory() as tmp, patch.object(inbox, "INBOX", Path(tmp) / "db"), \
                patch.object(inbox, "send_transactional_email") as mailer:
            app = FastAPI()
            app.include_router(router)
            # Drive the queue explicitly after saving the request.
            client = TestClient(app)
            self.addCleanup(client.close)
            response = client.post("/demo-requests", json={
                **answers, "email": "visitor@example.org", "request_id": str(uuid4()),
            })
            self.assertEqual(response.status_code, 202)
            with inbox.connect() as db:
                self.assertEqual(json.loads(db.execute("SELECT details FROM requests").fetchone()[0]), answers)
            self.assertTrue(inbox.deliver_one())
            self.assertTrue(inbox.deliver_one())
            founder = next(call.kwargs for call in mailer.call_args_list if call.kwargs["to"] == inbox.FOUNDER)
            for value in answers.values():
                self.assertIn(", ".join(value) if isinstance(value, list) else value, founder["text"])
            self.assertIn("Check stock &amp; compare assemblies", founder["html"])
            self.assertEqual(founder["reply_to"], "visitor@example.org")

    def test_request_and_independent_mail_retries(self):
        async def sleeping_worker():
            await asyncio.sleep(3600)
        with TemporaryDirectory() as tmp, patch.object(inbox, 'INBOX', Path(tmp) / 'db'), \
                patch.object(inbox, 'run_mail_queue', sleeping_worker), \
                patch.object(inbox, 'send_transactional_email') as send:
            app = FastAPI()
            app.include_router(router)
            body = dict(request_id=str(uuid4()), email='visitor@example.com', name='Test Visitor',
                        organization='Test Lab', interests=['BOM comparison', 'Robotics inventory'])
            with TestClient(app) as client:
                self.assertEqual(client.post('/demo-requests', json={**body, 'organization': ' '}).status_code, 422)
                for _ in range(2):
                    self.assertEqual(client.post('/demo-requests', json=body).json(), {'status': 'received'})
                self.assertEqual(client.post('/demo-requests', json={**body,'request_id':str(uuid4())}).status_code, 202)
                self.assertEqual(client.post('/demo-requests', json={**body, 'name':'Changed'}).status_code, 409)
            send.side_effect = [RuntimeError('relay unavailable'), None, None]
            self.assertTrue(inbox.deliver_one())
            self.assertTrue(inbox.deliver_one())
            self.assertFalse(inbox.deliver_one())
            with inbox.connect() as db:
                self.assertEqual(db.execute('SELECT count(*) FROM requests').fetchone()[0], 1)
                self.assertEqual(db.execute('SELECT count(*) FROM mail WHERE sent IS NULL').fetchone()[0], 1)
                db.execute('UPDATE mail SET due=0 WHERE sent IS NULL')
            self.assertTrue(inbox.deliver_one())
            self.assertFalse(inbox.deliver_one())
            founder, visitor, retry = [call.kwargs for call in send.call_args_list]
            self.assertEqual(founder, retry)
            self.assertEqual(founder['to'], 'tanya@findez.ai')
            self.assertEqual(founder['reply_to'], body['email'])
            self.assertIn('BOM comparison', founder['text'])
            self.assertEqual(visitor['to'], body['email'])
            self.assertEqual(visitor['reply_to'], 'tanya@findez.ai')


if __name__ == '__main__':
    unittest.main()
