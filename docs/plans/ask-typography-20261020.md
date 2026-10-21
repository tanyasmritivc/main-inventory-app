# Ask typography correction — build101 candidate

The reference has a smaller, lighter heading and regular input text. Mobile Ask
now uses the native iOS display face at24pt/medium with tighter tracking. The
composer uses17pt regular text, and the organization pill and tab labels have
explicit lighter weights. The shared existing typography policy is applied below
the Ask route, so inherited OS Bold Text cannot replace every label with700.
Text scaling and all other accessibility flags remain intact.

Only typography and build metadata change. Background, controls, navigation,
API behavior, organization boundaries and existing customer data are untouched.
The exact proprietary reference font cannot be verified from a screenshot; this
uses native iOS SF system text/display faces to match its visible proportions.

35 targeted typography, appearance, world navigation and Chat tests pass;
Flutter analysis is clean. Native16-case rendering/interaction suite and CI are
in progress. Build101 will reuse the published build100 API/migration073.
No new database migration or public App Store submission.
