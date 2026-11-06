# Photo scan latency - November 5, 2026

The timeout repair prevents premature failure but does not shorten model inference. Auto Extract grounds up to eight objects, then identifies them in four two-crop batches. Two workers impose a second detail wave. The candidate permits all four existing batches to start together. The gateway models endpoint advertises ten simultaneous inference requests. Total calls, two-crop image resolution, model, prompts, output contracts, validation and explicit save are unchanged. Existing 110-second per-call and 240-second shared inference limits remain.

Experiments with direct completion mode and merged grounding/identification were not selected: direct mode still took 133.3 seconds on the workbench; merged analysis timed out on one run and produced a brand error in another. They are not in the patch. No lower-detail photos, omitted evidence fields, new provider or invented progress.

The concurrency regression uses a four-party barrier to prove all detail batches start before any finishes, and verifies ordered item association and confidence. Matched real-provider timings and release checks are pending. This change removes avoidable scheduling delay; it does not promise a fixed total scan duration under model load.
