import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/pro_status.dart';
import 'package:mobile/core/api_client.dart';

/// Stub that extends ApiClient and overrides only getMyLimits().
class _StubApi extends ApiClient {
  _StubApi(this._response) : super(baseUrl: 'http://localhost');

  final Map<String, dynamic>? _response;

  @override
  Future<Map<String, dynamic>> getMyLimits() async {
    if (_response == null) throw Exception('Network error');
    return _response;
  }
}

Map<String, dynamic> _pilotPayload({
  String? endsAt = '2026-09-11T23:59:59Z',
  String? notice =
      'Free Pilot: Unlimited access through September 11, 2026. '
      'Standard free-plan limits and optional paid plans begin September 12. '
      'You will not be charged automatically.',
}) =>
    {
      'tier': 'free',
      'pilot_mode': true,
      'pilot_ends_at': endsAt,
      'pilot_notice': notice,
      'items': {'used': 0, 'max': null},
      'spaces': {'used': 0, 'max': null},
      'chats': {'used': 0, 'max': null, 'resets_at': '2026-10-01T00:00:00Z'},
      'scans': {
        'used': 0,
        'max': null,
        'daily_used': 0,
        'daily_max': null,
        'resets_at': '2026-10-01T00:00:00Z',
      },
    };

Map<String, dynamic> _nonPilotPayload() => {
      'tier': 'free',
      'pilot_mode': false,
      'pilot_ends_at': null,
      'pilot_notice': null,
      'items': {'used': 5, 'max': 30},
      'spaces': {'used': 1, 'max': 3},
      'chats': {'used': 3, 'max': 20, 'resets_at': '2026-10-01T00:00:00Z'},
      'scans': {
        'used': 2,
        'max': 10,
        'daily_used': 1,
        'daily_max': null,
        'resets_at': '2026-10-01T00:00:00Z',
      },
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProStatus.reset();
  });

  group('ProStatus — pilot mode active', () {
    test('isPilotMode is true after refresh with pilot_mode=true', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      expect(ProStatus.isPilotMode, isTrue);
    });

    test('pilotEndsAt is populated', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      expect(ProStatus.pilotEndsAt, '2026-09-11T23:59:59Z');
    });

    test('pilotNotice contains the required text', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      expect(ProStatus.pilotNotice, contains('September 11, 2026'));
      expect(ProStatus.pilotNotice, contains('not be charged automatically'));
      expect(ProStatus.pilotNotice, contains('September 12'));
    });

    test('isPro is false — pilot is not a paid tier', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      expect(ProStatus.isPro, isFalse);
    });

    test('tier remains free', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      expect(ProStatus.tier, 'free');
    });

    test('pilot fields are persisted to SharedPreferences', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pilot_mode'), isTrue);
      expect(prefs.getString('pilot_ends_at'), '2026-09-11T23:59:59Z');
      expect(prefs.getString('pilot_notice'), isNotNull);
    });

    test('loadCached restores pilot fields without a network call', () async {
      SharedPreferences.setMockInitialValues({
        'plan_tier': 'free',
        'pilot_mode': true,
        'pilot_ends_at': '2026-09-11T23:59:59Z',
        'pilot_notice': 'Cached notice text',
      });
      ProStatus.reset();
      await ProStatus.loadCached();
      expect(ProStatus.isPilotMode, isTrue);
      expect(ProStatus.pilotEndsAt, '2026-09-11T23:59:59Z');
      expect(ProStatus.pilotNotice, 'Cached notice text');
    });

    test('API failure falls back to cached pilot values — never shows paywall', () async {
      SharedPreferences.setMockInitialValues({
        'plan_tier': 'free',
        'pilot_mode': true,
        'pilot_ends_at': '2026-09-11T23:59:59Z',
        'pilot_notice': 'Stale cached notice',
      });
      ProStatus.reset();
      await ProStatus.refresh(_StubApi(null)); // null → throws

      expect(ProStatus.isPilotMode, isTrue,
          reason: 'Must fall back to cached pilot=true on API failure');
      expect(ProStatus.pilotEndsAt, '2026-09-11T23:59:59Z');
      expect(ProStatus.pilotNotice, 'Stale cached notice');
    });

    test('pilot with no end-date: endsAt is null, notice still present', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload(endsAt: null)));
      expect(ProStatus.pilotEndsAt, isNull);
      expect(ProStatus.pilotNotice, isNotNull);
    });
  });

  group('ProStatus — pilot mode inactive', () {
    test('isPilotMode is false when pilot_mode=false', () async {
      await ProStatus.refresh(_StubApi(_nonPilotPayload()));
      expect(ProStatus.isPilotMode, isFalse);
    });

    test('pilotNotice is null when pilot is inactive', () async {
      await ProStatus.refresh(_StubApi(_nonPilotPayload()));
      expect(ProStatus.pilotNotice, isNull);
    });

    test('pilotEndsAt is null when pilot is inactive', () async {
      await ProStatus.refresh(_StubApi(_nonPilotPayload()));
      expect(ProStatus.pilotEndsAt, isNull);
    });

    test('tier and isPro reflect the real free tier', () async {
      await ProStatus.refresh(_StubApi(_nonPilotPayload()));
      expect(ProStatus.tier, 'free');
      expect(ProStatus.isPro, isFalse);
    });

    test('stale pilot prefs are cleared when pilot is deactivated', () async {
      SharedPreferences.setMockInitialValues({
        'pilot_notice': 'old notice',
        'pilot_ends_at': 'old date',
      });
      await ProStatus.refresh(_StubApi(_nonPilotPayload()));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pilot_notice'), isFalse);
      expect(prefs.containsKey('pilot_ends_at'), isFalse);
    });
  });

  group('ProStatus — reset', () {
    test('reset clears all pilot fields', () async {
      await ProStatus.refresh(_StubApi(_pilotPayload()));
      ProStatus.reset();
      expect(ProStatus.isPilotMode, isFalse);
      expect(ProStatus.pilotEndsAt, isNull);
      expect(ProStatus.pilotNotice, isNull);
    });
  });
}
