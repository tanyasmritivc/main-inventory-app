// Synthetic debug harness. Production always targets lib/main.dart.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/background_http.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/scan/capture_progress.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import '../test/support/announcement_fixture.dart';

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
  bool dark = true;
  String status = 'Ready';
  BackgroundHttpClient? client;
  Future<void> start() async {
    client?.close();
    final current = BackgroundHttpClient();
    client = current;
    setState(() => status = 'Starting');
    try {
      final response = await current.send(
        http.Request('POST', Uri.parse('https://localhost:8450/slow'))
          ..headers['Authorization'] = 'Bearer synthetic-fixture'
          ..body = 'synthetic-data',
      );
      if (mounted) setState(() => status = 'Headers received');
      final chunks = <int>[];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
        if (mounted) setState(() => status = String.fromCharCodes(chunks));
      }
      if (mounted) {
        setState(() => status = 'Complete: ${String.fromCharCodes(chunks)}');
      }
    } catch (error) {
      if (mounted) setState(() => status = 'Error: $error');
    } finally {
      current.close();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Mobile 197 audit')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(status),
            TextButton(
              onPressed: start,
              child: const Text('Start background request'),
            ),
            TextButton(
              onPressed: () => client?.close(),
              child: const Text('Stop request'),
            ),
            TextButton(
              onPressed: () => setState(() => dark = !dark),
              child: const Text('Toggle theme'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                announcementRoute(context, welcomeCampaign, announcementAccess),
              ),
              child: const Text('Announcement'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await runWithCaptureProgress(
                    context: context,
                    photo: const AssetImage(
                      'assets/onboarding/sample_workbench.jpg',
                    ),
                    extract: (_) => Completer<void>().future,
                  );
                } on CaptureCancelled {
                  /* Explicit fixture cancellation. */
                }
              },
              child: const Text('Space capture'),
            ),
            TextButton(
              onPressed: () => NativePresentation.show(
                context,
                model: {
                  'title': 'Settings',
                  'large': true,
                  'textSizeFactor': 1.0,
                  'sections': [
                    {
                      'rows': [
                        {
                          'id': 'profile',
                          'title': 'Test Account',
                          'subtitle': 'Edit profile',
                          'symbol': 'person.crop.circle',
                          'disclosure': true,
                        },
                        {
                          'id': 'notifications',
                          'title': 'Notifications',
                          'symbol': 'bell',
                          'disclosure': true,
                        },
                      ],
                    },
                    {
                      'rows': [
                        {
                          'id': 'plans',
                          'title': 'Free pre-launch access',
                          'subtitle': 'Your plan',
                          'announcementPlan': true,
                          'badge': 'Free',
                          'disclosure': true,
                        },
                      ],
                    },
                    {
                      'title': 'Preferences',
                      'rows': [
                        {
                          'id': 'appearance',
                          'title': 'Appearance',
                          'subtitle': 'dark · Default text',
                          'symbol': 'circle.lefthalf.filled',
                          'disclosure': true,
                        },
                      ],
                    },
                  ],
                },
              ),
              child: const Text('Native Settings'),
            ),
          ],
        ),
      ),
    ),
  );
}
