import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import 'capture_client.dart';

enum CaptureStage { preparing, detecting, understanding, saving }

enum CaptureFailureKind { extraction, save, limit }

enum CaptureRunOutcome { completed, cancelled, failed }

class CaptureDraft {
  const CaptureDraft({required this.id, required this.item});

  final String id;
  final ExtractedInventoryItem item;

  CaptureDraft copyWith({ExtractedInventoryItem? item}) =>
      CaptureDraft(id: id, item: item ?? this.item);
}

class CaptureSaveOutcome {
  const CaptureSaveOutcome({
    required this.inserted,
    required this.total,
    required this.failed,
    required this.allSucceeded,
  });

  final List<InventoryItem> inserted;
  final int total;
  final int failed;
  final bool allSucceeded;
}

class CaptureController extends ChangeNotifier {
  CaptureController({required CaptureGateway gateway}) : _gateway = gateway;

  final CaptureGateway _gateway;
  final List<CaptureDraft> _drafts = [];
  final Map<String, String> _saveFailures = {};

  CancelToken? _activeRead;
  Timer? _detectTimer;
  Timer? _understandTimer;
  Timer? _longWaitTimer;
  int _generation = 0;
  int _idCounter = 0;
  List<int>? _retryBytes;
  String? _retryFilename;
  String? _retryBarcode;

  List<CaptureDraft> get drafts => List.unmodifiable(_drafts);
  Map<String, String> get saveFailures => Map.unmodifiable(_saveFailures);
  bool isAnalyzing = false;
  bool isSaving = false;
  bool showLongWaitHint = false;
  CaptureStage? stage;
  CaptureFailureKind? failureKind;
  String? errorMessage;
  MultiExtractSummary? summary;

  bool get canRetryPhoto =>
      !isAnalyzing && _retryBytes != null && _retryFilename != null;

  String _nextId() => '${++_idCounter}';

