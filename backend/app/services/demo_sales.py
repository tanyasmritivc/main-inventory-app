"""Private sales lifecycle in the existing demo inbox. All times are UTC epoch seconds."""
from contextlib import contextmanager
from datetime import datetime
import json
import secrets
import time
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.services import demo_calendar, demo_requests as inbox

STATUSES = ("New Request", "Confirmation Sent", "Meeting Pending", "Meeting Booked", "Demo Completed",
            "Follow-Up Required", "Pilot Discussion", "Converted", "Not Proceeding")
ORIGIN = "https://findez.ai"
DASHBOARD = "FindEZ Founder Dashboard → Demo Requests"


class Missing(Exception):
    pass


class Conflict(Exception):
    pass


def now():
    return int(time.time())


@contextmanager
def transaction():
    db = inbox.connect()
    try:
        db.execute("BEGIN IMMEDIATE")
        yield db
        db.commit()
    finally:
        db.close()


def event(db, rid, actor, action, detail=""):
    db.execute("INSERT INTO demo_events(request_id,at,actor,action,detail) VALUES(?,?,?,?,?)",
               (rid, now(), actor, action, detail))


def lead(db, rid):
    row = db.execute("SELECT r.*, s.status,s.owner,s.pilot,s.briefing,s.brief_state FROM requests r "
                     "JOIN sales s ON s.request_id=r.id WHERE r.id=?", (rid,)).fetchone()
    if not row:
        raise Missing()
    return row


def set_status(db, rid, status, actor):
    if lead(db, rid)["status"] != status:
        db.execute("UPDATE sales SET status=?,updated=? WHERE request_id=?", (status, now(), rid))
        event(db, rid, actor, "Status", status)


def timezone_name(zone):
    try:
        ZoneInfo(zone)
    except (ZoneInfoNotFoundError, ValueError, TypeError):
        raise ValueError("Choose a valid IANA time zone.") from None
    return zone


def local_time(start, zone):
    return datetime.fromtimestamp(start, ZoneInfo(zone)).strftime("%a, %d %b %Y at %H:%M %Z") + " (" + zone + ")"


def meeting_link(m):
    return ORIGIN + "/book-demo/schedule#" + m["token"]


def queue(db, rid, kind, due, subject, body, **extra):
    if extra.get("calendar"):
        extra["ics"] = demo_calendar.invitation(meeting(db,rid),lead(db,rid),extra["calendar"],inbox.founder())
    content = json.dumps(dict(subject=subject, text=body, **extra))
    db.execute("INSERT INTO mail(request_id,kind,due,content) VALUES(?,?,?,?)", (rid, kind, due, content))


def meeting(db, rid):
    return db.execute("SELECT * FROM demo_meetings WHERE request_id=?", (rid,)).fetchone()


def available(db, rid, starts, minutes):
    return starts > now() and not db.execute(
        "SELECT 1 FROM demo_meetings WHERE request_id!=? AND state='confirmed' AND starts<? "
        "AND starts+minutes*60>? LIMIT 1", (rid, starts+minutes*60, starts)).fetchone()


def cancel_pending(db, rid, prefix):
    db.execute("UPDATE mail SET cancelled=? WHERE request_id=? AND sent IS NULL AND cancelled IS NULL "
               "AND kind LIKE ?", (now(), rid, prefix+"%"))


def offer(rid, actor, starts, minutes, zone, location):
    timezone_name(zone)
    with inbox.delivery_lock(), transaction() as db:
        user = lead(db, rid)
        if user["status"] in ("Converted", "Not Proceeding") or completed(db, rid):
            raise Conflict("Scheduling is closed for this request.")
        old = meeting(db, rid)
        if old and old["state"] == "confirmed":
            raise Conflict("Cancel the existing appointment before issuing a new set of times.")
        starts = sorted(set(starts))
        if any(not available(db, rid, s, minutes) for s in starts):
            raise Conflict("One of those times is past or already booked.")
        if old and old["state"] == "offered" and (json.loads(old["offers"]), old["minutes"],old["zone"],old["location"]) == (starts,minutes,zone,location):
            return
        rev = old["revision"]+1 if old else 1
        token = secrets.token_urlsafe(32)
        db.execute("INSERT INTO demo_meetings(request_id,token,revision,state,offers,minutes,zone,location,updated) "
                   "VALUES(?,?,?,'offered',?,?,?,?,?) ON CONFLICT(request_id) DO UPDATE SET token=excluded.token,"
                   "revision=excluded.revision,state='offered',starts=NULL,offers=excluded.offers,minutes=excluded.minutes,"
                   "zone=excluded.zone,location=excluded.location,updated=excluded.updated",
                   (rid, token, rev, json.dumps(starts), minutes, zone, location, now()))
        m = meeting(db,rid)
        cancel_pending(db,rid,"offer/")
        queue(db,rid,f"offer/{rev}",now(),"Choose a time for your FindEZ AI demo",
              f"Hi {first_name(user)},\n\nChoose an available time for your walkthrough:\n{meeting_link(m)}\n\nThe FindEZ team", expires=max(starts))
        set_status(db,rid,"Meeting Pending",actor)
        event(db,rid,actor,"Times offered",str(len(starts)))


