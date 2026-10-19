# Chat latency diagnosis - October 19, 2026

## Confirmed findings

The user reported long waits on the public iOS app for "what do i have" and
"what else do i have". Apple API confirms public iOS 1.0.8 uses build 95,
build ID 375271f5-080e-429c-9054-8b42518280df, the same signed binary uploaded
to TestFlight on October 18. This confirms binary identity; it does not prove
which build was installed for every earlier user observation.

Read-only inspection of the affected conversation found these intervals from
saved user message to saved assistant answer:

| Prompt | User message timestamp (UTC) | Answer saved after |
| --- | --- | --- |
| what do i have | 2026-10-19 22:02:25.215 | 81.434 seconds |
| what else do i have | 2026-10-19 22:04:07.897 | 42.956 seconds |

An earlier request at 22:01:59.825 has no stored assistant answer; its cause was
not established. No customer message contents beyond the reported prompts or
inventory records are included in this receipt.

The same authorized inventory context was measured in a separate read-only
process: authorization 0.054 seconds, preferences 0.009 seconds, full context
load 0.022 seconds. Context held one saved item. The nginx API location has
proxy_buffering off; the endpoint also requests X-Accel-Buffering: no. Mobile
uses ai_command?stream=true and consumes incremental events. The deployed
agent/client/route hashes match the inspected source.

## Configured model probes

Synthetic one-item inventory, both reported prompts, real configured gateway
https://agent.ftctools.com/v1, model deepseek-v4-flash-agent. All repository
reads/writes, state persistence and tool writes were mocked in the probe;
only model requests reached the configured gateway. No production app source,
configuration, permissions, or customer data was changed.

Baseline:

- First question: model tool selection 6.300 seconds; final generation
  28.663 seconds (first upstream event 27.846 seconds); total 34.965 seconds.
- Follow-up: selection 6.448 seconds; final generation 36.870 seconds
  (first upstream event 35.846 seconds); total 43.319 seconds.
- The gateway returned 47-58 events per baseline model call, so the older claim
  that this gateway only sends one batched event is not current for these probes.
  Receiving multiple events does not eliminate its long wait before the first.

Two diagnostic-only variants were evaluated and NOT deployed:

- Explicit fresh/complete snapshot guidance avoided the extra tool round trip,
  but totals remained 35.805 and 63.750 seconds. It did not establish an improvement.
- Documented RunOptions enabled_tools=[] and max_steps=1 preserved the supplied
  application tool call but took 99.566 seconds for the first question (32.113
  seconds selection, 67.450 seconds final generation). The follow-up probe was
  stopped to avoid unnecessary calls. This option was not an effective remedy.

These measurements localize the major wait inside the external model gateway,
before response events reach FindEZ. They do not distinguish gateway queue time,
GPU contention, prompt prefill, hidden generation, or internal orchestration.
No claim of a resolved latency bug is made. Do not add scripted answers or
fallback models to mask this delay.

## Operator investigation needed

The user confirms someone else manages the gateway. Provide that operator with:

1. The UTC timestamps and measured delays above, model name and streaming flag.
2. A request to separate queue wait, prefill, generation and time to first output
   for /v1/chat/completions, including requests with caller-provided tools.
3. A comparison with October 18 gateway deployment/model-routing, capacity and
   load. The user's yesterday/today observation alone does not identify a change.
4. A check that answer text is forwarded as it is generated instead of being
   retained until an internal agent stage completes.

The gateway's public /healthz returns status ok, version 1.3.0. Health does not
measure completion latency. Its published /openapi.json documents RunOptions;
no undocumented model parameters, model switch or provider replacement was used.

The local diagnostic script is private at /private/tmp/findez-chat-latency-probe.py;
it contains a scoped diagnostic identity and must not be committed or shared.
No message was sent to the external operator. This is a documentation-only
investigation; no new app binary or production restart is required.
