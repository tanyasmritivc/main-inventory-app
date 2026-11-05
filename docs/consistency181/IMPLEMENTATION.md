# Mobile consistency181

Main Spaces directory typography is the reference: regular native SF Pro, 16pt body/control text and 13pt secondary text, preserving deliberate page headings and quantity emphasis. Remove the detail-only15/12pt override; item names and Space Ask prompts now use ordinary sizes. System text scaling remains supported.

The organization pill is opaque neutral grey in both themes. Its compact menu opens immediately with a static loading row while its authenticated directory request runs, offers retry on failure, and checks account identity before selection. Shared inventory choosers use a small grey Choose label and stacked rows. More rows have tighter spacing. Workspace names use a restrained20pt heading and the shell theme.

Inventory-level Ask now uses the current WorldComposer and full-viewport blur, retaining its original authorized inventory client, history, sources and cancellation. Empty Spaces omit search/sort metadata, duplicate Ask actions and Showing0of0; Review remains available because pending photos can exist without saved items. The bottom + remains the entry point.

The mobile pending label is neutral Thinking. Separate backend PR314/runtime39d3c46 removes the unconditional organization directory read, leaving the AI to select tools when useful. It is deployed with1,495 backend tests, all five CI gates, real-model no-tool greetings and authenticated HTTPS verification. No scripted greeting, schema change or change to extraction routing.

Apple acknowledged TestFlight 1.1.2 (181), delivery f1876ea2-5e32-49a0-8ece-59089bb4ad88. Processing/tester availability pending and unpolled. All five exact-source CI gates passed (run 41976263542). 1,379 Flutter tests passed (one existing skip), analyzer clean; 61 native checks passed across menus, typography, Space, inventory Ask and workspaces. Signed archive/export and Apple validation passed. Source 1d4888c1fce3020322ecedb878e94db7f7a6294d. Physical iPhone acceptance remains unverified. See docs/consistency181/testflight181-receipt.json.

Simulator fixtures use disposable data and simulated keyboards; Flutter captures omit UIKit platform views. Native tab fixture callbacks are not proof of tab hit testing. Production AI QA used disposable authenticated accounts removed after verification: hi/thanks selected no tools; a directory question selected one directory call. A live HTTPS greeting completed successfully. Model response time remains variable.