  Future<CaptureRunOutcome> analyzePhoto({
    required List<int> bytes,
    required String filename,
    String? barcodeToAssociate,
  }) async {
    if (isAnalyzing || isSaving) return CaptureRunOutcome.failed;
    _retryBytes = List<int>.from(bytes);
    _retryFilename = filename;
    _retryBarcode = barcodeToAssociate;
    final generation = ++_generation;
    final token = CancelToken();
    _activeRead = token;
    isAnalyzing = true;
    stage = CaptureStage.preparing;
    showLongWaitHint = false;
    errorMessage = null;
    failureKind = null;
    _saveFailures.clear();
    _scheduleProgress(generation);
    notifyListeners();

    try {
      final result = await _gateway.extractPhoto(
        bytes: bytes,
        filename: filename,
        cancelToken: token,
      );
      if (generation != _generation) return CaptureRunOutcome.cancelled;

      if (barcodeToAssociate != null) {
        final verified = result.items
            .where((item) => item.catalogMatch?.verified == true)
            .toList();
        final candidate = verified.length == 1
            ? verified.single
            : (result.items.length == 1 ? result.items.single : null);
        if (candidate != null) candidate.barcode = barcodeToAssociate;
      }

      if (result.items.isEmpty) {
        failureKind = CaptureFailureKind.extraction;
        errorMessage = 'FindEZ could not identify an item in that photo.';
        return CaptureRunOutcome.failed;
      }

      _drafts
        ..clear()
        ..addAll(
          result.items.map((item) => CaptureDraft(id: _nextId(), item: item)),
        );
      summary = result.summary;
      return CaptureRunOutcome.completed;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || generation != _generation) {
        return CaptureRunOutcome.cancelled;
      }
      failureKind =
          error.response?.statusCode == 429 || error.response?.statusCode == 403
          ? CaptureFailureKind.limit
          : CaptureFailureKind.extraction;
      errorMessage = describeError(error).$1;
      return CaptureRunOutcome.failed;
    } catch (error) {
      if (generation != _generation) return CaptureRunOutcome.cancelled;
      failureKind = CaptureFailureKind.extraction;
      errorMessage = describeError(error).$1;
      return CaptureRunOutcome.failed;
    } finally {
      if (generation == _generation) {
        _cancelTimers();
        _activeRead = null;
        isAnalyzing = false;
        stage = null;
        showLongWaitHint = false;
        notifyListeners();
      }
    }
  }

  Future<CaptureRunOutcome> retryPhoto() {
    final bytes = _retryBytes;
    final filename = _retryFilename;
    if (bytes == null || filename == null) {
      return SynchronousFuture(CaptureRunOutcome.failed);
    }
    return analyzePhoto(
      bytes: bytes,
      filename: filename,
      barcodeToAssociate: _retryBarcode,
    );
  }

  Future<BarcodeLookupResult?> lookupBarcode(String barcode) async {
    if (isAnalyzing || isSaving) return null;
    final generation = ++_generation;
    final token = CancelToken();
    _activeRead = token;
    isAnalyzing = true;
    stage = CaptureStage.understanding;
    errorMessage = null;
    failureKind = null;
    notifyListeners();
    try {
      final result = await _gateway.lookupBarcode(
        barcode: barcode,
        cancelToken: token,
      );
      if (generation != _generation) return null;
      return result;
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error) && generation == _generation) {
        failureKind = CaptureFailureKind.extraction;
        errorMessage = describeError(error).$1;
      }
      return null;
    } catch (error) {
      if (generation == _generation) {
        failureKind = CaptureFailureKind.extraction;
        errorMessage = describeError(error).$1;
      }
      return null;
    } finally {
      if (generation == _generation) {
        _activeRead = null;
        isAnalyzing = false;
        stage = null;
        notifyListeners();
      }
    }
  }

  void useBarcodeResult(BarcodeLookupResult result, String barcode) {
    final name = (result.name ?? '').trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown item') return;
    _drafts
      ..clear()
      ..add(
        CaptureDraft(
          id: _nextId(),
          item: ExtractedInventoryItem(
            name: name,
            category: normalizeCaptureCategory(result.category ?? 'Other'),
            quantity: 1,
            brand: _clean(result.brand),
            partNumber: _clean(result.model),
            barcode: barcode,
          ),
        ),
      );
    summary = null;
    errorMessage = null;
    notifyListeners();
  }

  void replaceDrafts(Iterable<ExtractedInventoryItem> items) {
    _drafts
      ..clear()
      ..addAll(items.map((item) => CaptureDraft(id: _nextId(), item: item)));
    _saveFailures.clear();
    notifyListeners();
  }

  void updateDraft(String id, ExtractedInventoryItem item) {
    final index = _drafts.indexWhere((draft) => draft.id == id);
    if (index < 0) return;
    _drafts[index] = _drafts[index].copyWith(item: item);
    _saveFailures.remove(id);
    notifyListeners();
  }

  void removeDraft(String id) {
    _drafts.removeWhere((draft) => draft.id == id);
    _saveFailures.remove(id);
    notifyListeners();
  }

  Future<CaptureSaveOutcome?> save({required String destination}) async {
    if (isSaving || isAnalyzing || _drafts.isEmpty) return null;
    final target = destination.trim();
    if (target.isEmpty) {
      failureKind = CaptureFailureKind.save;
      errorMessage = 'Choose a Space before saving.';
      notifyListeners();
      return null;
    }

    final prepared = _prepareForSave(target);
    _saveFailures
      ..clear()
      ..addAll(prepared.validationFailures);
    if (prepared.items.isEmpty) {
      failureKind = CaptureFailureKind.save;
      errorMessage = 'Fix the highlighted results before saving.';
      notifyListeners();
      return null;
    }

    isSaving = true;
    stage = CaptureStage.saving;
    failureKind = null;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _gateway.saveItems(items: prepared.items);
      final failedPrepared = <int>{};
      for (final failure in response.failures) {
        final index = failure['index'] is num
            ? (failure['index'] as num).toInt()
            : int.tryParse('${failure['index']}');
        if (index == null || index < 0 || index >= prepared.draftIds.length) {
          continue;
        }
        failedPrepared.add(index);
        final reason = (failure['reason'] ?? 'Could not save this result.')
            .toString();
        for (final id in prepared.draftIds[index]) {
          _saveFailures[id] = reason;
        }
      }

      final expectedSuccess = prepared.items.length - failedPrepared.length;
      final responseIsCertain = response.inserted.length == expectedSuccess;
      if (!responseIsCertain) {
        failureKind = CaptureFailureKind.save;
        errorMessage =
            'The save result was unclear. Check Memory before trying again.';
        return CaptureSaveOutcome(
          inserted: response.inserted,
          total: _drafts.length,
          failed: _drafts.length,
          allSucceeded: false,
        );
      }

      final failedIds = <String>{
        ...prepared.validationFailures.keys,
        for (final index in failedPrepared) ...prepared.draftIds[index],
      };
      final total = _drafts.length;
      _drafts.removeWhere((draft) => !failedIds.contains(draft.id));
      final failed = _drafts.length;
      if (failed > 0) {
        failureKind = CaptureFailureKind.save;
        errorMessage =
            'Some results were saved. Fix the remaining results and try again.';
      } else {
        summary = null;
        _retryBytes = null;
        _retryFilename = null;
        _retryBarcode = null;
      }
      return CaptureSaveOutcome(
        inserted: response.inserted,
        total: total,
        failed: failed,
        allSucceeded: failed == 0,
      );
    } catch (error) {
      failureKind = CaptureFailureKind.save;
      errorMessage = describeError(error).$1;
      return null;
    } finally {
      isSaving = false;
      stage = null;
      notifyListeners();
    }
  }

  Future<void> cancelActive() async {
    if (!isAnalyzing) return;
    _generation += 1;
    _activeRead?.cancel('Cancelled by user');
    _activeRead = null;
    _cancelTimers();
    isAnalyzing = false;
    stage = null;
    showLongWaitHint = false;
    errorMessage = null;
    notifyListeners();
  }

  void clear() {
    unawaited(cancelActive());
    _drafts.clear();
    _saveFailures.clear();
    summary = null;
    failureKind = null;
    errorMessage = null;
    _retryBytes = null;
    _retryFilename = null;
    _retryBarcode = null;
    notifyListeners();
  }

  void _scheduleProgress(int generation) {
    _detectTimer = Timer(const Duration(milliseconds: 600), () {
      if (generation != _generation || !isAnalyzing) return;
      stage = CaptureStage.detecting;
      notifyListeners();
    });
    _understandTimer = Timer(const Duration(seconds: 2), () {
      if (generation != _generation || !isAnalyzing) return;
      stage = CaptureStage.understanding;
      notifyListeners();
    });
    _longWaitTimer = Timer(const Duration(seconds: 8), () {
      if (generation != _generation || !isAnalyzing) return;
      showLongWaitHint = true;
      notifyListeners();
    });
  }

  void _cancelTimers() {
    _detectTimer?.cancel();
    _understandTimer?.cancel();
    _longWaitTimer?.cancel();
  }

  _PreparedSave _prepareForSave(String destination) {
    final validationFailures = <String, String>{};
    final groups = <String, List<CaptureDraft>>{};
    for (final draft in _drafts) {
      final name = draft.item.name.trim();
      if (name.isEmpty || draft.item.quantity < 1) {
        validationFailures[draft.id] =
            'A name and quantity of at least 1 are required.';
        continue;
      }
      final rawLocation = (draft.item.location ?? '').trim();
      final location =
          rawLocation.isEmpty || rawLocation.toLowerCase() == 'unsorted'
          ? destination
          : rawLocation;
      final key = '${name.toLowerCase()}::${location.toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(draft);
    }

    final items = <ExtractedInventoryItem>[];
    final draftIds = <List<String>>[];
    for (final group in groups.values) {
      final first = group.first.item;
      final rawLocation = (first.location ?? '').trim();
      final location =
          rawLocation.isEmpty || rawLocation.toLowerCase() == 'unsorted'
          ? destination
          : rawLocation;
      items.add(
        copyExtractedItem(
          first,
          category: normalizeCaptureCategory(first.category),
          quantity: group.fold<int>(
            0,
            (sum, draft) => sum + draft.item.quantity,
          ),
          location: location,
        ),
      );
      draftIds.add(group.map((draft) => draft.id).toList());
    }
    return _PreparedSave(
      items: items,
      draftIds: draftIds,
      validationFailures: validationFailures,
    );
  }

  @override
  void dispose() {
    _activeRead?.cancel('Capture controller disposed');
    _cancelTimers();
    super.dispose();
  }
}

class _PreparedSave {
  const _PreparedSave({
    required this.items,
    required this.draftIds,
    required this.validationFailures,
  });

  final List<ExtractedInventoryItem> items;
  final List<List<String>> draftIds;
  final Map<String, String> validationFailures;
}

String? _clean(String? value) {
  final cleaned = (value ?? '').trim();
  return cleaned.isEmpty ? null : cleaned;
}

String normalizeCaptureCategory(String rawCategory) {
  final value = rawCategory.trim();
  if (value.isEmpty || value.toLowerCase() == 'unsorted') return 'Other';
  return value;
}

ExtractedInventoryItem copyExtractedItem(
  ExtractedInventoryItem item, {
  String? name,
  String? category,
  int? quantity,
  String? location,
}) {
  return ExtractedInventoryItem(
    name: name ?? item.name,
    category: category ?? item.category,
    quantity: quantity ?? item.quantity,
    subcategory: item.subcategory,
    brand: item.brand,
    partNumber: item.partNumber,
    barcode: item.barcode,
    tags: item.tags,
    confidence: item.confidence,
    notes: item.notes,
    location: location ?? item.location,
    catalogMatch: item.catalogMatch,
    scanEvidence: item.scanEvidence,
  );
}
