# Private tool markup in model content

GLM sometimes emits serialized tool instructions in ordinary content rather than native tool_calls. The shared completion stream now withholds possible control-tag prefixes across chunk boundaries and rejects confirmed tool/argument/reasoning markup before display. It never executes textual instructions. Native tool calls still use the existing authorized executor and receipts.

World chat retries malformed formatting once with a fixed native-tool reminder, retaining completed-action receipts. Repeated malformed generations fail safely. Ordinary comparisons, unrelated HTML and similarly named tags remain supported.

118 focused tests and 1,599 backend tests plus 10 subtests passed. Five CI gates passed on runtime 052c81f (run 40434724135, PR249). Deployed two source files to the self-hosted API, preserving 127 unrelated files and all schema/configuration. API/database health and anonymous-access denial passed. Live authenticated Safari inventory question completed normally with 12 records and resource links.

Prior personal-group conversation receipt fix e53d6ea remains live; this does not implement reusable groups or rewrite old failed messages. Receipt: private-tool-markup-receipt.json.
