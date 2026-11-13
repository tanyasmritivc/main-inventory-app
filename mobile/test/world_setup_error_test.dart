import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/onboarding/world_setup_gate.dart';

class _SignedOutApi extends ApiClient {
  _SignedOutApi() : super(baseUrl: 'https://api.test');

  @override
  String? get accountId => null;
}

void main() {
  testWidgets(
    'setup error keeps Retry reachable on a small screen at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(3.2)),
            child: child!,
          ),
          home: WorldSetupGate(api: _SignedOutApi()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text("We couldn't finish setting up. Try again."),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
