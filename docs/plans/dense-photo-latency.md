# Crowded photo latency investigation — not deployed

The user reported that the deployed crowded-photo scan still takes too long. The coverage release is live, but it did not solve latency. This investigation found no safe, reliable speed improvement. All experimental runtime and test changes were restored exactly to base 2c0e34c5. Production was never modified by these experiments.

## Measurements

All measurements used the user's converted mechanical-parts JPEG in an isolated candidate copied from the running backend. Inference used the existing configured gateway/model and performed no inventory writes or storage uploads. Results and the private photo remain outside the repository.

| Candidate | Seconds | Detected regions | Identified | Unknown |
| --- | ---: | ---: | ---: | ---: |
| Prior deployed coverage-release sample | 218.88 | 58 | 47 | 11 |
| Four crops per detail call, more workers | 240.19 | 70 | 41 | 29 |
| Combined close-up grounding and identity | 240.26 | 20 | 17 | 3 |
| Short overview, original two-crop batches, more workers | 240.28 | 50 | 39 | 11 |
| Classifier fallback, 512-pixel hint | 231.54 | 25 | 16 | 9 |
| Classifier fallback, 256-pixel hint | 223.23 | 30 | 23 | 7 |
| Forced parallel overview and close-ups, two-crop details | 225.51 | 51 | 40 | 11 |

These are individual runs with variable model output, not a controlled accuracy benchmark or a general speed guarantee. All results were partial. A higher region count does not establish higher accuracy; no ground-truth recall claim is made. The final parallel trial took longer and identified fewer regions than the prior release sample, so it was rejected.

## Findings and constraints

The original path performs full-photo localization, overlapping close-up localization, then crop identification. The gateway's image requests have substantial and inconsistent generation latency. Some localization calls took 60–110 seconds or timed out. A small density classification succeeded in standalone probes (0.57, 0.62 and 4.81 seconds), but timed out at ten seconds inside repeated extraction trials; it is unsuitable as a required scheduling dependency.

The configured gateway advertises only one vision-chat model, glm-5.3-flash-agent. Its other advertised model is for image generation. The published gateway request/options schema does not expose a thinking-budget control. No undocumented parameter, alternate provider, new credential, smaller detection cap or silent quality reduction was shipped. A meaningful model-level speedup requires a faster supported vision endpoint or a supported way to reduce that model's reasoning time, followed by another representative accuracy/latency check. UI progress messages alone cannot shorten the inference.

## Validation and release status

The rejected final classifier/parallel candidate passed 67 focused tests and 1,573 backend tests. A previous combined candidate passed all five CI jobs at b25d1c72349a629ffe3707f84c482eaa97d5d76c (run 42451933060); passing tests did not establish acceptable real-photo performance. Neither candidate was deployed.

The service and both modified test files were restored byte-for-byte to 2c0e34c5. Final runtime diff against that base is empty. Production extraction was independently checked and remains SHA256 b23f1ff84ab4a81208efc1b9e907984a163210e025cfe7f48e62dda0134fec3b with systemd findez active. No main-chat, web, mobile, database, saving or destination behavior changed; no new TestFlight binary is needed for this documentation-only outcome. Latency remains unresolved.
