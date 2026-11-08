import 'dart:async';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import '../test/support/announcement_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'light_contrast_audit_test.dart' as contrast;

void main() {
  group('Contrast', contrast.main);
  for (final brightness in Brightness.values) {
    for (final native in [false, true]) {
      testWidgets('light203 visual ${brightness.name} native=$native', (
        tester,
      ) async {
        IntegrationTestWidgetsFlutterBinding.ensureInitialized();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      if (native) {
                        unawaited(
                          NativePresentation.show(
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
                                      'title': 'Alex Morgan',
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
                                      'id': 'plan',
                                      'title': 'Free pre-launch access',
                                      'subtitle': 'Your plan',
                                      'announcementPlan': true,
                                      'badge': 'Free',
                                    },
                                  ],
                                },
                                {
                                  'title': 'Preferences',
                                  'rows': [
                                    {
                                      'id': 'appearance',
                                      'title': 'Appearance',
                                      'subtitle':
                                          '${brightness.name} · Default text',
                                      'symbol': 'circle.lefthalf.filled',
                                      'disclosure': true,
                                    },
                                    {
                                      'id': 'memory',
                                      'title': 'Personalization and memory',
                                      'symbol': 'brain',
                                      'disclosure': true,
                                    },
                                  ],
                                },
                              ],
                            },
                          ),
                        );
                      } else {
                        unawaited(
                          Navigator.of(context).push(
                            announcementRoute(
                              context,
                              welcomeCampaign,
                              announcementAccess,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(seconds: 1));
          debugPrint(
            'NATIVE_CAPTURE_READY ${native ? 'settings' : 'founders'}-${brightness.name}',
          );
          await Future<void>.delayed(const Duration(seconds: 3));
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
