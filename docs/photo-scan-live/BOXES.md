# Actual crop overlays - TestFlight 185

Build185 adds boxes to the existing build184 scan surface. It consumes optional
`scan_regions` events containing accepted normalized crop coordinates and actual
analysis states. Numbered outlines follow the visible photo's letterboxed bounds;
a brighter outline marks crops currently being read. Concurrent batches may
highlight multiple boxes. No guessed rectangles appear before grounding finishes.
Missing metadata retains the original plain sweep.

Stop, completion and a new scan remove/reset transient regions. Invalid,
duplicate and out-of-range coordinates are ignored; terminal crops cannot be
reactivated by replayed starts. Reduced motion disables overlay transitions.
Item ordering, edit/save payloads, existing scan/review UI and typography remain
unchanged. Backend PR321 supplies metadata without extra inference requests,
model/prompt changes, or changes to the restored 40/100-second limits and two
workers. No schema or inventory data changes.

Mobile runtime: fdb3dfc536598abfa64c1cf18214369bd41db80a (PR322).
Backend runtime: 177a807a592ad76daee1cdab88336e72674ad076, deployed with API/database
health passing and unrelated live source preserved.

Validation: 1,281 Flutter tests passed, one existing skip; analysis clean.
Geometry tests cover portrait/landscape and light/dark rendering. Parser tests
cover invalid metadata and replayed states. Chat tests cover incoming activity,
cancellation and late events without losing typed text. Two native iOS cases
produced four inspected captures (light/dark and reduced motion). These use
synthetic activity over the supplied prototype photo; fresh live-model and
physical-device acceptance are not claimed. Backend full suite has 1,542 passes;
final staged production-source suite has 58 passes. Both runtime commits passed
all five CI gates (backend42161346041, mobile42161649041). A callback scheduling
race found by CI was fixed before deployment.

Signed production IPA/archive: 33 device executables verified in each,
27 privacy manifests, strict signatures and production configuration verified.
Apple validation passed. Upload acknowledgment is recorded separately;
processing and tester availability are not polled. The public App Store
submission stays unchanged.

Apple acknowledged upload of 1.1.2 (185), delivery
`34bbbcc1-2e1d-4ced-ae7c-1e24ad5bd17d`. See `boxes185-delivery.json`.
