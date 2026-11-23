CREATE TABLE sales (
 request_id TEXT PRIMARY KEY REFERENCES requests(id), status TEXT NOT NULL DEFAULT 'New Request',
 owner TEXT NOT NULL DEFAULT '', pilot TEXT NOT NULL DEFAULT '{}',
 briefing TEXT, brief_state TEXT NOT NULL DEFAULT 'pending', brief_due INTEGER NOT NULL DEFAULT 0,
 brief_lease TEXT, updated INTEGER NOT NULL DEFAULT 0
);
INSERT INTO sales(request_id,status,updated)
 SELECT r.id, CASE WHEN m.sent IS NULL THEN 'New Request' ELSE 'Confirmation Sent' END,r.created
 FROM requests r LEFT JOIN mail m ON m.request_id=r.id AND m.kind='visitor';
-- Historical leads stay available for on-demand review without bulk model calls.
UPDATE sales SET brief_state='on demand';
CREATE INDEX sales_status ON sales(status,updated);
CREATE TABLE demo_events (
 id INTEGER PRIMARY KEY, request_id TEXT NOT NULL REFERENCES requests(id), at INTEGER NOT NULL,
 actor TEXT NOT NULL, action TEXT NOT NULL, detail TEXT NOT NULL DEFAULT ''
);
CREATE INDEX demo_events_by_request ON demo_events(request_id,at);
CREATE TABLE demo_meetings (
 request_id TEXT PRIMARY KEY REFERENCES requests(id), token TEXT NOT NULL UNIQUE,
 revision INTEGER NOT NULL, state TEXT NOT NULL, offers TEXT NOT NULL,
 starts INTEGER, minutes INTEGER NOT NULL, zone TEXT NOT NULL, location TEXT NOT NULL,
 updated INTEGER NOT NULL, booked_once INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX demo_meetings_active ON demo_meetings(state,starts);
CREATE TABLE demo_followups (
 id TEXT PRIMARY KEY, request_id TEXT NOT NULL REFERENCES requests(id), scenario TEXT NOT NULL,
 subject TEXT NOT NULL, body TEXT NOT NULL, due INTEGER NOT NULL,
 state TEXT NOT NULL DEFAULT 'draft', approved_by TEXT, version INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX demo_followups_by_request ON demo_followups(request_id,state);
ALTER TABLE mail ADD COLUMN last_error TEXT;
ALTER TABLE mail ADD COLUMN cancelled INTEGER;
ALTER TABLE mail ADD COLUMN content TEXT;
