# AI-directed inventory lookups

World chat previously loaded the authorized organization directory before every turn, including greetings. It did not eagerly read every item at this point, but the status text suggested that it did. The directory is now the existing AI-selected `world_directory` tool. Ordinary conversation still goes to the model with all applicable tools available; there is no keyword classifier or scripted greeting. Initial status is Thinking. Upfront authorization and fresh authorization on every tool remain.

Validation: 1,495 backend tests pass, including model-generated direct replies with no directory/tool calls, AI-requested directory access, and rejection before model invocation for unauthorized worlds. Production has newer unrelated chat features; deploy only these specific edits onto the verified live file and retain rollback. No schema changes. Deployment receipt pending.
