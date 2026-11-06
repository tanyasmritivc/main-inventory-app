// Synthetic native UI audit only. Production targets lib/main.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/notifications/notifications_page.dart';
import 'package:mobile/features/scan/native_scan_camera.dart';
import 'package:mobile/features/world/world_composer.dart';

class InboxFixture extends ApiClient {
  InboxFixture() : super(baseUrl: 'https://example.invalid');
  bool read = false;
  @override
  String get accountId => 'synthetic-actor';
  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'unread_count': read ? 0 : 2,
    'notifications': [
      for (var i = 0; i < 7; i++)
        {
          'id': 'notice-$i',
          'display_text': i.isEven
              ? 'You created the task: Check the robotics parts before practice'
              : 'Alex updated the workshop inventory.',
          'team_name': 'Robotics Workshop',
          'created_at': '2026-11-05T20:00:00Z',
          'action': i.isEven ? 'task_created' : 'item_updated',
          'is_read': read || i > 1,
        },
    ],
  };
  @override
  Future<void> markNotificationsRead() async {
    read = true;
  }
}

void main() {
  if (kReleaseMode) {
    throw UnsupportedError('Debug only');
  }
  runApp(const Audit());
}

class Audit extends StatefulWidget {
  const Audit({super.key});
  @override
  State<Audit> createState() => AuditState();
}

class AuditState extends State<Audit> {
  final api = InboxFixture();
  final camera = NativeScanCamera();
  final text = TextEditingController();
  final focus = FocusNode();
  bool dark = true;
  String status = 'Ready';
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Native inbox and camera audit')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(status),
              TextButton(
                onPressed: () => NotificationsPage.open(context, api: api),
                child: const Text('Notifications'),
              ),
              TextButton(
                onPressed: () => setState(() => dark = !dark),
                child: const Text('Toggle appearance'),
              ),
              TextButton(
                onPressed: () async {
                  final photo = await camera.pick(dark: dark);
                  if (mounted) {
                    setState(
                      () => status = photo == null
                          ? 'Camera cancelled'
                          : 'Selected photo: ${photo.length} bytes',
                    );
                  }
                },
                child: const Text('Open camera'),
              ),
              WorldComposer(
                controller: text,
                focusNode: focus,
                onChanged: (_) {},
                onAttach: () {},
                onVoice: () {},
                onSend: null,
                busy: false,
                listening: false,
                compact: false,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    camera.cancel();
    text.dispose();
    focus.dispose();
    super.dispose();
  }
}
