import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/pro_status.dart';
import 'package:mobile/core/upgrade_sheet.dart';

class _AccessApi extends ApiClient {
  _AccessApi(this.response) : super(baseUrl: 'http://localhost');
  final Map<String, dynamic>? response;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> getMyLimits() async {
    reads++;
    if (response == null) throw Exception('Offline');
    return response!;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProStatus.reset();
  });

  for (final response in <Map<String, dynamic>?>[
    {'pilot_mode': true, 'limits_enabled': false},
    {'pilot_mode': true, 'limits_enabled': true},
    {'pilot_mode': false},
    null,
  ]) {
    testWidgets('stale quota error does not interrupt access: $response', (
      tester,
    ) async {
      // An earlier verified quota must not authorize a new prompt while offline.
      await ProStatus.refresh(
        _AccessApi({'pilot_mode': false, 'limits_enabled': true}),
      );
      final api = _AccessApi(response);
      bool returned = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showUpgradeSheet(
                    context,
                    api,
                    reason: 'Old quota error',
                  );
                  returned = true;
                },
                child: const Text('Add items'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add items'));
      await tester.pumpAndSettle();
      expect(api.reads, 1);
      expect(returned, isTrue);
      expect(find.text('Usage limit reached'), findsNothing);
      expect(find.text('Add items'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  }
}
