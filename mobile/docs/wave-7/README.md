# Wave 7 See review

Live See recognition is gated. The backend has no frame inference service, and
the required p50 latency against a real workspace could not be measured. The
`/vision/observe` route returns unavailable. Shipping a live viewfinder that
waits on the photo job would misrepresent the result and could hang.

The light and dark simulator screenshots show the unavailable state. It says
that nothing is saved and offers Photo. See does not persist as the default
Capture mode, so reopening Capture returns to a usable mode. A widget test
checks that behavior and the Photo fallback.

The connected iPhone is paired, but the camera permission denied path still
needs a visual check on the device. Live See cannot pass its shelf recognition
acceptance until a measured backend service exists.
