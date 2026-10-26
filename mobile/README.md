# FindEZ mobile

Flutter iOS client for AI item recognition and inventory search. FindEZ serves
households, businesses, labs, schools, teams, and industry.

From `mobile/`:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --coverage
```

Runtime configuration uses `API_BASE_URL`, `SUPABASE_URL`, and
`SUPABASE_ANON_KEY` Dart defines. Use your isolated development services for
local work and pass public client values through `--dart-define-from-file`.
Keep server credentials out of the client. Production builds must use verified
production origins and must not enable `PREVIEW_ONBOARDING`.

See [TESTING.md](../TESTING.md) for native and physical-device release checks,
and [the architecture](../.agents/ARCHITECTURE.md) for backend boundaries.
