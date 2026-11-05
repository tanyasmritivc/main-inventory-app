# Imported details and native controls182

Auto-extract Camera/Photo Library choices use a UIKit popover anchored to the actual composer plus control in logical screen coordinates. iPhone retains popover presentation; selection completes after dismissal, outside tap cancels, and accessibility Escape dismisses. Theme and text scaling are native. Other main Ask behavior is unchanged.

Imported details use a contained expandable panel, 12pt regular SF Pro values/11pt captions, with a bounded scrolling area and every original source field. Current item fields retain normal typography. Home bell/clock use 18pt light SF Symbols with their 44pt hit targets retained. JSON is accepted by the mobile import picker with the companion backend316 review support.

The backend correction retains vendor part identifiers in their source columns instead of presenting them as Where to buy. It preserves arbitrary typed columns and avoids guessing among duplicate headers. Spreadsheet files and Google Sheets exports are supported; no new live Google Sheets connector.

Validation and TestFlight182 receipt pending. Camera/library selection is checked using the actual UIKit simulator popover without invoking camera access. Physical iPhone acceptance remains unverified.
