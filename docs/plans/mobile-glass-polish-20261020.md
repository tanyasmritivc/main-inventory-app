# Mobile glass polish — build 102 candidate

The World shell now uses restrained frosted surfaces, fine highlights and soft
shadows, with warm orange/peach accents. Native iOS text/display typography keeps
regular body text and medium emphasis. The Ask landing stays sparse. Its three
navigation destinations use a slim floating icon bar with tooltips and semantic
labels; selection animates unless Reduce Motion is enabled.

Chat uses a compact composer, smaller right-aligned question bubbles and a
floating blurred header. Spaces uses separated rows instead of stacked cards.
More has consistent icons. Organization controls, review cards and the account
sheet share the same local visual theme. Glass surfaces become solid in high
contrast mode. This is a Flutter frosted treatment inspired by the reference,
not a claim to use Apple's proprietary Liquid Glass renderer.

Chat history now has local title search over loaded conversations, an empty and
no-results state, and a New chat control. It preserves scoped conversation reads,
existing swipe deletion and failure handling. At large text on short screens the
whole history page scrolls to retain access to every control. Existing drafts,
organization selection, captures, voice, confirmation and permission behavior
remain unchanged. No backend, web, schema, or customer-data changes are included.

All 18 native iOS simulator cases passed; eight previews were visually reviewed
and preserved. Final Flutter regression/analysis and signed delivery are in progress. Synthetic fixtures only; never use the
founder's account for testing. Physical-device appearance, VoiceOver and sustained
scroll/blur performance remain device acceptance checks. The separately reported
photo-to-inventory processing issue is outside this presentation change.
