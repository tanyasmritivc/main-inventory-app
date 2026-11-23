import asyncio
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import tempfile
import time
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import AsyncMock, patch
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.testclient import TestClient
import httpx

from app.api.routes import demo_requests, demo_sales as routes
from app.services import demo_requests as inbox, demo_sales as sales, demo_briefings as briefs


class DemoSalesTests(TestCase):
    def setUp(self):
        routes.limiter.reset()
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        for stub in (patch.object(inbox, "INBOX", Path(tmp.name)/"demo.db"),
                     patch.object(inbox, "send_transactional_email"),
                     patch.object(routes, "integrations", return_value={"Calendar":"Calendar invitations"})):
            self.addCleanup(stub.stop)
            stub.start()
        app = FastAPI()
        app.include_router(demo_requests.router)
        app.include_router(routes.router)
        self.api = TestClient(app)
        self.addCleanup(self.api.close)
        self.app = app
        self.actor = str(uuid4())
        self.rid = str(uuid4())
        self.private = "/internal/demo-sales/"+self.rid
        self.body = dict(request_id=self.rid, email="visitor@example.org", name="Example Person", role="Engineer",
                         organization="Prototype Lab", organization_type="Hardware startup", form_version=2,
                         interests=["BOM comparison"], cad_software="Autodesk Fusion",problem="Check stock")
        self.starts = int(time.time()) + 4*86400

    def submit(self):
        self.assertEqual(self.api.post("/demo-requests",json=self.body).status_code,202)
        self.app.dependency_overrides[routes.founder_access] = lambda: self.actor

    def act(self, action, **data):
        return self.api.post(self.private+"/action",json={"action":action,**data})

    def offer(self):
        r=self.api.post(self.private+"/offer",json={"starts":[self.starts,self.starts+7200],"minutes":30,
            "location":"https://meet.example.org/real-test-room","zone":"America/Los_Angeles"})
        self.assertEqual(r.status_code,200,r.text)
        with closing(inbox.connect()) as db:
            return sales.meeting(db,self.rid)["token"]

    def reserve(self, token, revision=1, start=None):
        return self.api.post("/demo-scheduling/book",json={"token":token,"revision":revision,"starts":start or self.starts,"zone":"Asia/Kolkata"})

    def deliver(self):
        while inbox.deliver_one():
            pass

    def test_form_to_schedule_reschedule_cancel(self):
        self.submit()
        self.submit()
        self.deliver()
        self.assertEqual(inbox.send_transactional_email.call_count,2)
        visitor=next(c.kwargs for c in inbox.send_transactional_email.call_args_list if c.kwargs['to']==self.body['email'])
        self.assertIn("Hi Example,",visitor['text'])
        self.assertIn("findez-signature.gif",visitor['html'])
        self.assertNotIn("your demo is confirmed",visitor["text"].lower())
        token=self.offer()
        self.assertEqual(self.reserve(token,start=self.starts+1).status_code,409)
        self.assertEqual(self.reserve(token).json()["state"],"confirmed")
        self.assertEqual(self.reserve(token).json()["revision"],2)
        self.assertEqual(self.reserve(token,2,self.starts+7200).json()['revision'],3)
        self.assertEqual(self.reserve(token,1).status_code,409)
        self.deliver()
        invites=[c.kwargs for c in inbox.send_transactional_email.call_args_list if c.kwargs.get('calendar')]
        self.assertEqual(len(invites),2)
        self.assertIn('SEQUENCE:3',invites[0]['calendar'][1])
        self.assertIn('Asia/Kolkata',invites[0]['text'])
        with closing(inbox.connect()) as db:
            rows=db.execute("SELECT due FROM mail WHERE kind LIKE '%reminder-%' AND cancelled IS NULL ORDER BY due").fetchall()
            self.assertEqual([r[0] for r in rows],[self.starts+7200-86400,self.starts+7200-3600])
        r=self.api.post("/demo-scheduling/cancel",json={"token":token,"revision":3})
        self.assertEqual(r.json()["state"],"cancelled")
        self.assertEqual(self.reserve(token,4).status_code,409)
        with closing(inbox.connect()) as db:
            self.assertFalse(db.execute("SELECT 1 FROM mail WHERE cancelled IS NULL AND kind LIKE '%reminder-%'").fetchone())
        self.deliver()
        self.assertEqual(inbox.send_transactional_email.call_args.kwargs['calendar'][0],'CANCEL')

    def test_double_booking_and_invalid_tokens_and_timezone(self):
        self.submit()
        token=self.offer()
        self.assertEqual(self.api.post("/demo-scheduling/view",json={"token":"x"*43}).status_code,404)
        self.assertEqual(self.api.post("/demo-scheduling/book",json={"token":token,"revision":1,"starts":self.starts,"zone":"Invalid/zone"}).status_code,422)
        other=str(uuid4())
        inbox.save(other,"another@example.org",{"name":"Other","organization":"Team","interests":[]})
        sales.offer(other,self.actor,[self.starts+60],30,"UTC","https://meet.example.org/test")
        with closing(inbox.connect()) as db:
            other_token=sales.meeting(db,other)["token"]
        self.reserve(token)
        self.assertEqual(self.reserve(other_token,start=self.starts+60).status_code,409)
        self.assertEqual(sales.view_slots(other_token)["slots"],[])

    def test_review_and_metrics_lifecycle(self):
        self.submit()
        self.assertEqual(self.act("draft",scenario="General").status_code,409)
        self.reserve(self.offer())
        self.assertEqual(self.act("status",value="Demo Completed").status_code,409)
        with patch.object(sales,"now",return_value=self.starts+600):
            self.assertEqual(self.act("status",value="Demo Completed").json()['status'],"Demo Completed")
        self.assertEqual(self.act("owner",value="Founder").json()['owner'],"Founder")
        self.assertEqual(self.act("note",value="Discuss maintenance stock.").json()['history'][0]['detail'],"Discuss maintenance stock.")
        self.assertEqual(self.act("draft",scenario="Pilot").status_code,409)
        self.act("pilot",scope="Maintenance bench",next_action="Agree evaluation criteria")
        self.act("status",value="Pilot Discussion")
        draft=self.act("draft",scenario="General").json()['followups'][0]
        self.assertIn(self.body['organization'],draft["body"])
        self.assertEqual(draft['state'],'draft')
        for _ in range(2):
            self.assertEqual(self.act("approve",id=draft["id"],subject=draft["subject"],body=draft["body"]).status_code,200)
        self.deliver()
        self.assertEqual(sum(c.kwargs['subject']==draft['subject'] for c in inbox.send_transactional_email.call_args_list),1)
        other=self.act("draft",scenario="No response").json()["followups"][0]
        self.act("approve",id=other['id'],subject=other['subject'],body=other['body'],due=self.starts+9999)
        self.act("response")
        self.assertEqual(self.api.get(self.private).json()['followups'][0]['state'],'cancelled')
        self.act("status",value="Converted")
        result=self.api.get("/internal/demo-sales",params={"search":"prototype","category":"Hardware startup","status":"Converted"}).json()
        self.assertEqual([x["id"] for x in result["items"]],[self.rid])
        for rate in result['metrics']['rates'].values():
            self.assertEqual(rate,[1,1])

    def test_briefing_and_fallback(self):
        self.submit()
        with patch.object(briefs,"gateway_completion",side_effect=RuntimeError):
            self.assertTrue(briefs.generate_one())
        detail=self.api.get(self.private).json()
        self.assertEqual(detail["brief_state"],"Template fallback")
        self.assertGreaterEqual(len(detail['briefing']['questions']),3)
        self.act("briefing")
        sample=briefs.fallback(self.body)
        response=SimpleNamespace(choices=[SimpleNamespace(message=SimpleNamespace(content=json.dumps(sample)))])
        with patch.object(briefs,"gateway_completion",return_value=response) as gateway:
            self.assertTrue(briefs.generate_one())
            self.assertFalse(briefs.generate_one())
        self.assertEqual(self.api.get(self.private).json()["brief_state"],"AI draft")
        self.assertNotIn(self.body["email"],str(gateway.call_args))
        self.assertEqual(inbox.send_transactional_email.call_count,0)

    def test_invalid_submissions_and_authorization(self):
        for fields in ({"email":"broken@"},{"role":" "},{"organization_type":None}):
            self.assertEqual(self.api.post("/demo-requests",json={**self.body,**fields}).status_code,422)
        self.assertEqual(self.api.get(self.private).status_code,401)
        self.assertEqual(self.act("note",value="x").status_code,401)
        credentials=HTTPAuthorizationCredentials(scheme="Bearer",credentials="example")
        with patch.object(httpx.AsyncClient,"get",new_callable=AsyncMock) as get:
            for code,expected in ((403,403),(401,401),(502,503)):
                get.return_value=httpx.Response(code,request=httpx.Request("GET","http://localhost/"))
                with self.assertRaises(HTTPException) as raised:
                    asyncio.run(routes.founder_access(credentials))
                self.assertEqual(raised.exception.status_code,expected)

    def test_legacy_migration_preserves_inbox_and_delivery(self):
        with sqlite3.connect(inbox.INBOX) as db:
            db.executescript("CREATE TABLE requests(id TEXT PRIMARY KEY,email TEXT,details TEXT,fingerprint TEXT,created INTEGER);"
                "CREATE TABLE mail(request_id TEXT,kind TEXT,due INTEGER,attempts INTEGER DEFAULT 0,sent INTEGER,PRIMARY KEY(request_id,kind));")
            db.execute("INSERT INTO requests VALUES(?,?,?,?,?)",(self.rid,self.body['email'],json.dumps(self.body),'existing',100))
            db.execute("INSERT INTO mail VALUES(?,'visitor',100,1,101)",(self.rid,))
        inbox.initialize()
        inbox.initialize()
        with closing(inbox.connect()) as db:
            self.assertEqual(sales.detail(db,self.rid)["status"],"Confirmation Sent")
            self.assertEqual(db.execute("SELECT count(*) FROM mail").fetchone()[0],1)
            self.assertEqual(db.execute("PRAGMA foreign_key_check").fetchall(),[])

    def test_reminders_deliver_once_at_their_due_times(self):
        self.submit()
        self.reserve(self.offer())
        self.deliver()
        for hours in (24, 1):
            with patch.object(time, "time", return_value=self.starts-hours*3600):
                self.deliver()
                self.deliver()
            messages = [c.kwargs for c in inbox.send_transactional_email.call_args_list
                        if c.kwargs['subject'] == 'Reminder: your FindEZ AI demo']
            self.assertEqual(len(messages), 1 if hours == 24 else 2)
            self.assertIn('Asia/Kolkata', messages[-1]['text'])
            self.assertIn('Reschedule or cancel', messages[-1]['text'])

    def test_calendar_delivery_failure_and_cancellation(self):
        self.submit()
        self.reserve(self.offer())
        inbox.send_transactional_email.side_effect = RuntimeError("provider unavailable")
        self.deliver()
        with closing(inbox.connect()) as db:
            row=db.execute("SELECT attempts,sent,last_error FROM mail WHERE kind='meeting/2/invite'").fetchone()
            self.assertEqual(tuple(row),(1,None,'Mail provider did not confirm delivery'))
        self.act("cancel",revision=2)
        inbox.send_transactional_email.reset_mock()
        inbox.send_transactional_email.side_effect=None
        with patch.object(time,"time",return_value=int(time.time())+900):
            self.deliver()
        self.assertEqual([c.kwargs['calendar'][0] for c in inbox.send_transactional_email.call_args_list if 'calendar' in c.kwargs], ['CANCEL','CANCEL'])

    def test_actual_calendar_mime_and_missing_mail_configuration(self):
        from app.services import email_delivery
        cfg=SimpleNamespace(smtp_from_email="demo@example.org",smtp_from_name="FindEZ",
            brevo_smtp_username=None,brevo_smtp_password=None,brevo_smtp_host="localhost",brevo_smtp_port=587)
        kwargs=dict(to="visitor@example.org",subject="Demo",html="<p>Demo</p>",text="Demo",
                    calendar=("REQUEST","BEGIN:VCALENDAR\r\nEND:VCALENDAR"))
        with patch.object(email_delivery,"get_settings",return_value=cfg), patch.dict("os.environ",{},clear=True):
            with self.assertRaisesRegex(RuntimeError,"not configured"):
                email_delivery.send_transactional_email(**kwargs)
            cfg.brevo_smtp_username, cfg.brevo_smtp_password = True,True
            with patch.object(email_delivery.smtplib,"SMTP") as smtp:
                email_delivery.send_transactional_email(**kwargs)
            msg=smtp.return_value.__enter__.return_value.send_message.call_args.args[0]
            self.assertEqual([p.get_content_type() for p in msg.iter_parts()],["text/plain","text/html","text/calendar"])
            self.assertEqual(list(msg.iter_parts())[2].get_param("method"),"REQUEST")

    def test_concurrent_requests_for_the_same_slot_have_one_winner(self):
        from concurrent.futures import ThreadPoolExecutor
        from threading import Barrier
        self.submit()
        token=self.offer()
        other=str(uuid4())
        inbox.save(other,"second@example.org",{"name":"Second Visitor","organization":"Other lab","interests":[]})
        sales.offer(other,self.actor,[self.starts],30,"UTC","https://meet.example.org/other")
        with closing(inbox.connect()) as db:
            other_token=sales.meeting(db,other)["token"]
        gate=Barrier(2)
        def compete(ticket):
            gate.wait(timeout=3)
            try:
                sales.book(ticket,1,self.starts,"America/Los_Angeles")
            except sales.Conflict:
                return False
            return True
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(compete,[token,other_token])),[False,True])

    def test_dst_transition_and_exhausted_job_recovery(self):
        from datetime import datetime
        # The repeated 1:30 am in California is two distinct bookable UTC instants.
        for when,zone in (("2027-11-07T08:30:00+00:00","PDT"),("2027-11-07T09:30:00+00:00","PST")):
            self.assertIn("01:30 "+zone,sales.local_time(int(datetime.fromisoformat(when).timestamp()),"America/Los_Angeles"))
        self.submit()
        with sales.transaction() as db:
            db.execute("UPDATE mail SET attempts=8,last_error='Mail provider did not confirm delivery' WHERE request_id=? AND kind='visitor'",(self.rid,))
        self.assertEqual(self.act("retry_mail",kind="visitor").status_code,200)
        self.assertEqual(self.act("retry_mail",kind="visitor").status_code,409)
        self.deliver()
        self.assertEqual(self.act("retry_mail",kind="visitor").status_code,409)
