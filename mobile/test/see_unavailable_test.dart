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
  testWidgets('Find can open See before Capture mounts', (tester) async {
    SharedPreferences.setMockInitialValues({'capture_mode': 'photo'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ScanPage(
          api: _CaptureApi(),
          onSaved: () {},
          requestedMode: CaptureMode.see,
          modeRequestSerial: 1,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('See is unavailable'), findsOneWidget);
  });

  testWidgets('unavailable See explains the gate and returns to Photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'capture_mode': 'photo'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ScanPage(api: _CaptureApi(), onSaved: () {}),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('See'));
    await tester.pump();
    expect(find.text('See is unavailable'), findsOneWidget);
    expect(find.text('Nothing is saved here.'), findsOneWidget);
    expect(find.text('Use Photo instead'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('capture_mode'), 'photo');

    await tester.tap(find.text('Use Photo instead'));
    await tester.pump();
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('See is unavailable'), findsNothing);
  });
}
