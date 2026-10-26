import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/checkout/checkout_page.dart';

class CheckoutApi extends ApiClient {
  CheckoutApi() : super(baseUrl: 'https://api.test');
  bool fail = true;
  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async {
    if (fail) throw StateError('private database response');
    return [
      {
        'checkout_id': 'qa-checkout',
        'items': {
          'name': 'Rechargeable laboratory multimeter',
          'location': 'Equipment cabinet',
        },
        'checked_out_by': 'Alex Example',
      },
    ];
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} failed checkout load is recoverable at large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = CheckoutApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2.6)),
              child: child!,
            ),
            home: CheckoutPage(api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Nothing checked out'), findsNothing);
        expect(find.textContaining('private database'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        expect(tester.takeException(), isNull);
        api.fail = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Rechargeable laboratory multimeter'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
