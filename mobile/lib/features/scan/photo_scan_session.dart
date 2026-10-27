import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

String scanIdentity(ExtractedInventoryItem item) {
  String clean(String? value) =>
      (value ?? '').toLowerCase().replaceAll(RegExp(r'[\s\-_.(),/]+'), '');
  if (clean(item.barcode).isNotEmpty) return 'barcode:${clean(item.barcode)}';
  if (clean(item.brand).isNotEmpty && clean(item.partNumber).isNotEmpty) {
    return 'model:${clean(item.brand)}:${clean(item.partNumber)}';
  }
  return 'name:${clean(item.name)}';
}

class PhotoDetection {
  PhotoDetection(this.item, {String? requestId})
    : requestId =
          requestId ??
          base64Url.encode(
            List.generate(24, (_) => Random.secure().nextInt(256)),
          );
  ExtractedInventoryItem item;
  final String requestId;
  String? savedId, issue;
  bool attempted = false, ignored = false;
  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'request': requestId,
    'saved': savedId,
    'attempted': attempted,
    'ignored': ignored,
    'issue': issue,
  };
  factory PhotoDetection.fromJson(Map<String, dynamic> data) =>
      PhotoDetection(
          ExtractedInventoryItem.fromJson(
            Map<String, dynamic>.from(data['item']),
          ),
          requestId: data['request'],
        )
        ..savedId = data['saved']
        ..attempted = data['attempted'] == true
        ..ignored = data['ignored'] == true
        ..issue = data['issue'];
}

/// Durable per-account/inventory/Space receipts keep retries idempotent. A scan
/// never increments a previous item's count, including when a photo is repeated.
class PhotoScanSession {
  PhotoScanSession(this.api, this.spaceId, this.location);
  final ApiClient api;
  final String spaceId, location;
  final List<PhotoDetection> rows = [];
  bool _writing = false;
  String get key =>
      'findez.photo-scan.v1.${api.accountId}.${api.inventoryContext?.inventoryId}.$spaceId';
  Future<void> restore() async {
    api.assertCurrentContext();
    final raw = (await SharedPreferences.getInstance()).getString(key);
    api.assertCurrentContext();
    if (raw != null) {
      rows.addAll(
        (jsonDecode(raw) as List).map(
          (value) => PhotoDetection.fromJson(Map<String, dynamic>.from(value)),
        ),
      );
    }
  }

  Future<void> persist() async {
    api.assertCurrentContext();
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(rows.map((row) => row.toJson()).toList()),
    )) {
      throw StateError('Scan could not be kept on this device');
    }
    api.assertCurrentContext();
  }

  Future<List<PhotoDetection>> accept(
    List<ExtractedInventoryItem> items,
  ) async {
    final added = <PhotoDetection>[];
    for (final item in items) {
      final identity = scanIdentity(item);
      // A repeated photo can supply a model after an earlier name-only result.
      final name = item.name.toLowerCase().replaceAll(
        RegExp(r'[\s\-_.(),/]+'),
        '',
      );
      final old = rows.where(
        (row) =>
            scanIdentity(row.item) == identity ||
            row.item.name.toLowerCase().replaceAll(
                  RegExp(r'[\s\-_.(),/]+'),
                  '',
                ) ==
                name,
      );
      final unknown =
          name.isEmpty ||
          RegExp(
            r'^(unknown|unidentified|unrecognized)(item|object)?$',
          ).hasMatch(name);
      if (!unknown && old.isNotEmpty) continue;
      item.location = location;
      if (item.category.trim().isEmpty) item.category = 'Other';
      final row = PhotoDetection(item);
      rows.add(row);
      added.add(row);
    }
    await persist();
    return added;
  }

  Future<bool> save(PhotoDetection row, {bool allowExisting = false}) async {
    if (_writing || row.savedId != null || row.ignored) return false;
    if (row.item.needsReview ||
        row.item.scanEvidence?.quantityMissing == true) {
      row.issue = 'Confirm the identity and count before saving.';
      await persist();
      return false;
    }
    _writing = true;
    try {
      api.assertCurrentContext();
      if (!row.attempted) {
        final spaces = await api.listSpaces();
        api.assertCurrentContext();
        if (!spaces.any(
          (space) =>
              (space['space_id'] ?? space['id']) == spaceId &&
              space['name'] == location,
        )) {
          row.issue = 'This Space changed. Close the scan and choose it again.';
          await persist();
          return false;
        }
        // Any plausible existing match requires deliberate review. A search
        // failure must block saving, never be interpreted as an empty inventory.
        final existing = await api.searchItems(query: row.item.name);
        api.assertCurrentContext();
        if (existing.items.isNotEmpty) {
          row.issue =
              'Possible existing item. Review before saving separately.';
          if (!allowExisting) {
            await persist();
            return false;
          }
        }
      }
      row.attempted = true;
      await persist(); // Receipt identity reaches disk BEFORE the server write.
      final result = await api.bulkCreateInventory(
        items: [row.item],
        requestIds: [row.requestId],
      );
      api.assertCurrentContext();
      if (!result.confirmedIndices(1).contains(0) ||
          result.inserted.length != 1) {
        throw StateError('Save not confirmed');
      }
      row.savedId = result.inserted.single.itemId;
      row.issue = null;
      await persist();
      return true;
    } catch (_) {
      row.issue = 'Save not confirmed. Retry checks the same item.';
      await persist();
      return false;
    } finally {
      _writing = false;
    }
  }

  /// End this visit while preserving unconfirmed writes for safe retry.
  Future<void> finish() async {
    if (_writing) return;
    rows.removeWhere((row) => row.savedId != null || row.ignored);
    await persist();
  }

  Future<bool> undo(PhotoDetection row) async {
    if (_writing || row.savedId == null) return false;
    _writing = true;
    try {
      api.assertCurrentContext();
      if (!await api.deleteItem(itemId: row.savedId!)) return false;
      row.savedId = null;
      row.ignored =
          true; // A repeated photo must not silently add an undone item.
      await persist();
      return true;
    } finally {
      _writing = false;
    }
  }
}
