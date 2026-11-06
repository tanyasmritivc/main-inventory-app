# Native notification sheet and direct camera — build 189

Notifications now presents a dedicated UIKit inset-grouped sheet with the same
system font roles, grouping, close control and grabber as the existing Chats and
Settings sheets. All entry points use it on iOS. Existing feed loading, unread
badges, mark-all-read, refresh/retry, invitation/task links and permission actions
remain owned by the existing Dart controller. Dismissing a linked destination
returns to the inbox; stable row IDs prevent refreshes from opening another row.

Chats and Settings retain their renderer, models, layout and typography. The only
change within the Settings source is its Notifications destination calling the
new presentation entry point. Shared NativePresentation and appearance sources
are byte-identical to build 188.

The two home suggestion chips are removed. Composer placeholder text is laid out
once per phrase and revealed with a frame-interpolated soft edge. Existing focus,
draft, hidden-tab, background and Reduce Motion guards remain. The accessibility
label stays stable while the visual placeholder animates.

The bottom-bar plus opens UIImagePickerController directly for capture. A native
UIKit overlay says “Take a photo to add items” and provides a Photos action using
PHPicker. The native shutter, camera-switch and cancellation controls remain.
Returning from Photos without a selection reopens the camera when permitted.
Denied camera access offers Photos, Settings or Cancel. A simulator without a
camera opens Photos. Selected images are orientation-normalized, resized to a
maximum 2048-pixel edge and JPEG-encoded before entering the existing Auto Extract
preview. Cancelling or disposing the caller discards late results. Nothing is
saved merely by opening the camera or selecting a photo.

Validation and delivery receipts are recorded separately. The synthetic debug
entry point `mobile/tool/native_inbox_camera189.dart` is not a production build
target. Physical-iPhone shutter/rotation/permission/VoiceOver acceptance remains
necessary; simulator Photos checks do not prove physical camera behavior. No
backend, database, AI pipeline or public App Store submission changes.

Validation completed: 1,293 Flutter tests passed with one existing skip; analyzer
clean. Native iOS compilation passed. Simulator UI review covered the light/dark
notification sheet, mark-read reflected on reopening, close/reopen, Photos
selection returning 315,806 encoded bytes, and cancellation returning null.
Protected Chats/Settings UI comparisons passed. Physical camera acceptance is
pending.

Apple validated and acknowledged TestFlight 1.1.2 (189), delivery `2964ea2b-d43b-4129-9f0b-3cdcf9619005`. Processing and tester availability were not polled. See the adjacent release JSON for source/package provenance.
