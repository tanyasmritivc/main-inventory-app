# Wave 8 onboarding review

The old sample tour and its unused flow file were removed. Onboarding now
starts with the camera. A photograph is held in app storage through sign-in,
then the authenticated extraction route returns the objects for review. The
place question appears only after that response. Objects needing an identity
must be corrected before save. The memory and Ask screens use the saved API
response, and connections are fetched from the relationship route.

The screenshots show welcome and the simulator camera error state in light
and dark. The simulator has no usable camera. The rest of the path requires
an authenticated extraction and save, so visual and fresh-account acceptance
remain open while migrations 036, 037 and 038 have never been executed and the
workspace backend has not been deployed. The connected iPhone is paired, but
its on-screen camera permission result has not been confirmed.

The extraction endpoint returns only a final result, not per-stage job status.
The running screen therefore shows one honest in-flight state rather than
timed stages. The organization photo-retention screen states the current
behavior; it does not offer a toggle because no retention-policy API exists.
Team invitations are available for an existing team. When the account has no
team, the screen gives the real empty state and points to team setup in More.