def first_name(user):
    return json.loads(user["details"])["name"].split()[0]


def public_meeting(db, token):
    m = db.execute("SELECT * FROM demo_meetings WHERE token=?", (token,)).fetchone()
    if not m:
        raise Missing()
    return m


def view_slots(token):
    with transaction() as db:
        m = public_meeting(db, token)
        slots = [] if m["state"] not in ("offered", "confirmed") else [
            s for s in json.loads(m["offers"]) if available(db,m["request_id"],s,m["minutes"])]
        return {"state":m["state"],"revision":m["revision"],"starts":m["starts"],"minutes":m["minutes"],
                "zone":m["zone"],"slots":slots,"location":m["location"] if m["state"]=="confirmed" else None}


def book(token, revision, starts, zone):
    timezone_name(zone)
    with inbox.delivery_lock(), transaction() as db:
        m = public_meeting(db,token)
        rid = m["request_id"]
        user = lead(db,rid)
        if m["state"] == "confirmed" and starts == m["starts"] and revision in (m["revision"], m["revision"]-1):
            return
        if (m["revision"] != revision or m["state"] not in ("confirmed","offered") or
                (m["starts"] and m["starts"] <= now()) or starts not in json.loads(m["offers"]) or
                not available(db,rid,starts,m["minutes"])):
            raise Conflict("That time is no longer available. Refresh the available times.")
        rev = revision+1
        cancel_pending(db,rid,"meeting/")
        cancel_pending(db,rid,"offer/")
        db.execute("UPDATE demo_meetings SET state='confirmed',revision=?,starts=?,zone=?,booked_once=1,updated=? WHERE request_id=?",
                   (rev,starts,zone,now(),rid))
        m = meeting(db,rid)
        when = local_time(starts,zone)
        info = f"{when}\nDuration: {m['minutes']} minutes\nMeeting: {m['location']}\nReschedule or cancel: {meeting_link(m)}"
        subject = "Your FindEZ AI demo is confirmed" if revision == 1 else "FindEZ AI demo appointment"
        name = first_name(user)
        queue(db,rid,f"meeting/{rev}/invite",now(),subject,f"Hi {name},\n\nYour demo is confirmed.\n{info}",calendar="REQUEST", expires=starts)
        queue(db,rid,f"meeting/{rev}/host",now(),"FindEZ AI demo booked",
              f"{json.loads(user['details'])['name']} ({user['email']})\n{info}",host=True,calendar="REQUEST", expires=starts)
        for hours in (24,1):
            due = starts-hours*3600
            if due>now():
                queue(db,rid,f"meeting/{rev}/reminder-{hours}",due,"Reminder: your FindEZ AI demo",
                      f"Hi {name},\n\nYour walkthrough is coming up.\n{info}",expires=starts-3600 if hours==24 else starts)
        set_status(db,rid,"Meeting Booked","prospect")
        event(db,rid,"prospect","Meeting confirmed",when)


def cancel(db, m, revision, actor):
    if m["state"]=="cancelled":
        return
    if actor == "prospect" and m["starts"] and m["starts"] <= now():
        raise Conflict("This appointment has already started.")
    if m["state"]=="completed" or m["revision"]!=revision:
        raise Conflict("The appointment changed. Refresh before cancelling.")
    rid=m["request_id"]
    cancel_pending(db,rid,"meeting/")
    cancel_pending(db,rid,"offer/")
    rev=revision+1
    db.execute("UPDATE demo_meetings SET state='cancelled',revision=?,updated=? WHERE request_id=?", (rev,now(),rid))
    if m["state"]=="confirmed":
        text = "The FindEZ AI demonstration scheduled for "+local_time(m["starts"],m["zone"])+" has been cancelled. Reply to arrange another time."
        for audience in ("visitor","host"):
            queue(db,rid,f"meeting/{rev}/cancel-{audience}",now(),"FindEZ AI demo cancelled",text,
                  calendar="CANCEL",host=audience=="host")
    set_status(db,rid,"Meeting Pending",actor)
    event(db,rid,actor,"Meeting cancelled")




