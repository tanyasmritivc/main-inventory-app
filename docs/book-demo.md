# FindEZ product demo booking

The public marketing route is `/book-demo`. Set `FINDEZ_DEMO_CALENDLY_URL` in
the web service environment to the published 20-minute event URL. The page reads
this setting at request time. A missing or invalid URL shows the sales email
address. A video meeting room URL cannot supply availability.

Configure the host calendar, conflict checks and available hours in Calendly.
Select the authorized Zoom or Google Meet integration as the event location.
Keep the built-in confirmation screen, invitee confirmation, host notifications
and calendar invitation enabled. Calendly owns booking records, meeting links,
rescheduling and cancellations. To send additional messages, attach 24-hour and
1-hour reminders and a post-demo follow-up workflow to this event.

The page prefills name and email. Configure these six text questions on the event
in this order to carry visitor answers into the booking and host notification.

1. Company or organization
2. Job title or role
3. Organization type
4. Team size (optional)
5. What would you like to explore?
6. Which CAD software does your team use? (optional)

An invitee who stops before scheduling has not booked an appointment. Pilot
requests open an email draft to the published FindEZ contact address. Before
launch, verify an available slot, a real test booking, matching invitations,
video location, rescheduling and cancellation in the host account.
