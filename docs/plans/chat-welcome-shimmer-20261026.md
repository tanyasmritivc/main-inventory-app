# Chat welcome and progress polish

Remove only the web chat progress mascot and its reserved indentation. Keep the status disclosure, timing, received updates and cancellation behavior. Reuse ShinyText on whichever empty-chat heading is supplied, with a slower four-second left-to-right monochrome sweep. The heading remains an h1 and does not become a live status announcement. Existing reduced-motion, forced-colors, background-tab and offscreen handling remains in force. The mobile implementation is tracked in a separate lane. No API changes.

Initial release 7f5ba16 passed 633 tests, type checks, lint (52 pre-existing warnings), all five CI gates and 27 production route checks. It was published with the API unchanged. The user subsequently requested more frequent glimmer: retain the four-second sweep and reduce the pause to one second on both surfaces. Final timing release pending.
