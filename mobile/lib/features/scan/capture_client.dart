import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

import '../../core/api_client.dart';

abstract interface class CaptureGateway {
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  });

  Future<BarcodeLookupResult> lookupBarcode({
    required String barcode,
    CancelToken? cancelToken,
  });

  Future<BulkCreateResult> saveItems({
    required List<ExtractedInventoryItem> items,
  });
}

class CaptureClient implements CaptureGateway {
  CaptureClient(this._api);

  final ApiClient _api;

  @override
  Future<MultiExtractResult> extractPhoto({
    required List<int> bytes,
    required String filename,
    CancelToken? cancelToken,
  }) {
    final prepared = prepareCaptureImage(bytes, filename);
    return _api.extractInventoryFromImage(
      bytes: prepared.bytes,
      filename: prepared.filename,
      cancelToken: cancelToken,
    );
  }

  @override
  Future<BarcodeLookupResult> lookupBarcode({
    required String barcode,
    CancelToken? cancelToken,
  }) => _api.barcodeLookup(barcode: barcode, cancelToken: cancelToken);

  @override
  Future<BulkCreateResult> saveItems({
    required List<ExtractedInventoryItem> items,
  }) => _api.bulkCreateInventory(items: items);
}

class PreparedCaptureImage {
  const PreparedCaptureImage({required this.bytes, required this.filename});

  final List<int> bytes;
  final String filename;
}

PreparedCaptureImage prepareCaptureImage(List<int> bytes, String filename) {
  try {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) {
      return PreparedCaptureImage(bytes: bytes, filename: filename);
    }
    const maxDimension = 1920;
    var resized = decoded;
    if (decoded.width >= decoded.height && decoded.width > maxDimension) {
      resized = img.copyResize(decoded, width: maxDimension);
    } else if (decoded.height > decoded.width &&
        decoded.height > maxDimension) {
      resized = img.copyResize(decoded, height: maxDimension);
    }
    final stem = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return PreparedCaptureImage(
      bytes: img.encodeJpg(resized, quality: 85),
      filename: '$stem.jpg',
    );
  } catch (_) {
    return PreparedCaptureImage(bytes: bytes, filename: filename);
  }
}
