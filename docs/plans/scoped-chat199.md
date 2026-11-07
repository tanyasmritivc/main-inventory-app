# Contextual chat, photo history and Space choices - build 199

## Behavior

The inventory-context chat sheet uses the existing WorldComposer, compact question
cards and refined assistant rendering, while retaining the authorized inventory
client. Voice, photo questions, streaming, stop, retry, history and reviewed item
actions stay on that boundary. The main Ask layout and composer are unchanged.
The iOS sheet keeps Cupertino drag dismissal, replaces the large title with a
secondary scope label, uses plain Cupertino icons, and reserves bottom safe-area
space even with the keyboard visible.

On the Space page, Ask FindEZ is a flat search-style pill. Review and Low quantity
are separate white rounded controls; counts and callbacks are unchanged.

Space context choices come from the authoritative world Spaces directory across
inventories, rather than presenting all inventory containers in a Spaces dropdown.
Deletion notifications, resume and the existing visible-page refresh reload the
choices and prune deleted selected Spaces. Failed reads retain the loaded list
and selection with a visible retry error. Inventories are not deleted or hidden
from inventory management.

History loading replaces the current conversation only after successful fetch and
conversion. A Photo conversation with no saved messages opens explicitly with a
retry explanation; it no longer falls back to the start screen. Saved extraction
drafts reopen using their existing card and conversation identity without writes.
The empty-history explanation is excluded from active extraction previews.

## Verification and delivery

Regression coverage includes scoped clients, immediate streaming, dismissal,
keyboard clearance, narrow/large-text layouts, deleted selections, refresh errors,
saved photo drafts, empty Photo conversations and failed history loads retaining
the retry prompt. Flutter 1331 pass/1 skip; analyzer clean. All 11 native checks passed, with both themes and keyboard screenshots inspected:

`context_chat_test.dart` and `space_chat_layout_test.dart` on the iPhone simulator.

No backend, database or web change is included. Physical iPhone acceptance remains
pending: open contextual Ask with/without the keyboard, swipe down, send a scoped
photo question, reopen a saved Photo draft, and delete a Space then revisit context
choices. Build and Apple upload evidence are recorded in the release receipt.
