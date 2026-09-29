import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/scan_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CaptureApi extends ApiClient {
  _CaptureApi() : super(baseUrl: 'https://invalid.test');

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => const [];
}

void main() {
  testWidgets('Capture offers Photo and Scan without See', (tester) async {
    SharedPreferences.setMockInitialValues({'capture_mode': 'see'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ScanPage(api: _CaptureApi(), onSaved: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('See'), findsNothing);
  });
}
