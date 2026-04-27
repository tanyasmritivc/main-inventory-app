import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.api, required this.onSaved});

  final ApiClient api;
  final VoidCallback onSaved;

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
      appBar: AppBar(title: const Text('Scan'), centerTitle: true),
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

  /// Normalizes taxonomy/category strings to simple top-level categories.
  String _normalizeCategory(String rawCategory) {
    final c = rawCategory.trim().toLowerCase();
    if (c.isEmpty) return 'Unsorted';
    if (c.contains('food') || c.contains('grocery') || c.contains('beverage')) return 'Food';
    if (c.contains('cosmetic') || c.contains('beauty') || c.contains('makeup') || c.contains('skincare')) return 'Cosmetics';
    if (c.contains('electronic') || c.contains('tech') || c.contains('gadget') || c.contains('computer') || c.contains('phone')) return 'Electronics';
    if (c.contains('clothing') || c.contains('apparel') || c.contains('fashion') || c.contains('shoe')) return 'Clothing';
    if (c.contains('home') || c.contains('kitchen') || c.contains('furniture') || c.contains('decor')) return 'Home';
    if (c.contains('health') || c.contains('medicine') || c.contains('pharma') || c.contains('supplement')) return 'Health';
    if (c.contains('toy') || c.contains('game') || c.contains('hobby')) return 'Toys';
    if (c.contains('book') || c.contains('media') || c.contains('office')) return 'Office';
    if (c.contains('cleaning') || c.contains('household') || c.contains('supply')) return 'Supplies';
    return 'Other';
  }

  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _scanStatus;

  Timer? _rotateStatusT;
  Timer? _fakeProgressT;
  double _fakeProgress = 0.0;
  int _rotateStatusIndex = 0;

  static const _instantScanStatuses = <String>[
    'Scanning…',
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

  late final TextEditingController _defaultLocation;
  Map<String, String> _saveFailures = const {};

  bool _showTrackCategoryPrompt = false;
  String? _lastSavedCategory;
  String? _lastSavedLocation;

  List<_ScannedItem> _scannedItems = const [];

  int _extractionNonce = 0;

  @override
  void initState() {
    super.initState();
    _defaultLocation = TextEditingController(text: 'Unsorted');
  }

  String _newScannedId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

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

  void _cancelScan() {
    _statusT1?.cancel();
    _statusT2?.cancel();
    _statusT3?.cancel();
    _longWaitT?.cancel();
    _stopInstantScanUi();
    _extractionNonce++;

    if (mounted) {
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
            child: GlassCard(
              padding: const EdgeInsets.all(8),
              borderRadius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_outlined),
                    title: const Text('Choose from Library'),
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
        return 'Analyzing item...';
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

    final trimmedBarcode = barcode.trim();

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

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      return 'Connection issue. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _pick(ImageSource src) async {
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

      final bytes = await x.readAsBytes();
      developer.log(
        'SCAN REQUEST SENT: ${<String, dynamic>{
          'filename': x.name,
          'bytes': bytes.length,
        }}',
      );
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
    } on dio.DioException {
      if (!mounted) return;
      _lastErrorWasExtraction = true;
      _stopInstantScanUi();
      setState(
        () => _error = 'Connection issue. Please try again.',
      );
    } catch (_) {
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

  Future<void> _saveAll() async {
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

      final res = await widget.api.bulkCreateInventory(items: normalized);
      if (!mounted) return;

      final backendFailures = <String, String>{};
      for (final f in res.failures) {
        final idx = (f['index'] is num)
            ? (f['index'] as num).toInt()
            : int.tryParse((f['index'] ?? '').toString());
        if (idx == null) continue;
        final id = (idx >= 0 && idx < indexMap.length) ? indexMap[idx] : null;
        if (id == null) continue;
        backendFailures[id] =
            (f['reason'] ?? 'Couldn’t save this item.').toString();
      }

      if (backendFailures.isNotEmpty || failures.isNotEmpty) {
        final merged = <String, String>{...failures, ...backendFailures};
        setState(() => _saveFailures = merged);
      }

      final inserted = res.inserted.length;
      if (inserted > 0) {
        final loc = fallbackLocation;
        String? cat;
        for (final it in normalized) {
          final c = _normalizeCategory(it.category);
          if (c.isNotEmpty) {
            cat = c;
            break;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved $inserted items to $loc',
            ),
          ),
        );
        widget.onSaved();
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
      } else {
        setState(
          () => _error =
              'Couldn’t save those items. Fix the highlighted rows and try again.',
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
  void dispose() {
    _defaultLocation.dispose();
    _statusT1?.cancel();
    _statusT2?.cancel();
    _statusT3?.cancel();
    _longWaitT?.cancel();
    _stopInstantScanUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    const bgGradient = LinearGradient(
      colors: [
        Color(0xFF020617),
        Color(0xFF0F172A),
        Color(0xFF020617),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Scan'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _cancelScan,
            child: const Text('Cancel'),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: bgGradient),
        ),
      ),
      floatingActionButton: _scannedItems.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveAll,
              label: Text(_saving ? 'Saving…' : 'Save All'),
              icon: ShaderMask(
                shaderCallback: (rect) => accent.createShader(rect),
                blendMode: BlendMode.srcIn,
                child: const Icon(Icons.save_outlined),
              ),
            ),
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
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
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                          setState(() {
                            _showTrackCategoryPrompt = false;
                          });
                        },
                        child: const Text('Track'),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: isIOS
                      ? PrimaryGradientButton(
                          onPressed: _loading ? null : _scanBarcode,
                          height: 52,
                          borderRadius: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (rect) =>
                                    accent.createShader(rect),
                                blendMode: BlendMode.srcIn,
                                child: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Scan with camera',
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _loading ? null : _scanBarcode,
                          icon: ShaderMask(
                            shaderCallback: (rect) =>
                                accent.createShader(rect),
                            blendMode: BlendMode.srcIn,
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              color: Colors.white,
                            ),
                          ),
                          label: const Text(
                            'Scan with camera',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final src = await _pickPhotoSource();
                            if (src == null) return;
                            await _pick(src);
                          },
                    icon: ShaderMask(
                      shaderCallback: (rect) => accent.createShader(rect),
                      blendMode: BlendMode.srcIn,
                      child: const Icon(
                        Icons.photo_outlined,
                        color: Colors.white,
                      ),
                    ),
                    label: const Text(
                      'Upload photo',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: Theme.of(context).colorScheme.error,
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
                ),
              ),
            const SizedBox(height: 12),
            if (_scannedItems.isNotEmpty) ...[
              TextField(
                controller: _defaultLocation,
                decoration: const InputDecoration(
                  labelText: 'Default location',
                  hintText: 'Unsorted',
                  prefixIcon: Icon(Icons.place_outlined),
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
                                      'AI is analyzing your item...',
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
                            ? Center(
                                child: Text(
                                  'Your extracted items will appear here.',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.65),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _scannedItems.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final s = _scannedItems[index];
                                  return _ExtractedRow(
                                    item: s.item,
                                    errorText: _saveFailures[s.id],
                                    onDelete: () => _removeItem(s.id),
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
