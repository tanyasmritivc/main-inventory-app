import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/launch_notification_permission.dart';
import 'package:mobile/core/push_notifications.dart';

/// Interactive native check on a disposable installation only. No API calls.
/// Run with FINDEZ_NOTIFICATION_PERMISSION_QA=true and answer Apple's alert.
class _SignedOutApi extends ApiClient {
  _SignedOutApi() : super(baseUrl: 'https://api.invalid');
  @override
  String? get accountId => null;
  @override
  Future<void> registerPushDevice({
    required String token,
    required String environment,
  }) async {
    fail('A signed-out installation must not register a server token');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'first active frame requests native permission and retains the choice',
    (tester) async {
      final initial = await PushNotifications.authorizationStatus();
      debugPrint('NOTIFICATION_QA initial=$initial');
      expect(
        initial,
        'notDetermined',
        reason: 'Use a fresh disposable installation',
      );
      Widget app() => MaterialApp(
        home: LaunchNotificationPermission(
          api: _SignedOutApi(),
          child: const Scaffold(body: Center(child: Text('Welcome to FindEZ'))),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Welcome to FindEZ'), findsOneWidget);
      String status = initial;
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (status == 'notDetermined' && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
        status = await PushNotifications.authorizationStatus();
      }
      expect(['authorized', 'denied'], contains(status));
      debugPrint('NOTIFICATION_QA decision=$status');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 2));
      expect(await PushNotifications.authorizationStatus(), status);
      // The native method itself also respects a durable existing decision.
      expect(
        await const MethodChannel(
          'com.findez.app/push',
        ).invokeMethod<bool>('requestPermission'),
        status == 'authorized',
      );
      expect(find.text('Welcome to FindEZ'), findsOneWidget);
      debugPrint('NOTIFICATION_QA retained_without_second_prompt=true');
    },
    timeout: const Timeout(Duration(minutes: 4)),
    skip: !const bool.fromEnvironment('FINDEZ_NOTIFICATION_PERMISSION_QA'),
  );
}
