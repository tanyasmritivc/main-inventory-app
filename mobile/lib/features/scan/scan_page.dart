import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/pro_status.dart';
import '../../core/upgrade_sheet.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
import 'confirm_scan_sheet.dart';
import 'qr_sheet.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.api, required this.onSaved, this.isActive = false, this.onSpaceScanned});

  final ApiClient api;
  final VoidCallback onSaved;
  final bool isActive;
  final void Function(String spaceName)? onSpaceScanned;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScannedItem {
  const _ScannedItem({required this.id, required this.item});

  final String id;
  final ExtractedInventoryItem item;

  _ScannedItem copyWith({ExtractedInventoryItem? item}) {
    return _ScannedItem(id: id, item: item ?? this.item);
  }
}

enum _ScanStage { uploading, analyzing, extracting }

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  MobileScannerController? _controller;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const <BarcodeFormat>[
        BarcodeFormat.all,
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: controller == null
          ? const SizedBox.shrink()
          : MobileScanner(
              controller: controller,
              onDetect: (capture) {
                if (_returned) return;
                final codes = capture.barcodes;
                if (codes.isEmpty) return;
                final raw = codes.first.rawValue;
                if (raw == null || raw.trim().isEmpty) return;
                _returned = true;
                Navigator.of(context).pop(raw.trim());
              },
            ),
    );
  }
}

class _ScanPageState extends State<ScanPage> {
  late final ApiClient _api;
  late final TextEditingController _defaultLocation;
  List<String> _availableSpaces = [];
  final ImagePicker _picker = ImagePicker();

  /// Normalizes taxonomy/category strings to simple top-level categories.
  String _normalizeCategory(String rawCategory) {
    final c = rawCategory.trim().toLowerCase();
    if (c.isEmpty || c == 'unsorted') return 'Other';
    
    // Food
    if (c.contains('food') || c.contains('grocery') || c.contains('beverage') ||
        c.contains('snack') || c.contains('nut') || c.contains('nuts') ||
        c.contains('bar') || c.contains('kirkland') || c.contains('cashew') ||
        c.contains('almond') || c.contains('pecan')) return 'Food';
    
    // Cosmetics
    if (c.contains('cosmetic') || c.contains('beauty') || c.contains('makeup') || 
        c.contains('skincare')) return 'Cosmetics';
    
    // Electronics
    if (c.contains('electronic') || c.contains('tech') || c.contains('gadget') || 
        c.contains('computer') || c.contains('phone') || c.contains('appliance')) return 'Electronics';
    
    // Clothing
    if (c.contains('clothing') || c.contains('apparel') || c.contains('fashion') || 
        c.contains('shoe')) return 'Clothing';
    
    // Health
    if (c.contains('health') || c.contains('medicine') || c.contains('pharma') || 
        c.contains('supplement') || c.contains('medication')) return 'Health';
    
    // Home
    if (c.contains('home') || c.contains('kitchen') || c.contains('furniture') || 
        c.contains('decor') || c.contains('appliance')) return 'Home';
    
    // Office
    if (c.contains('book') || c.contains('media') || c.contains('office') || 
        c.contains('stationery')) return 'Office';
    
    // Supplies
    if (c.contains('cleaning') || c.contains('household') || c.contains('supply') || 
        c.contains('adhesive') || c.contains('tool')) return 'Supplies';
    
    // Toys
    if (c.contains('toy') || c.contains('game') || c.contains('hobby')) return 'Toys';
    
    // Accessories -> Other
    if (c.contains('accessories') || c.contains('accessory')) return 'Other';
    
    return 'Other';
  }

  bool _loading = false;
  bool _saving = false;
  bool _cameraMode = false;
  String? _error;
  String? _scanStatus;

  Timer? _rotateStatusT;
  Timer? _fakeProgressT;
  double _fakeProgress = 0.0;
  int _rotateStatusIndex = 0;

  static const _instantScanStatuses = <String>[
    'Scanning…',
    'Analyzing your photo…',
    'Detecting items…',
    'Almost there…',
  ];

  _ScanStage? _scanStage;
  bool _showLongWaitHint = false;
  bool _lastErrorWasExtraction = false;

  Timer? _statusT1;
  Timer? _statusT2;
  Timer? _statusT3;
  Timer? _longWaitT;

  Map<String, String> _saveFailures = const {};

  bool _showTrackCategoryPrompt = false;
  String? _lastSavedCategory;
  String? _lastSavedLocation;

  List<_ScannedItem> _scannedItems = const [];

