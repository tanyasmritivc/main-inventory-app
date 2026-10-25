# Proactive missing destinations — October 24, 2026

The first strawberries/Fridge message previously produced an unsaved draft and a
question listing unrelated inventories. Destination-creation guidance only applied
to a draft present at the start of the turn; the tool list also stayed frozen after
creating a draft, leaving refinement unavailable until another message.

The API now provides first-turn creation guidance, refreshes draft capabilities
within the tool loop, and rejects duplicate direct additions after drafting even
inside one tool batch. A unique existing Space is reused; a missing Space or
inventory gets a reviewed creation proposal. Explicit parents are retained,
Personal has a simple proposed default, and ambiguous organizational parents get
one short question. Existing capture drafts keep counts/photos/Review evidence,
with destination-only creation and explicit stock saving afterward. A complete
new task can include its items in the creation card. No schema or client changes.

Validation and delivery receipts will be recorded after release gates complete.
