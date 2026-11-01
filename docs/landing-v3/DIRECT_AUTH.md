# Direct landing authentication — October 24

Send now navigates immediately to `/signup?prompt=...`. A 160ms composer opacity
transition is nonblocking and disabled for reduced motion. Removed the inventory
demo component, its stylesheet, illustrative parser and animation pause callback.
Existing prompt bounds, draft recovery, auth/onboarding and editable Ask handoff
remain. No inventory is created by the public page.

Runtime: `33543a7d36a564e5dccbd94c7c851c7a43794893`, PR190.
Self-hosted directory: `/home/ubuntu/findez-web-releases/direct-auth-20261024/frontend`.
Build: `QbQGQXxQY5zOUd7kkZfdp`.
Receipt: `/home/ubuntu/findez-web-releases/direct-auth-20261024/deployment-receipt.json`.
Rollback retains the previous prompt-preview release and systemd override backup.

Validation: 483 tests / 62 suites, TypeScript, production compile and server build
passed; lint 0 errors / 52 unchanged warnings. All five CI jobs passed in
40117394503. Local compilation initially lacked public Supabase configuration;
its final compile used non-secret placeholders, never deployed. Server build used
existing production configuration. Twelve route statuses, six exact brand assets,
362 preserved files and unchanged backend PID verified. Live browser submitted
“Add 20 M3 screws” and opened Create account directly, retaining that prompt and
its sign-in link. No account, email, inventory or mobile binary created.

Manual verification: reload findez.ai, enter a prompt and click Send or press
Enter. Signup should appear directly, with the request shown above the form.
Sign in retains the request too. Browser Back restores the recent typed draft.
An empty submission stays in the composer; Shift+Enter remains a newline.
