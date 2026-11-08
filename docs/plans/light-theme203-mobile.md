Mobile light-mode readability update, build 1.1.2 (203).

Keep the user-selected #F6F8F9 canvas with white cards. Replace pure-white shell/directory backgrounds and the shell wash with the shared canvas. Use softer charcoal primary text and readable neutral gray secondary text. Shared dividerColor and dividerTheme now agree, with opaque separators and separate stronger control outlines. Workspace lists, announcement tables, contextual Ask, Space action pills and native Settings/Notifications list separators use visible light-mode boundaries. Plan cards use a flat white light surface. Dark styling and application behavior remain unchanged.

Contrast regressions exercise secondary labels and chevrons on actual surface colors, separators at 2:1 or more, control outlines at 3:1 or more and text at 4.5:1 or more. Existing large-text and light/dark flow tests remain. Native visual checks cover Ask, attachments, Spaces, item details, Settings and Founders Access; all 19 checks passed and screenshots were reviewed.

No web/backend/database changes. No changes to scan/chat processing or account flows.

Delivery: Apple acknowledged signed build 1.1.2 (203), delivery d36695e4-04b5-4da8-9ae7-b24a994cc977. PR354; source 1bda45645f51b0a97fe9d981234f0bca6e242d94; CI42436247397 passed all five jobs, including 1,340 Flutter tests / 1 skip and clean analysis. The local full suite was interrupted by disk exhaustion; complete exact-commit CI is the full-suite evidence. Xcode cache cleanup and removal of verified duplicate unpacked release copies resolved local disk exhaustion; original IPAs, archives and receipts were retained. The native Spaces visual fixture now explicitly waits for its loaded data before capture.

Strict signing, production configuration, all 33 device executables in both archive/export and 27 privacy manifests verified. Processing/tester availability not polled; physical iPhone acceptance pending. See mobile203-release.json.