def list_requests(db, search="", status="", category="", upcoming=False, offset=0):
    where = ["1=1"]
    args = []
    if search:
        where.append("(instr(lower(r.email),lower(?)) OR instr(lower(json_extract(r.details,'$.name')),lower(?)) "
                     "OR instr(lower(json_extract(r.details,'$.organization')),lower(?)))")
        args.extend([search]*3)
    if status:
        where.append("s.status=?")
        args.append(status)
    if category:
        where.append("coalesce(json_extract(r.details,'$.organization_type'),'Unspecified')=?")
        args.append(category)
    if upcoming:
        where.append("m.state='confirmed' AND m.starts>=?")
        args.append(now())
    query = """SELECT r.id,r.email,r.created,s.status,s.owner,json_extract(r.details,'$.name') name,
        json_extract(r.details,'$.organization') organization,json_extract(r.details,'$.organization_type') category,
        m.starts,m.state meeting_state FROM requests r JOIN sales s ON s.request_id=r.id
        LEFT JOIN demo_meetings m ON m.request_id=r.id WHERE """+" AND ".join(where)
    rows=db.execute(query+(" ORDER BY m.starts" if upcoming else " ORDER BY r.created DESC,r.id")+" LIMIT 51 OFFSET ?",[*args,offset]).fetchall()
    return {"items":[dict(v) for v in rows[:50]],"more":len(rows)>50}


def detail(db,rid):
    row=lead(db,rid)
    m=meeting(db,rid)
    return {"id":rid,"email":row["email"],"created":row["created"],"submitted":json.loads(row["details"]),
            "status":row["status"],"owner":row["owner"],"pilot":json.loads(row["pilot"]),
            "briefing":json.loads(row["briefing"]) if row["briefing"] else None,"brief_state":row["brief_state"],
            "meeting":(dict(event_id=demo_calendar.event_uid(rid), **{k:m[k] for k in ("revision","state","starts","minutes","zone","location")}) if m else None),
            "history":[dict(x) for x in db.execute("SELECT at,actor,action,detail FROM demo_events WHERE request_id=? ORDER BY id DESC",(rid,))],
            "mail":[dict(x) for x in db.execute("SELECT kind,due,attempts,sent,last_error,cancelled FROM mail WHERE request_id=? ORDER BY rowid DESC",(rid,))],
            "followups":[dict(x) for x in db.execute("SELECT * FROM demo_followups WHERE request_id=? ORDER BY rowid DESC",(rid,))]}


def metrics(db):
    def count(sql,*args):
        return db.execute(sql,args).fetchone()[0]
    n=count("SELECT count(*) FROM requests")
    booked=count("SELECT count(*) FROM demo_meetings WHERE booked_once=1")
    def status_set(status):
        return {r[0] for r in db.execute("SELECT DISTINCT request_id FROM demo_events WHERE action='Status' AND detail=?",(status,))}
    completed=status_set("Demo Completed")
    pilots=status_set("Pilot Discussion")
    converted=status_set("Converted")
    followed={r[0] for r in db.execute("SELECT DISTINCT request_id FROM mail WHERE kind LIKE 'followup/%' AND sent IS NOT NULL")}
    delivered=count("SELECT count(*) FROM mail WHERE kind='visitor' AND sent IS NOT NULL")
    return {"total":n,"organizations":dict(db.execute("SELECT coalesce(json_extract(details,'$.organization_type'),'Unspecified'),count(*) FROM requests GROUP BY 1")),
            "rates":{"Confirmation accepted by mail provider":[delivered,n],"Booked":[booked,n],
                     "Completed among booked":[len(completed),booked],"Followed up among completed":[len(completed & followed),len(completed)],
                     "Converted among pilots":[len(pilots & converted),len(pilots)]},"pilot_discussions":len(pilots)}


