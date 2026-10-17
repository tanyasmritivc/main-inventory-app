# Contained web dashboard

The empty inventory dashboard used uncontained sections and repeated detached
actions. Recently added and Spaces now use a consistent two-column panel layout,
with clear section headers, contained empty states and rows that retain the
existing item/Space links. Narrow screens stack the panels. Existing application
fonts and light/dark tokens are reused. Capture, search, refresh, inventory scope,
partial-load errors, attention counts and the underlying APIs are preserved.
Viewer empty states no longer offer creation actions.

Runtime files: frontend/src/components/site/home-overview.tsx and the new scoped
home-overview.module.css. Shared global styles, navigation, public homepage,
mobile and backend are unchanged. No database or customer-record changes.

Validation: 327 Jest tests across 45 suites pass with coverage; TypeScript passes;
changed-file lint has no errors (existing unused-variable/raw-image warnings).
Three added behavioral cases cover owner/viewer empty actions and failed loading
without a false empty state. A final focused run follows accessible View all
labels. A production webpack build and self-hosted visual acceptance are pending.
