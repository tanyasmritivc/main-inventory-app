import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/capture_client.dart';
import 'package:mobile/features/scan/capture_controller.dart';
import 'package:mobile/features/scan/scan_page.dart';

void main() {
  testWidgets('Capture is photo-first and keeps secondary entry points', (
    tester,
  ) async {
    final controller = CaptureController(gateway: _PageGateway());
    await tester.pumpWidget(_app(controller));
    await tester.pump();

    expect(find.text('Remember this.'), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-take-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-choose-photo')), findsOneWidget);
    expect(find.text('Barcode or QR'), findsOneWidget);
    expect(find.text('Spreadsheet'), findsOneWidget);
    expect(find.text('Check a BOM'), findsOneWidget);
    expect(find.text('Project Kits'), findsOneWidget);
    controller.dispose();
  });

  testWidgets(
    'renders multiple real results and review signals at text scale',
    (tester) async {
      final controller = CaptureController(gateway: _PageGateway());
      controller.replaceDrafts([
        ExtractedInventoryItem(
          name: 'Unidentified bracket',
          category: 'Hardware',
          quantity: 2,
          confidence: 0.4,
          scanEvidence: const ScanEvidence(
            ocrText: 'A-123',
            detectionConfidence: 0.8,
            needsReview: true,
          ),
        ),
        ExtractedInventoryItem(
          name: 'Servo',
          category: 'Robot Parts',
          quantity: 1,
        ),
      ]);
      await tester.pumpWidget(_app(controller, textScale: 1.8));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Check this result before saving'),
        300,
      );

      expect(find.text('2 results found'), findsOneWidget);
      expect(find.text('Check this result before saving'), findsOneWidget);
      expect(find.textContaining('Text: A-123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );

  testWidgets('reduced motion omits the indeterminate linear animation', (
    tester,
  ) async {
    final gateway = _PendingPageGateway();
    final controller = CaptureController(gateway: gateway);
    final run = controller.analyzePhoto(bytes: [1], filename: 'slow.jpg');
    await tester.pumpWidget(_app(controller, disableAnimations: true));
    await tester.pump();

    expect(find.text('Preparing your photo'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Stop'), findsNWidgets(2));

    await controller.cancelActive();
    await run;
    controller.dispose();
  });
}

Widget _app(
  CaptureController controller, {
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: ThemeData.dark(),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ScanPage(
      api: ApiClient(baseUrl: 'https://api.findez.test'),
      controller: controller,
      spacesLoader: () async => [
        {'name': 'Robot Room'},
      ],
      onSaved: () {},
    ),
  ),
);

class _PageGateway implements CaptureGateway {
  @override
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<BarcodeLookupResult> lookupBarcode({
    required String barcode,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<BulkCreateResult> saveItems({
    required List<ExtractedInventoryItem> items,
  }) => throw UnimplementedError();
}

class _PendingPageGateway extends _PageGateway {
  @override
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  }) async {
    await cancelToken!.whenCancel;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: '/capture'),
      reason: 'cancelled',
    );
  }
}
