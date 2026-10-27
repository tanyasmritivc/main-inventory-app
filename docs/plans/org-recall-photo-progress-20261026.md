# October 26 requested chat and capture updates

Extraction loader consumes real API progress, shows elapsed time during long stages, and retains stop/late-result protection. JSON API compatibility avoids resubmitting scans. Build 147 planned; focused tests pass and full/native validation is running. No public submission.

Validation: 1,185 host tests passed with one existing skip; analysis clean. Six native iOS checks pass, including real status updates, cancellation, Reduce Motion and large text. Three fake-clock-only success-hold assertions failed in the initial native import (wall clock advanced past the 600ms hold); these remain passing in the host suite and were excluded from the native rerun. Physical acceptance and Apple processing remain separate.
