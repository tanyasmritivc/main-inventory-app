import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/capture_client.dart';
import 'package:mobile/features/scan/capture_controller.dart';

void main() {
  group('CaptureController', () {
    test(
      'owns FIND lifecycle and preserves actual extraction metadata',
      () async {
        final gateway = _FakeGateway(
          extractResult: _result([
            _item('Servo', confidence: 0.92),
            _item('Bracket', quantity: 2),
          ], partial: true),
        );
        final controller = CaptureController(gateway: gateway);

        final outcome = await controller.analyzePhoto(
          bytes: [1, 2, 3],
          filename: 'parts.png',
        );

        expect(outcome, CaptureRunOutcome.completed);
        expect(controller.drafts.map((draft) => draft.item.name), [
          'Servo',
          'Bracket',
        ]);
        expect(controller.summary?.partial, isTrue);
        expect(controller.isAnalyzing, isFalse);
        expect(gateway.extractCalls, 1);
        controller.dispose();
      },
    );

    test(
      'explicit retry repeats a read-only extraction only on request',
      () async {
        final gateway = _FakeGateway(
          extractError: DioException(
            requestOptions: RequestOptions(path: '/capture'),
            type: DioExceptionType.connectionError,
          ),
        );
        final controller = CaptureController(gateway: gateway);

        expect(
          await controller.analyzePhoto(bytes: [1], filename: 'one.jpg'),
          CaptureRunOutcome.failed,
        );
        expect(gateway.extractCalls, 1);
        expect(controller.canRetryPhoto, isTrue);

        await controller.retryPhoto();
        expect(gateway.extractCalls, 2);
        controller.dispose();
      },
    );

    test(
      'cancellation aborts the active FIND request and keeps prior results',
      () async {
        final gateway = _PendingGateway();
        final controller = CaptureController(gateway: gateway);
        controller.replaceDrafts([_item('Existing result')]);
        final future = controller.analyzePhoto(
          bytes: [1],
          filename: 'slow.jpg',
        );
        await Future<void>.delayed(Duration.zero);

        await controller.cancelActive();
        final outcome = await future;

        expect(outcome, CaptureRunOutcome.cancelled);
        expect(gateway.wasCancelled, isTrue);
        expect(controller.drafts.single.item.name, 'Existing result');
        expect(controller.isAnalyzing, isFalse);
        controller.dispose();
      },
    );

    test(
      'aggregates duplicate results before the inventory mutation',
      () async {
        final gateway = _FakeGateway(
          saveResult: BulkCreateResult(
            inserted: [_savedItem('Bolt', quantity: 5)],
            failures: const [],
          ),
        );
        final controller = CaptureController(gateway: gateway);
        controller.replaceDrafts([
          _item('Bolt', quantity: 2),
          _item('bolt', quantity: 3),
        ]);

        final outcome = await controller.save(destination: 'Hardware');

        expect(gateway.savedItems, hasLength(1));
        expect(gateway.savedItems.single.quantity, 5);
        expect(outcome?.allSucceeded, isTrue);
        expect(controller.drafts, isEmpty);
        controller.dispose();
      },
    );

    test(
      'partial save removes successes so retry cannot duplicate them',
      () async {
        final gateway = _FakeGateway(
          saveResult: BulkCreateResult(
            inserted: [_savedItem('Servo')],
            failures: const [
              {'index': 1, 'reason': 'Space is unavailable.'},
            ],
          ),
        );
        final controller = CaptureController(gateway: gateway);
        controller.replaceDrafts([_item('Servo'), _item('Motor')]);

        final outcome = await controller.save(destination: 'Robot Room');

        expect(outcome?.allSucceeded, isFalse);
        expect(outcome?.failed, 1);
        expect(controller.drafts.single.item.name, 'Motor');
        expect(controller.saveFailures.values.single, 'Space is unavailable.');
        controller.dispose();
      },
    );

    test('does not automatically retry a failed inventory mutation', () async {
      final gateway = _FakeGateway(saveError: StateError('offline'));
      final controller = CaptureController(gateway: gateway);
      controller.replaceDrafts([_item('Servo')]);

      final outcome = await controller.save(destination: 'Robot Room');

      expect(outcome, isNull);
      expect(gateway.saveCalls, 1);
      expect(controller.drafts.single.item.name, 'Servo');
      expect(controller.failureKind, CaptureFailureKind.save);
      controller.dispose();
    });

    test(
      'unexpected empty FIND response becomes a visible recoverable error',
      () async {
        final controller = CaptureController(
          gateway: _FakeGateway(extractResult: _result(const [])),
        );

        final outcome = await controller.analyzePhoto(
          bytes: [1],
          filename: 'empty.jpg',
        );

        expect(outcome, CaptureRunOutcome.failed);
        expect(controller.errorMessage, contains('could not identify'));
        expect(controller.canRetryPhoto, isTrue);
        controller.dispose();
      },
    );
  });

  test('invalid image data is passed through without inventing a format', () {
    final prepared = prepareCaptureImage([1, 2, 3], 'capture.heic');
    expect(prepared.bytes, [1, 2, 3]);
    expect(prepared.filename, 'capture.heic');
  });
}

ExtractedInventoryItem _item(
  String name, {
  int quantity = 1,
  double? confidence,
}) => ExtractedInventoryItem(
  name: name,
  category: 'Robot Parts',
  quantity: quantity,
  confidence: confidence,
);

MultiExtractResult _result(
  List<ExtractedInventoryItem> items, {
  bool partial = false,
}) => MultiExtractResult(
  items: items,
  summary: MultiExtractSummary(
    totalDetected: items.length,
    categories: {'Robot Parts': items.length},
    partial: partial,
  ),
);

InventoryItem _savedItem(String name, {int quantity = 1}) =>
    InventoryItem.fromJson({
      'item_id': 'saved-$name',
      'name': name,
      'category': 'Robot Parts',
      'quantity': quantity,
      'location': 'Robot Room',
      'created_at': '2026-09-25T00:00:00Z',
    });

class _FakeGateway implements CaptureGateway {
  _FakeGateway({
    this.extractResult,
    this.extractError,
    this.saveResult,
    this.saveError,
  });

  final MultiExtractResult? extractResult;
  final Object? extractError;
  final BulkCreateResult? saveResult;
  final Object? saveError;
  int extractCalls = 0;
  int saveCalls = 0;
  List<ExtractedInventoryItem> savedItems = const [];

  @override
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  }) async {
    extractCalls += 1;
    if (extractError case final error?) throw error;
    return extractResult ?? _result([_item('Default')]);
  }

  @override
  Future<BarcodeLookupResult> lookupBarcode({
    required String barcode,
    CancelToken? cancelToken,
  }) async => BarcodeLookupResult(name: 'Servo');

  @override
  Future<BulkCreateResult> saveItems({
    required List<ExtractedInventoryItem> items,
  }) async {
    saveCalls += 1;
    savedItems = items;
    if (saveError case final error?) throw error;
    return saveResult ??
        BulkCreateResult(inserted: const [], failures: const []);
  }
}

class _PendingGateway implements CaptureGateway {
  bool wasCancelled = false;

  @override
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<MultiExtractResult>();
    cancelToken?.whenCancel.then((_) {
      wasCancelled = true;
      completer.completeError(
        DioException.requestCancelled(
          requestOptions: RequestOptions(path: '/capture'),
          reason: 'cancelled',
        ),
      );
    });
    return completer.future;
  }

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
