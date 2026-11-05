# Imported details and native controls182

Auto-extract Camera/Photo Library choices use a UIKit popover anchored to the actual composer plus control in logical screen coordinates. iPhone retains popover presentation; selection completes after dismissal, outside tap cancels, and accessibility Escape dismisses. Theme and text scaling are native. Other main Ask behavior is unchanged.

Imported details use a contained expandable panel, 12pt regular SF Pro values/11pt captions, with a bounded scrolling area and every original source field. Current item fields retain normal typography. Home bell/clock use 18pt light SF Symbols with their 44pt hit targets retained. JSON is accepted by the mobile import picker with the companion backend316 review support.

The backend correction retains vendor part identifiers in their source columns instead of presenting them as Where to buy. It preserves arbitrary typed columns and avoids guessing among duplicate headers. Spreadsheet files and Google Sheets exports are supported; no new live Google Sheets connector.

Apple acknowledged TestFlight 1.1.2 (182), delivery 9f85977b-6b92-4d38-abd5-dc1b30fdb13a. Processing/tester availability pending and unpolled. All five exact-source CI gates passed (run 41979826041). 1,379 Flutter tests passed (one existing skip), analyzer clean; 12 native checks passed across anchored source selection, imported details and home controls. Signed archive/export and Apple validation passed. Source a06cb8db14a1315cd33556ee02c00bba17c85db8. Physical iPhone acceptance remains unverified. See docs/import182/testflight182-receipt.json.

Native camera/library selection was tested without opening real camera or library access. Simulator fixtures use disposable data and Flutter captures omit UIKit platform views. The full item-sheet capture verifies the compact panel in context. Backend PR316 is deployed with authenticated HTTPS and live-source regression checks. Google Sheets exports use CSV/XLSX; there is no new live Sheets connector.
