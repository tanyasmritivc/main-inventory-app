# Personal-group completion context

Safari exposed an integration gap in the immediate unsupported-personal-group answer: the backend persisted the text, but its completion event omitted conversation_id. The web client requires that ID before accepting an answer and therefore displayed an interruption. Normal model responses already include it.

The fast path now includes the authorized conversation ID. A regression test exercises the actual service through the HTTP SSE route and verifies the conversation, persisted message ID, timestamp and truthful answer without model/tool calls. A second test verifies that storage failure produces an error, never a successful completion.

This corrects delivery only. Durable named personal groups remain unsupported; the response says so and does not modify inventory. No migration or production configuration change is required. Full local backend tests: 1,582 passed plus 10 subtests; 79 focused tests passed. Publication requires all five CI gates and live verification.

Deployed runtime e53d6ea after all five gates passed (40432773207). Live Safari fresh-chat verification at 18:36 Pacific confirmed the complete answer and response controls without interruption. See delivery receipt.
