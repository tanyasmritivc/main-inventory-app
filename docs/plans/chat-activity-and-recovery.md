# Chat activity and response recovery

The server previously emitted Preparing your response while waiting on model
reasoning and tool JSON. Fixed labels now describe actual stream/tool boundaries.
Planning labels never claim a search or save happened. Internal reasoning and tool
arguments are never sent to clients. A single still-working label per phase requires
continued chunks after 15 seconds; it is not a completion estimate.

The October 25 production failure logged output_limit followed by an unconfirmed
action claim. Transport retry and final answer correction shared one allowance.
They now have independent bounded allowances. Correction cannot execute tools.
Mutation/proposal summaries are emitted only after claim validation passes; ordinary
read-only text remains streamed. False repeated claims still fail closed.

No schema, provider, model budget, authorization, layout or navigation change.
65 focused tests and 1,535 full backend tests passed (existing deprecation warnings).
Production release awaits exact-source CI. Web card JSON transport is a separate lane.