  int _extractionNonce = 0;

  MobileScannerController? _inlineController;

  @override
  void initState() {
    super.initState();
    _defaultLocation = TextEditingController();
    _loadSpaces();
  }

  @override
  void dispose() {
    _inlineController?.dispose();
    _defaultLocation.dispose();
    _statusT1?.cancel();
    _statusT2?.cancel();
    _statusT3?.cancel();
    _longWaitT?.cancel();
    _stopInstantScanUi();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _cameraMode) {
      _inlineController?.dispose();
      _inlineController = null;
      setState(() => _cameraMode = false);
    }
  }

  // Counter-based IDs so items created in the same microsecond always get
  // distinct keys, preventing Flutter from reusing widget state across items.
  int _idCounter = 0;
  String _newScannedId() => '${++_idCounter}';

  void _removeItem(String id) {
    if (!mounted) return;
    setState(() {
      _scannedItems = _scannedItems.where((s) => s.id != id).toList();
      if (_saveFailures.containsKey(id)) {
        final next = Map<String, String>.from(_saveFailures);
        next.remove(id);
        _saveFailures = next;
      }
    });
  }

  void _removeItemAt(int index) {
    if (!mounted) return;
    setState(() {
      final updated = List<_ScannedItem>.from(_scannedItems);
      if (index < 0 || index >= updated.length) return;
      final id = updated[index].id;
      updated.removeAt(index);
      _scannedItems = updated;
      if (_saveFailures.containsKey(id)) {
        final next = Map<String, String>.from(_saveFailures);
        next.remove(id);
        _saveFailures = next;
      }
    });
  }

  void _cancelScan() {
    _statusT1?.cancel();
    _statusT2?.cancel();
    _statusT3?.cancel();
    _longWaitT?.cancel();
    _stopInstantScanUi();
    _extractionNonce++;

    if (mounted) {
      _inlineController?.dispose();
      _inlineController = null;
      setState(() {
        _loading = false;
        _saving = false;
        _error = null;
        _scanStatus = null;
        _scanStage = null;
        _showLongWaitHint = false;
        _lastErrorWasExtraction = false;
        _fakeProgress = 0.0;
        _scannedItems = const [];
        _saveFailures = const {};
        _showTrackCategoryPrompt = false;
        _lastSavedCategory = null;
        _lastSavedLocation = null;
        _cameraMode = false;
      });
    }

    Navigator.of(context).maybePop();
  }

  void _stopInstantScanUi() {
    _rotateStatusT?.cancel();
    _rotateStatusT = null;
    _fakeProgressT?.cancel();
    _fakeProgressT = null;
  }

  void _startInstantScanUi() {
    _stopInstantScanUi();
    _rotateStatusIndex = 0;
    _fakeProgress = 0.0;
    _scanStatus = _instantScanStatuses.first;

    final started = DateTime.now();
    _rotateStatusT = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted || !_loading) return;
      setState(() {
        _rotateStatusIndex =
            (_rotateStatusIndex + 1) % _instantScanStatuses.length;
        _scanStatus = _instantScanStatuses[_rotateStatusIndex];
      });
    });

    _fakeProgressT = Timer.periodic(const Duration(milliseconds: 30), (t) {
      if (!mounted || !_loading) {
        t.cancel();
        return;
      }
      final elapsedMs =
          DateTime.now().difference(started).inMilliseconds.toDouble();
      final next = (elapsedMs / 1500.0) * 0.80;
      if (next >= 0.80) {
        setState(() => _fakeProgress = 0.80);
        t.cancel();
        return;
      }
      setState(() => _fakeProgress = next.clamp(0.0, 0.80));
    });
  }

  Future<ImageSource?> _pickPhotoSource() async {
    if (!mounted) return null;
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined,
                        color: Colors.white),
                    title: const Text('Take Photo',
                        style: TextStyle(color: Colors.white)),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_outlined,
                        color: Colors.white),
                    title: const Text('Choose from Library',
                        style: TextStyle(color: Colors.white)),
                    onTap: () =>
                        Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showExtractionReviewModal({required int ok, required int failed}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Some items need review'),
          content: Text(
            'Added $ok items successfully. $failed items couldn’t be recognized.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Review'),
            ),
          ],
        );
      },
    );
  }

  String _stageLabel(_ScanStage? s) {
    switch (s) {
      case _ScanStage.uploading:
        return 'Uploading image...';
      case _ScanStage.analyzing:
        return 'Analyzing your photo...';
      case _ScanStage.extracting:
        return 'Extracting details...';
      case null:
        return 'Preparing scan…';
    }
  }

  double _stageProgress(_ScanStage? s) {
    switch (s) {
      case _ScanStage.uploading:
        return 0.22;
      case _ScanStage.analyzing:
        return 0.55;
      case _ScanStage.extracting:
        return 0.85;
      case null:
        return 0.10;
    }
  }

  Future<void> _processBarcode(String trimmedBarcode) async {
    if (trimmedBarcode.startsWith('findez://space/')) {
      final spaceName = Uri.decodeComponent(trimmedBarcode.replaceFirst('findez://space/', ''));
      if (mounted) {
        Navigator.pop(context);
        widget.onSpaceScanned?.call(spaceName);
      }
      return;
    }

    _statusT1?.cancel();
    _statusT2?.cancel();
    _statusT3?.cancel();
    _longWaitT?.cancel();

    if (!mounted) return;
    setState(() {
      _loading = true;
      _saving = false;
      _error = null;
      _lastErrorWasExtraction = false;
      _scanStatus = 'Preparing scan…';
      _scanStage = null;
      _fakeProgress = 0.0;
      _showLongWaitHint = false;
      _scannedItems = const [];
      _saveFailures = const {};
      _showTrackCategoryPrompt = false;
      _lastSavedCategory = null;
      _lastSavedLocation = null;
    });

    _statusT1 = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || !_loading) return;
      setState(() => _scanStatus = 'Reading image…');
    });
    _statusT2 = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_loading) return;
      setState(() => _scanStatus = 'Identifying items…');
    });
    _statusT3 = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_loading) return;
      setState(() => _scanStatus = 'Finalizing results…');
    });

    try {
      final res = await widget.api.barcodeLookup(barcode: trimmedBarcode);
      if (!mounted) return;
      setState(() {
        _scannedItems = [
          _ScannedItem(
            id: _newScannedId(),
            item: ExtractedInventoryItem(
              name: (res.name ?? '').trim(),
              category: _normalizeCategory(res.category ?? 'Unsorted'),
              quantity: 1,
              brand:
                  (res.brand ?? '').trim().isEmpty ? null : res.brand?.trim(),
              partNumber: (res.model ?? '').trim().isEmpty
                  ? null
                  : res.model?.trim(),
              barcode: trimmedBarcode,
            ),
          ),
        ];
      });
    } on dio.DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    } finally {
      _statusT1?.cancel();
      _statusT2?.cancel();
      _statusT3?.cancel();
      _longWaitT?.cancel();
      if (mounted) setState(() => _loading = false);
      if (mounted) setState(() => _scanStatus = null);
    }
  }

  Future<void> _scanBarcode() async {
    if (_loading) return;
    String? barcode;
    try {
      barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const _BarcodeScannerPage()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to scan. Please try again.');
      return;
    }
    if (barcode == null || barcode.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Unable to scan. Please try again.');
      return;
    }
    await _processBarcode(barcode.trim());
  }

  List<int> _compressImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes.toList();
      const maxDim = 1920;
      img.Image resized = decoded;
      if (decoded.width >= decoded.height && decoded.width > maxDim) {
        resized = img.copyResize(decoded, width: maxDim);
      } else if (decoded.height > decoded.width && decoded.height > maxDim) {
        resized = img.copyResize(decoded, height: maxDim);
      }
      return img.encodeJpg(resized, quality: 85);
    } catch (_) {
      return bytes.toList();
    }
  }

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      return 'Connection issue. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _showTimeoutRetryDialog(ImageSource src) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Taking longer than expected',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'This photo is taking a while to process. You can retry or try a clearer photo.',
          style: TextStyle(color: Color(0x99FFFFFF), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0x99FFFFFF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              unawaited(_pick(src));
            },
            child: const Text('Retry', style: TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(ImageSource src) async {
    if (_loading) return;
    try {
      final runNonce = ++_extractionNonce;
      final x = await _picker.pickImage(
        source: src,
        maxWidth: 2048,
        imageQuality: 92,
      );
      if (x == null) return;

      _statusT1?.cancel();
      _statusT2?.cancel();
      _statusT3?.cancel();
      _longWaitT?.cancel();

      if (!mounted) return;
      setState(() {
        _loading = true;
        _saving = false;
        _error = null;
        _lastErrorWasExtraction = false;
        _scanStage = _ScanStage.uploading;
        _showLongWaitHint = false;
        _scanStatus = 'Scanning…';
        _fakeProgress = 0.0;
        _scannedItems = const [];
        _saveFailures = const {};
        _showTrackCategoryPrompt = false;
        _lastSavedCategory = null;
        _lastSavedLocation = null;
      });

      _startInstantScanUi();

      _statusT1 = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || !_loading) return;
        setState(() {
          _scanStage = _ScanStage.uploading;
        });
      });
      _statusT2 = Timer(const Duration(milliseconds: 800), () {
        if (!mounted || !_loading) return;
        setState(() {
          _scanStage = _ScanStage.analyzing;
        });
      });
      _statusT3 = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted || !_loading) return;
        setState(() {
          _scanStage = _ScanStage.extracting;
        });
      });

      _longWaitT = Timer(const Duration(seconds: 3), () {
        if (!mounted || !_loading) return;
        setState(() {
          _showLongWaitHint = true;
        });
      });

      final rawBytes = await x.readAsBytes();
      final bytes = _compressImageBytes(rawBytes);
      developer.log(
        'SCAN REQUEST SENT: ${<String, dynamic>{
          'filename': x.name,
          'original_bytes': rawBytes.length,
          'compressed_bytes': bytes.length,
        }}',
      );
      debugPrint('FINDEZ scan: calling extractInventoryFromImage with ${bytes.length} bytes, filename: ${x.name}');
      final res = await widget.api.extractInventoryFromImage(
        bytes: bytes,
        filename: x.name,
      );
      developer.log(
        'SCAN RESPONSE: ${<String, dynamic>{
          'items': res.items.length,
          'total_detected': res.summary.totalDetected,
          'categories': res.summary.categories,
        }}',
      );
      if (!mounted) return;
      _stopInstantScanUi();
      setState(() {
        _fakeProgress = 1.0;
      });

      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      if (runNonce != _extractionNonce) return;
      setState(() {
        _scannedItems = res.items
            .map((it) => _ScannedItem(id: _newScannedId(), item: it))
            .toList();
      });

      if (_scannedItems.isEmpty && runNonce == _extractionNonce) {
        setState(() {
          _lastErrorWasExtraction = true;
          _error = 'Unable to scan. Please try again.';
        });
        return;
      }

      final failed = res.items.where((it) {
        return it.name.trim().isEmpty || it.category.trim().isEmpty;
      }).length;
      final ok = res.items.length - failed;
      if (failed > 0 && runNonce == _extractionNonce) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (runNonce != _extractionNonce) return;
          unawaited(_showExtractionReviewModal(ok: ok, failed: failed));
        });
      }
    } on dio.DioException catch (e) {
      debugPrint('FINDEZ scan error: ${e.response?.statusCode} | ${e.response?.data} | ${e.message}');
      if (!mounted) return;
      if (e.response?.statusCode == 429) {
        _stopInstantScanUi();
        if (!ProStatus.isPro) {
          final detail = e.response?.data?['detail'];
          final message = detail is Map
              ? detail['message'] as String?
              : 'You\'ve reached your free scan limit.';
          showUpgradeSheet(
            context,
            widget.api,
            reason: message ?? 'You\'ve reached your free scan limit.',
          );
        } else {
          // Pro users should not receive 429 — refresh status in case DB is stale
          unawaited(ProStatus.refresh(widget.api));
          setState(() => _error = 'Something went wrong. Please try again.');
        }
        return;
      }
      _lastErrorWasExtraction = true;
      _stopInstantScanUi();
      final isTimeout = e.type == dio.DioExceptionType.receiveTimeout ||
          e.type == dio.DioExceptionType.sendTimeout ||
          e.type == dio.DioExceptionType.connectionTimeout ||
          e.response?.statusCode == 502 ||
          e.response?.statusCode == 503 ||
          e.response?.statusCode == 504;
      if (isTimeout) {
        unawaited(_showTimeoutRetryDialog(src));
      } else {
        setState(() => _error = 'Connection issue. Please try again.');
      }
    } catch (e) {
      debugPrint('FINDEZ scan unknown error: $e');
      if (!mounted) return;
      _lastErrorWasExtraction = true;
      _stopInstantScanUi();
      setState(
        () => _error = 'Something went wrong. Please try again.',
      );
    } finally {
      _statusT1?.cancel();
      _statusT2?.cancel();
      _statusT3?.cancel();
      _longWaitT?.cancel();
      _stopInstantScanUi();
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        setState(() {
          _scanStatus = null;
          _scanStage = null;
          _showLongWaitHint = false;
        });
      }
    }
  }

  Future<void> _onTrackTapped() async {
    final cat = (_lastSavedCategory ?? '').trim();
    final loc = (_lastSavedLocation ?? '').trim();
    setState(() => _showTrackCategoryPrompt = false);
    final matching = InventoryCache.items.where((it) {
      return it.category.trim().toLowerCase() == cat.toLowerCase() &&
          it.location.trim().toLowerCase() == loc.toLowerCase();
    }).toList();
    for (final item in matching) {
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: 1);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Tracking ${matching.length} $cat items in $loc'),
      ),
    );
  }

  Future<void> _loadSpaces() async {
    try {
      final result = await widget.api.searchItems(query: '');
      final spaces = result.items
          .map((i) => i.location.trim().isEmpty ? 'Unsorted' : i.location.trim())
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _availableSpaces = spaces);
    } catch (_) {}
  }

  Future<void> _showSpacePicker() async {
    final newSpaceCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Save to Space',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose where to save these items',
                style: TextStyle(color: Color(0x73FFFFFF), fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_availableSpaces.isNotEmpty) ...[
                const Text(
                  'YOUR SPACES',
                  style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSpaces.map((space) => GestureDetector(
                    onTap: () {
                      setState(() => _defaultLocation.text = space);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _defaultLocation.text == space
                            ? Colors.white
                            : const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: _defaultLocation.text == space
                              ? Colors.white
                              : const Color(0x14FFFFFF),
                        ),
                      ),
                      child: Text(
                        space,
                        style: TextStyle(
                          color: _defaultLocation.text == space ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight: _defaultLocation.text == space ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'CREATE NEW SPACE',
                style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newSpaceCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Robot Room, Pit, Electrical',
                        hintStyle: const TextStyle(color: Color(0x4DFFFFFF)),
                        filled: true,
                        fillColor: const Color(0x0AFFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0x14FFFFFF)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0x14FFFFFF)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0x40FFFFFF)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          setState(() => _defaultLocation.text = value.trim());
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      final name = newSpaceCtrl.text.trim();
                      if (name.isNotEmpty) {
                        setState(() => _defaultLocation.text = name);
                        Navigator.pop(ctx);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Create',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveFailureSummary({
    required int total,
    required int inserted,
    required Map<String, String> allFailures,
    required int silentDrops,
  }) {
    if (!mounted) return;
    final idToItem = {for (final s in _scannedItems) s.id: s};
    final lines = <String>[];
    for (final entry in allFailures.entries) {
      final name = idToItem[entry.key]?.item.name ?? 'Unknown item';
      lines.add('• "$name": ${entry.value}');
    }
    if (silentDrops > 0) {
      lines.add(
        '• $silentDrops item${silentDrops == 1 ? '' : 's'} could not be '
        'identified by the server (possible name conflict).',
      );
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          '$inserted of $total item${total == 1 ? '' : 's'} saved',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Some items could not be saved:',
              style: TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
            ),
            const SizedBox(height: 10),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  line,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fix the highlighted rows and tap Save All to retry.',
              style: TextStyle(color: Color(0x73FFFFFF), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: Color(0xFF0A84FF)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSaveAllTapped() async {
    final prefs = await SharedPreferences.getInstance();
    final confirm = prefs.getBool('confirm_before_save') ?? false;
    if (!confirm) {
      await _saveAll();
      return;
    }
    if (!mounted) return;
    final items = _scannedItems.map((s) => s.item).toList();
    final edited = await showModalBottomSheet<List<ExtractedInventoryItem>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmScanSheet(items: items),
    );
    if (edited == null || !mounted) return;
    setState(() {
      _scannedItems = edited
          .map((e) => _ScannedItem(id: _newScannedId(), item: e))
          .toList();
    });
    await _saveAll();
  }

  Future<void> _saveAll() async {
    if (_defaultLocation.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a space first')),
      );
      await _showSpacePicker();
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
      _saveFailures = const {};
    });

    try {
      final fallbackLocation = _defaultLocation.text.trim().isEmpty
          ? 'Unsorted'
          : _defaultLocation.text.trim();
      final normalized = <ExtractedInventoryItem>[];
      final indexMap = <String>[];

      final failures = <String, String>{};
      for (final s in _scannedItems) {
        final it = s.item;
        final name = it.name.trim();
        final category = _normalizeCategory(it.category);
        final location = (it.location ?? '').trim();

        if (name.isEmpty || category.isEmpty) {
          failures[s.id] = 'Name and category are required.';
          continue;
        }

        normalized.add(
          ExtractedInventoryItem(
            name: name,
            category: category,
            quantity: it.quantity,
            subcategory: it.subcategory,
            brand: it.brand,
            partNumber: it.partNumber,
            barcode: it.barcode,
            tags: it.tags,
            confidence: it.confidence,
            notes: it.notes,
            location: location.isEmpty ? fallbackLocation : location,
          ),
        );
        indexMap.add(s.id);
      }

      if (normalized.isEmpty) {
        if (!mounted) return;
        setState(() {
          _saveFailures = failures;
          _error = 'Fix the highlighted rows and try again.';
        });
        return;
      }

      debugPrint(
        ‘FINDEZ bulkCreate: sending ${normalized.length} item(s) — ‘
        ‘${normalized.map((it) => ‘"${it.name}" [${it.category}] → ${it.location}’).join(‘, ‘)}’,
      );

      final res = await widget.api.bulkCreateInventory(items: normalized);
      if (!mounted) return;

      debugPrint(
        ‘FINDEZ bulkCreate: response — inserted=${res.inserted.length} ‘
        ‘failures=${res.failures.length} — ‘
        ‘${res.inserted.map((it) => ‘"${it.name}" id=${it.itemId}’).join(‘, ‘)}’,
      );

      final backendFailures = <String, String>{};
      for (final f in res.failures) {
        final idx = (f[‘index’] is num)
            ? (f[‘index’] as num).toInt()
            : int.tryParse((f[‘index’] ?? ‘’).toString());
        if (idx == null) continue;
        final id = (idx >= 0 && idx < indexMap.length) ? indexMap[idx] : null;
        if (id == null) continue;
        backendFailures[id] =
            (f[‘reason’] ?? ‘Couldn\’t save this item.’).toString();
      }

      final allFailures = <String, String>{...failures, ...backendFailures};
      if (allFailures.isNotEmpty) {
        setState(() => _saveFailures = allFailures);
      }

      final insertedCount = res.inserted.length;
      // Items silently dropped: sent to server but neither inserted nor failed.
      // This happens when the backend deduplicates two items with the same
      // normalized name within a single batch.
      final silentDrops =
          normalized.length - insertedCount - res.failures.length;
      if (silentDrops > 0) {
        debugPrint(
          ‘FINDEZ bulkCreate: WARNING — $silentDrops item(s) silently dropped ‘
          ‘(server name deduplication). Sent=${normalized.length}, ‘
          ‘inserted=$insertedCount, explicit_failures=${res.failures.length}.’,
        );
      }

      if (insertedCount > 0) {
        final loc = fallbackLocation;
        String? cat;
        for (final it in normalized) {
          final c = _normalizeCategory(it.category);
          if (c.isNotEmpty) {
            cat = c;
            break;
          }
        }

        final totalExpected = _scannedItems.length;
        final allSucceeded =
            allFailures.isEmpty && silentDrops == 0 && insertedCount == normalized.length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allSucceeded
                  ? ‘Saved $insertedCount item${insertedCount == 1 ? ‘’ : ‘s’} to $loc’
                  : ‘Saved $insertedCount of $totalExpected items to $loc’,
            ),
          ),
        );
        widget.onSaved();

        if (allSucceeded) {
          // Every item saved — clear the list and offer QR codes.
          final noBarcodeItems = res.inserted
              .where((it) => it.barcode == null || it.barcode!.trim().isEmpty)
              .toList();
          setState(() {
            _scannedItems = const [];
            _saveFailures = const {};
            _error = null;
            _scanStatus = null;
            _scanStage = null;
            _showLongWaitHint = false;
            _lastErrorWasExtraction = false;
            _showTrackCategoryPrompt = true;
            _lastSavedCategory = cat;
            _lastSavedLocation = loc;
          });
          if (noBarcodeItems.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (noBarcodeItems.length == 1) {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) =>
                      QrOfferSheet(itemId: noBarcodeItems.first.itemId),
                );
              } else {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => BulkQrOfferSheet(items: noBarcodeItems),
                );
              }
            });
          }
        } else {
          // Partial save — keep failed items visible; show summary dialog.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showSaveFailureSummary(
              total: totalExpected,
              inserted: insertedCount,
              allFailures: allFailures,
              silentDrops: silentDrops,
            );
          });
        }
      } else {
        setState(
          () => _error =
              ‘Couldn\’t save those items. Fix the highlighted rows and try again.’,
        );
      }
    } on dio.DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    const accent = LinearGradient(
      colors: [
        Color(0xFF5EEAD4),
        Color(0xFF60A5FA),
        Color(0xFFC084FC),
        Color(0xFFF472B6),
        Color(0xFFFCA5A5),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _cancelScan,
            style: TextButton.styleFrom(foregroundColor: const Color(0x73FFFFFF)),
            child: const Text('Cancel'),
          ),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: _scannedItems.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab_scan',
              onPressed: _saving ? null : _onSaveAllTapped,
              label: Text(_saving ? 'Saving…' : 'Save All'),
              icon: ShaderMask(
                shaderCallback: (rect) => accent.createShader(rect),
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.save_outlined),
              ),
            ),
      body: Container(
        color: Colors.black,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, isIOS ? 16 : 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_showTrackCategoryPrompt)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          () {
                            final cat = (_lastSavedCategory ?? '').trim();
                            final loc = (_lastSavedLocation ?? '').trim();
                            final locPart = loc.isEmpty ? '' : ' for $loc';
                            if (cat.isEmpty) return 'Track this category?$locPart';
                            return 'Track "$cat"?$locPart';
                          }(),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showTrackCategoryPrompt = false;
                          });
                        },
                        child: const Text('Not now'),
                      ),
                      FilledButton(
                        onPressed: () => unawaited(_onTrackTapped()),
                        child: const Text('Track'),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _loading
                          ? null
                          : () => setState(() => _cameraMode = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _cameraMode
                              ? const Color(0xFF64D2FF).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                          border: _cameraMode
                              ? Border.all(
                                  color: const Color(0xFF64D2FF).withValues(alpha: 0.30),
                                  width: 0.5,
                                )
                              : Border.all(
                                  color: Colors.transparent,
                                  width: 0.5,
                                ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_camera_outlined,
                              color: _cameraMode
                                  ? const Color(0xFF64D2FF)
                                  : const Color(0x4DFFFFFF),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Scan with camera',
                              style: TextStyle(
                                color: _cameraMode
                                    ? const Color(0xFF64D2FF)
                                    : const Color(0x4DFFFFFF),
                                fontSize: 14,
                                fontWeight: _cameraMode
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _loading
                          ? null
                          : () async {
                              if (_cameraMode) {
                                _inlineController?.dispose();
                                _inlineController = null;
                                setState(() => _cameraMode = false);
                              }
                              final src = await _pickPhotoSource();
                              if (src == null) return;
                              await _pick(src);
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_cameraMode
                              ? const Color(0xFFBF5AF2).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                          border: !_cameraMode
                              ? Border.all(
                                  color: const Color(0xFFBF5AF2).withValues(alpha: 0.30),
                                  width: 0.5,
                                )
                              : Border.all(
                                  color: Colors.transparent,
                                  width: 0.5,
                                ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_outlined,
                              color: !_cameraMode
                                  ? const Color(0xFFBF5AF2)
                                  : const Color(0x4DFFFFFF),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Upload photo',
                              style: TextStyle(
                                color: !_cameraMode
                                    ? const Color(0xFFBF5AF2)
                                    : const Color(0x4DFFFFFF),
                                fontSize: 14,
                                fontWeight: !_cameraMode
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0x4DFF3B30),
                    width: 0.5,
                  ),
                ),
                child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF3B30),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _lastErrorWasExtraction
                                    ? 'Couldn’t extract item details. Try another photo.'
                                    : 'Couldn’t scan that photo.',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        if (!_lastErrorWasExtraction) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Try another photo, or use the camera.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.70),
                                ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.45),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
              ),
            const SizedBox(height: 12),
            if (_scannedItems.isNotEmpty) ...[
              GestureDetector(
                onTap: () => _showSpacePicker(),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x14FFFFFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_outlined, color: Color(0x73FFFFFF), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _defaultLocation.text.isEmpty ? 'Select a space...' : _defaultLocation.text,
                          style: TextStyle(
                            color: _defaultLocation.text.isEmpty
                                ? const Color(0x4DFFFFFF)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0x4DFFFFFF), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _loading
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Text(
                                      (_scanStatus ?? _stageLabel(_scanStage)),
                                      key: ValueKey<String>(
                                        (_scanStatus ??
                                            _stageLabel(_scanStage)),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      minHeight: 6,
                                      value: _loading
                                          ? (_fakeProgressT != null
                                              ? _fakeProgress
                                              : _stageProgress(_scanStage))
                                          : null,
                                      backgroundColor:
                                          Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        Colors.white.withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                  if (_showLongWaitHint) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      'Analyzing your photo — this may take a moment...',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.60,
                                            ),
                                            height: 1.35,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : (_scannedItems.isEmpty
                            ? (_cameraMode && widget.isActive
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: MobileScanner(
                                      controller: (_inlineController ??= MobileScannerController(
                                        formats: const <BarcodeFormat>[BarcodeFormat.all],
                                      )),
                                      errorBuilder: (context, error) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.warning_amber_outlined,
                                                  color: Color(0x4DFFFFFF),
                                                  size: 32,
                                                ),
                                                const SizedBox(height: 12),
                                                const Text(
                                                  'Camera not available on this device',
                                                  style: TextStyle(
                                                    color: Color(0x4DFFFFFF),
                                                    fontSize: 13,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 6),
                                                const Text(
                                                  'Use Upload photo to add items',
                                                  style: TextStyle(
                                                    color: Color(0x33FFFFFF),
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      onDetect: (capture) {
                                        final codes = capture.barcodes;
                                        if (codes.isEmpty) return;
                                        final raw = codes.first.rawValue;
                                        if (raw == null || raw.trim().isEmpty) return;
                                        _inlineController?.dispose();
                                        _inlineController = null;
                                        setState(() => _cameraMode = false);
                                        unawaited(_processBarcode(raw.trim()));
                                      },
                                    ),
                                    ),
                                  )
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFBF5AF2).withValues(alpha: 0.08),
                                                  blurRadius: 40,
                                                  spreadRadius: 15,
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.qr_code_scanner,
                                              color: Color(0x33FFFFFF),
                                              size: 48,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Point your camera at a barcode,\nor upload a photo of any item.',
                                            style: TextStyle(
                                              color: Color(0x4DFFFFFF),
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                            : ListView.separated(
                                itemCount: _scannedItems.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final s = _scannedItems[index];
                                  return _ExtractedRow(
                                    key: ValueKey(s.id),
                                    item: s.item,
                                    errorText: _saveFailures[s.id],
                                    onDelete: () => _removeItemAt(index),
                                    onChanged: (next) {
                                      _scannedItems[index] =
                                          _scannedItems[index].copyWith(
                                        item: next,
                                      );
                                      if (_saveFailures.containsKey(s.id)) {
                                        setState(() {
                                          final nextFailures =
                                              Map<String, String>.from(
                                            _saveFailures,
                                          );
                                          nextFailures.remove(s.id);
                                          _saveFailures = nextFailures;
                                        });
                                      }
                                    },
                                  );
                                },
                              )),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _ExtractedRow extends StatefulWidget {
  const _ExtractedRow({
    super.key,
    required this.item,
    required this.onChanged,
    this.onDelete,
    this.errorText,
  });

  final ExtractedInventoryItem item;
  final ValueChanged<ExtractedInventoryItem> onChanged;
  final VoidCallback? onDelete;
  final String? errorText;

  @override
  State<_ExtractedRow> createState() => _ExtractedRowState();
}

class _ExtractedRowState extends State<_ExtractedRow> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _qty;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _category = TextEditingController(text: widget.item.category);
    _location = TextEditingController(text: widget.item.location ?? '');
    _qty = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void didUpdateWidget(_ExtractedRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controllers if the underlying item changed while this state was
    // reused (defense-in-depth against any future key collision).
    if (oldWidget.item != widget.item) {
      if (_name.text != widget.item.name) _name.text = widget.item.name;
      if (_category.text != widget.item.category) _category.text = widget.item.category;
      final loc = widget.item.location ?? '';
      if (_location.text != loc) _location.text = loc;
      final qty = widget.item.quantity.toString();
      if (_qty.text != qty) _qty.text = qty;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _emit() {
    final next = ExtractedInventoryItem(
      name: _name.text.trim(),
      category: _category.text.trim(),
      quantity: int.tryParse(_qty.text.trim()) ?? 0,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      subcategory: widget.item.subcategory,
      brand: widget.item.brand,
      partNumber: widget.item.partNumber,
      barcode: widget.item.barcode,
      tags: widget.item.tags,
      confidence: widget.item.confidence,
      notes: widget.item.notes,
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final showError =
        widget.errorText != null && widget.errorText!.trim().isNotEmpty;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      trailing: widget.onDelete == null
          ? null
          : IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Remove',
            ),
      title: TextField(
        controller: _name,
        onChanged: (_) => _emit(),
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _category,
                    onChanged: (_) => _emit(),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _location,
                    onChanged: (_) => _emit(),
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _qty,
                    onChanged: (_) => _emit(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
              ],
            ),
            if (showError) ...[
              const SizedBox(height: 10),
              Text(
                widget.errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
