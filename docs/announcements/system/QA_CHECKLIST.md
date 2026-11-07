# FindEZ Announcement System — QA Checklist

## Founders Access
- [ ] New account sees Founders Access only after auth and app initialization.
- [ ] Existing user rollout can be targeted once.
- [ ] Dismissal persists across logout/login.
- [ ] Dismissal persists across reinstall/device change if backend state is used.
- [ ] It does not reappear on every login or app resume.
- [ ] Plan label and comparison values match actual entitlement configuration.
- [ ] No unsupported “free forever” or lifetime promise.
- [ ] Saved-item retention promise is verified before displaying.

## Product updates
- [ ] Published major update appears on first eligible session.
- [ ] User sees each campaign at most once after acknowledgement.
- [ ] Multiple pending updates do not stack.
- [ ] Global 7-day cap is honored.
- [ ] Expired, unpublished, or ineligible announcements do not appear.
- [ ] Platform-specific feature announcements are targeted correctly.

## Founders announcements
- [ ] Only real, published announcements appear.
- [ ] Max one founders announcement per 30 days per user.
- [ ] Product update within the last 7 days causes founders announcement to queue.
- [ ] Dismissed campaign does not repeat.
- [ ] No fake milestone or invented user-count copy.

## Session and UX
- [ ] No announcement appears over auth screens.
- [ ] No announcement appears during app loading/error.
- [ ] No modal appears during active capture/import/upload/edit/chat streaming.
- [ ] At most one non-critical modal appears in a session.
- [ ] No duplicate modal from Flutter rebuilds or route changes.
- [ ] Close, CTA, and Got it buttons work.
- [ ] Modal respects safe areas, screen size, scrolling, and accessibility.
- [ ] Dark and light variants match supplied designs.
- [ ] Modal remains usable with large text/accessibility settings.
- [ ] Web behavior is responsive if web is included.

## Data/security
- [ ] User can only read their own announcement state.
- [ ] Campaign IDs are stable and unique.
- [ ] Duplicate impressions/dismissals are idempotent.
- [ ] RLS and server-side eligibility are correct.
- [ ] No sensitive inventory details appear in analytics.
- [ ] Announcement system can be disabled safely.

## Regression
- [ ] Sign-up/sign-in still work.
- [ ] Existing plan/account behavior unchanged.
- [ ] Inventory, chat, scan, photo capture, and import still work.
- [ ] No production deploy without explicit approval.
