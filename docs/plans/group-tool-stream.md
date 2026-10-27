# Group requests and tool stream recovery

The reported personal-group prompt repeatedly hit `tool_index` in live logs.
The parser admitted only indices 0-3; five legitimate lookups failed at index 4.
Allow up to 16 bounded calls per completion. Existing argument, round, mutation,
authorization and confirmation limits remain unchanged; malformed indices fail closed.

An isolated real-model probe with synthetic inventory also tried to substitute a
world_create_task for unsupported durable personal-group memory. Execution was
blocked. The exact explicit request now returns a short truthful capability
explanation after world authorization, without model retries or inventory writes.
The model instruction applies the same limitation to paraphrases. This does not
implement reusable personal groups or alter saved personalization preferences.

Validation: 78 focused tests; 1,580 full backend tests and 10 subtests passed.
Includes five-call assembly, malformed indices, fast response with no model/tool
calls, authorization denial, existing receipt validation and retry safety.
Deployment is pending exact-source CI and a guarded two-file release. No schema
or configuration change is required. Preserve unrelated live source and retain
backups for rollback. Web controls are a separate release.