def followup_template(user, scenario):
    d=json.loads(user["details"])
    intro=f"Hi {first_name(user)},\n\nThank you for taking the time to meet with us and explore FindEZ AI."
    if scenario=="General":
        subject="Thank You for Exploring FindEZ AI"
        text=(f"{intro}\n\nIt was great learning more about {d['organization']} and how your team currently manages its physical inventory and engineering workflows.\n\n"
              "As discussed, FindEZ can help your team improve inventory visibility, discover available components, and connect physical inventory information with engineering workflows.\n\n"
              "If you'd like to explore FindEZ further, we'd be happy to discuss the next steps.")
    elif scenario=="Pilot":
        subject="Next steps for your FindEZ AI pilot discussion"
        pilot=json.loads(user["pilot"])
        text=intro+"\n\n"+"\n".join(label+": "+pilot[key] for key,label in PILOT_FIELDS if pilot.get(key))
        if not pilot.get("scope") or not pilot.get("next_action"):
            raise Conflict("Record a proposed pilot scope and next agreed action first.")
    else:
        subject="Following up on your FindEZ AI demo"
        text=f"Hi {first_name(user)},\n\nWould you like to continue our conversation about FindEZ for {d['organization']}? If now isn’t the right time, no action is needed."
    return subject,text+"\n\nBest,\nTanya\nFounder, FindEZ AI"


PILOT_FIELDS=(("scope","Proposed scope"),("use_case","Intended use case"),("participants","Participants"),
              ("onboarding","Onboarding requirements"),("next_action","Next agreed action"))


def completed(db, rid):
    return db.execute("SELECT 1 FROM demo_events WHERE request_id=? AND action='Status' AND detail='Demo Completed'", (rid,)).fetchone()


def stop_followups(db, rid, scenario=None):
    sql = "SELECT id FROM demo_followups WHERE request_id=? AND state IN ('draft','queued')"
    for row in db.execute(sql + (" AND scenario=?" if scenario else ""), (rid, scenario) if scenario else (rid,)).fetchall():
        cancel_pending(db, rid, "followup/" + row["id"])
        db.execute("UPDATE demo_followups SET state='cancelled' WHERE id=?", (row["id"],))


def update_status(db, rid, actor, status):
    user = lead(db, rid)
    if status == user["status"]:
        return
    if status not in STATUSES[4:]:
        raise Conflict("Request and booking statuses are set by their recorded events.")
    if status == "Demo Completed":
        m = meeting(db, rid)
        if not m or m["state"] != "confirmed" or m["starts"] > now():
            raise Conflict("Only a confirmed meeting that has started can be marked complete.")
        db.execute("UPDATE demo_meetings SET state='completed' WHERE request_id=?", (rid,))
        cancel_pending(db, rid, "meeting/")
    if status == "Follow-Up Required" and not completed(db, rid):
        raise Conflict("Mark the demo complete before requesting a follow-up.")
    if status in ("Converted", "Not Proceeding"):
        stop_followups(db, rid)
        m = meeting(db, rid)
        if m and m["state"] in ("confirmed", "offered"):
            cancel(db, m, m["revision"], actor)
    set_status(db, rid, status, actor)


def draft_followup(db, rid, actor, scenario):
    user = lead(db, rid)
    if not completed(db, rid) or user["status"] in ("Not Proceeding", "Converted"):
        raise Conflict("Follow-ups require a completed demo and an open prospect.")
    previous = db.execute("SELECT state FROM demo_followups WHERE request_id=? AND scenario=? AND state!='cancelled'",
                          (rid, scenario)).fetchone()
    if previous:
        return
    if scenario == "No response" and db.execute("SELECT 1 FROM demo_events WHERE request_id=? AND action='Response recorded'", (rid,)).fetchone():
        raise Conflict("A response is already recorded.")
    subject, body = followup_template(user, scenario)
    db.execute("INSERT INTO demo_followups(id,request_id,scenario,subject,body,due) VALUES(?,?,?,?,?,?)",
               (str(uuid4()), rid, scenario, subject, body, now()))
    event(db, rid, actor, "Follow-up drafted", scenario)


def approve_followup(db, rid, actor, draft_id, subject, body, due):
    row = db.execute("SELECT * FROM demo_followups WHERE request_id=? AND id=?", (rid, draft_id)).fetchone()
    if not row:
        raise Missing()
    if row["state"] in ("queued", "sent") and row["subject"] == subject and row["body"] == body:
        return
    if row["state"] != "draft":
        raise Conflict("This draft is no longer available for approval.")
    due = max(due or 0, now())
    db.execute("UPDATE demo_followups SET subject=?,body=?,due=?,approved_by=?,state='queued' WHERE id=?",
               (subject, body, due, actor, draft_id))
    queue(db, rid, "followup/"+draft_id, due, subject, body)
    event(db, rid, actor, "Follow-up approved", subject)
