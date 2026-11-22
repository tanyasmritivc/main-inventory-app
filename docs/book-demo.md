# FindEZ product demo booking

The public marketing route is `/book-demo`. Its 20-minute FindEZ Product Demo uses
`https://calendly.com/tanya-findez/30min`. To switch events, set
`FINDEZ_DEMO_CALENDLY_URL` in the web service environment. The page reads
this setting at request time. A missing or invalid URL shows the sales email
address. A video meeting room URL cannot supply availability.

Configure the host calendar, conflict checks and available hours in Calendly.
Select the authorized Zoom or Google Meet integration as the event location.
Keep the built-in confirmation screen, invitee confirmation, host notifications
and calendar invitation enabled. Calendly owns booking records, meeting links,
rescheduling and cancellations. To send additional messages, attach 24-hour and
1-hour reminders and a post-demo follow-up workflow to this event.

The published event has one free-text preparation question. Keep that question
first on the event. The site prefills name and email and sends organization,
role, organization type, team size, demo interest and CAD software together
in the preparation answer. The invitee can review and edit it before confirming.

An invitee who stops before scheduling has not booked an appointment. Pilot
requests open an email draft to the published FindEZ contact address. Before
launch, verify an available slot, a real test booking, matching invitations,
video location, rescheduling and cancellation in the host account.
