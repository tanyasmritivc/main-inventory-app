// Synthetic UIKit audit only; production always targets lib/main.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/notifications/notification_preferences.dart';
import 'package:mobile/features/notifications/notifications_page.dart';

class PolicyFixture extends ApiClient {
  PolicyFixture() : super(baseUrl: 'https://example.invalid');
  @override
  String get accountId => 'synthetic-notifications';
  var preferences = <String, dynamic>{
    'revision': 0,
    'push_enabled': false,
    'in_app_enabled': true,
    'quiet_enabled': true,
    'quiet_start': 1260,
    'quiet_end': 480,
    'timezone': 'America/Los_Angeles',
    'inventory_alerts': true,
    'capture_reminders': true,
    'show_details': false,
    'paused_until': null,
  };
  var rows = <Map<String, dynamic>>[
    {
      'id': '10000000-0000-0000-0000-000000000001',
      'action': 'personalization',
      'display_text': 'An inventory item needs your attention.',
      'created_at': '2026-11-06T09:00:00Z',
      'is_read': false,
    },
    {
      'id': '10000000-0000-0000-0000-000000000002',
      'action': 'personalization',
      'display_text': 'A photo review is waiting for you.',
      'created_at': '2026-11-06T08:00:00Z',
      'is_read': true,
    },
  ];
  @override
  Future<Map<String, dynamic>> getNotificationPreferences() async => {
    'preferences': preferences,
    'timezones': [
      'America/Los_Angeles',
      'America/New_York',
      'Asia/Kolkata',
      'Europe/London',
      'UTC',
    ],
  };
  @override
  Future<Map<String, dynamic>> updateNotificationPreferences(
    int revision,
    Map<String, dynamic> changes,
  ) async {
    preferences = {...preferences, ...changes, 'revision': revision + 1};
    return {'preferences': preferences};
  }

  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'notifications': rows,
    'unread_count': rows.where((r) => r['is_read'] != true).length,
    'policy_version': 1,
  };
  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {}
  @override
  Future<void> dismissNotification(String id) async {
    rows = rows.where((r) => r['id'] != id).toList();
  }

  @override
  Future<void> clearNotifications() async {
    rows = [];
  }

  @override
  Future<void> markNotificationsRead() async {
    rows = [
      for (final r in rows) {...r, 'is_read': true},
    ];
  }
}

void main() {
  if (kReleaseMode) throw UnsupportedError('Debug only');
  runApp(const Audit());
}

class Audit extends StatefulWidget {
  const Audit({super.key});
  @override
  State<Audit> createState() => _AuditState();
}

class _AuditState extends State<Audit> {
  final api = PolicyFixture();
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Notification policy audit')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => NotificationsPage.open(context, api: api),
                child: const Text('Notifications'),
              ),
              TextButton(
                onPressed: () => showNotificationPreferences(context, api),
                child: const Text('Preferences'),
              ),
              TextButton(
                onPressed: () => setState(() => dark = !dark),
                child: const Text('Switch appearance'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
