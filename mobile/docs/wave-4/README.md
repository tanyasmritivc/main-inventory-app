# Wave 4 capture review

These six light and dark simulator screenshots show Photo, Scan and See on an
iPhone 17 Pro. The simulator has no camera, so Photo and Scan show their camera
unavailable states. The place name comes from a test API in a temporary preview
harness outside the app. No preview value is compiled into the product.

The signed capture preview was installed on a connected iPhone. The first
Flutter debug launch stopped in LLDB, while a direct device launch succeeded.
Camera permission denied, live viewfinder, photo save and barcode save still
need on-device acceptance. The workspace backend is not deployed, so this
preview cannot prove an end-to-end save.
