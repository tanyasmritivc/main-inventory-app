"""Calendar invitation adapter for founder-supplied availability and meeting locations."""
from datetime import datetime, timezone


def event_uid(request_id):
    return "demo-" + request_id + "@findez.ai"


def invitation(m, user, method, organizer):
    """RFC 5545 UTC event with a stable UID, monotonic SEQUENCE and folded UTF-8 lines."""
    def utc(ts):
        return datetime.fromtimestamp(ts,timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    def escape(s):
        return s.replace('\\','\\\\').replace('\n','\\n').replace('\r','').replace(';','\\;').replace(',','\\,')
    lines=["BEGIN:VCALENDAR","PRODID:-//FindEZ AI//Product Demo//EN","VERSION:2.0","METHOD:"+method,
           "BEGIN:VEVENT","UID:"+event_uid(m["request_id"]),"SEQUENCE:"+str(m["revision"]),
           "DTSTAMP:"+utc(m["updated"]),"DTSTART:"+utc(m["starts"]),"DTEND:"+utc(m["starts"]+60*m["minutes"]),
           "SUMMARY:FindEZ AI Product Demo","LOCATION:"+escape(m["location"]),"ORGANIZER:mailto:"+organizer,
           "ATTENDEE:mailto:"+user["email"],"STATUS:"+("CANCELLED" if method=="CANCEL" else "CONFIRMED"),
           "END:VEVENT","END:VCALENDAR"]
    result=[]
    for line in lines:
        part=""
        for char in line:
            if len((part+char).encode())>75:
                result.append(part)
                part=" "
            part+=char
        result.append(part)
    return "\r\n".join(result)+"\r\n"
