# Consistent mobile typography - build 179

The prior size rule covered only explicit 14-17pt styles. Plain Flutter Text widgets and inherited DefaultTextStyle sizes could bypass it, and voice/native list text had separate defaults. This change routes 505 plain app-owned text widgets through AppText across 57 files, resolves inherited size before normalization, and aligns voice/native list text with the same regular SF Pro body size.

Ordinary text, inputs and controls use 16pt with regular weight and neutral body letter spacing. Caption styles from 12-13.5pt use 13pt; 20-23pt titles use 20pt. Deliberate larger hero/headline values and small badge/icon lettering retain their scale. System and saved app text scaling remain intact. Camera/Library popup title uses the shared 20pt title size. Native lists use 16pt body and 13pt detail/footer text.

All changes are mobile typography and its verification. Navigation, capture, inventory, chat requests, API contracts, web and backend are unchanged. Full regression, native layout checks and delivery evidence are recorded below when complete. Physical iPhone acceptance is unverified.

## Verification notes

The first full Flutter run passed 1,368 tests with one existing skip. The native capture harness initially included an exact fake-clock voice-duration assertion, which differs by 1ms on a real clock, and screenshot file I/O consumed a live countdown before tapping Edit. The final native selection excludes fake-clock-only timing checks, and the visual fixture freezes its injected clock during PNG capture only. All 13 voice unit checks pass, including the exact two-second behavior; production voice timing is unchanged.
