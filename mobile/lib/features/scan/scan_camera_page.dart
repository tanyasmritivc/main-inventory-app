import 'scan_experience.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';
import '../../core/private_image.dart';
import 'confirm_scan_sheet.dart';
import 'photo_scan_session.dart';
import 'scan_destination.dart';

enum ScanMode { photo, library }

abstract class ScanCameraSource {
  Future<void> open();
  Future<Uint8List> capture();
  Widget preview();
  Future<void> dispose();
}

class NativeScanCamera implements ScanCameraSource {
  CameraController? _controller;
  @override
  Future<void> open() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera');
    final back = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    final controller = CameraController(
      back.isEmpty ? cameras.first : back.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;
    await controller.initialize();
  }

  @override
  Future<Uint8List> capture() async =>
      (await _controller!.takePicture()).readAsBytes();
  @override
  Widget preview() => Center(child: CameraPreview(_controller!));
  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

class ScanOutcome {
  const ScanOutcome(this.names, this.location);
  final List<String> names;
  final String? location;
}

class ScanCameraPage extends StatefulWidget {
  const ScanCameraPage({
    super.key,
    required this.api,
    this.destination,
    this.cameraFactory,
    this.libraryPicker,
  });
  final ApiClient api;
  final ScanDestination? destination;
  final ScanCameraSource Function()? cameraFactory;
  final Future<Uint8List?> Function()? libraryPicker;
  @override
  State<ScanCameraPage> createState() => _ScanCameraPageState();
}

class _ScanCameraPageState extends State<ScanCameraPage>
    with WidgetsBindingObserver {
  ScanCameraSource? _camera;
  PhotoScanSession? _session;
  ScanDestination? _destination;
  ScanMode _mode = ScanMode.photo;
  bool _ready = false, _busy = false, _saving = false;
  int _cameraGeneration = 0, _operation = 0, _scanCycle = 0;
  bool _capturing = false;
  String? _error;
  String _status = 'Fit the shelf in the frame';
  Uint8List? _photo;
  Timer? _elapsedTimer;
  DateTime? _started;
  CancelToken? _cancel;
  final Set<String> _newSaved = {};
  Future<void> _cameraWork = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _destination = widget.destination;
    _openCamera();
  }

  void _check() {
    if (!mounted) throw StateError('Scan closed');
    widget.api.assertCurrentContext();
    _destination?.api.assertCurrentContext();
  }

  Future<void> _openCamera() async {
    final generation = ++_cameraGeneration;
    _cameraWork = _cameraWork.catchError((_) {}).then((_) async {
      await _camera?.dispose();
      _camera = null;
      if (!mounted || generation != _cameraGeneration) return;
      final camera = (widget.cameraFactory ?? NativeScanCamera.new)();
      _camera = camera;
      try {
        await camera.open();
        if (!mounted || generation != _cameraGeneration) {
          await camera.dispose();
          return;
        }
        setState(() {
          _ready = true;
          _error = null;
        });
      } catch (_) {
        await camera.dispose();
        if (mounted && generation == _cameraGeneration) {
          setState(() {
            _ready = false;
            _error =
                'Camera unavailable. Allow camera access in Settings, or choose Photo Library.';
          });
        }
      }
    });
    await _cameraWork;
  }

  Future<void> _closeCamera() async {
    ++_cameraGeneration;
    _ready = false;
    _cameraWork = _cameraWork.catchError((_) {}).then((_) async {
      await _camera?.dispose();
      _camera = null;
    });
    await _cameraWork;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
      unawaited(_closeCamera());
    } else if (_mode != ScanMode.library && _photo == null) {
      unawaited(_openCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_operation;
    _elapsedTimer?.cancel();
    _cancel?.cancel();
    unawaited(_closeCamera());
    super.dispose();
  }

  void _pause() {
    ++_scanCycle;
    _elapsedTimer?.cancel();
    _started = null;
    ++_operation;
    _cancel?.cancel();
    if (mounted) {
      setState(() {
        _busy = false;
        _status = 'Paused';
      });
    }
  }

  Future<bool> _chooseDestination() async {
    if (_session != null) return true;
    _destination ??= await Navigator.push<ScanDestination>(
      context,
      MaterialPageRoute(builder: (_) => ScanDestinationPage(api: widget.api)),
    );
    if (_destination == null || !mounted) return false;
    _check();
    final session = PhotoScanSession(
      _destination!.api,
      _destination!.id,
      _destination!.name,
    );
    await session.restore();
    _check();
    setState(() => _session = session);
    return true;
  }

  Future<void> _switch(ScanMode mode) async {
    if (_saving || _busy) return;
    _pause();
    setState(() {
      _mode = mode;
      _photo = null;
      _error = null;
      _status = 'Fit the shelf in the frame';
    });
    if (mode == ScanMode.library) {
      await _closeCamera();
      try {
        Uint8List? bytes;
        if (widget.libraryPicker != null) {
          bytes = await widget.libraryPicker!();
        } else {
          final file = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 2048,
            maxHeight: 2048,
            imageQuality: 92,
            requestFullMetadata: false,
          );
          if (file != null && await file.length() <= 10 * 1024 * 1024) {
            bytes = await file.readAsBytes();
          } else if (file != null) {
            throw const FormatException('Choose a photo smaller than 10 MB.');
          }
        }
        if (bytes != null && mounted) await _readPhoto(bytes);
      } catch (e) {
        if (mounted) setState(() => _error = describeError(e).$1);
      }
    } else {
      await _openCamera();
    }
  }

  Future<void> _capture() async {
    if (!_ready || _busy || _saving || _capturing) return;
    _capturing = true;
    final captureGeneration = _operation;
    final cycle = _scanCycle;
    setState(() => _busy = true);
    try {
      final bytes = await _camera!.capture();
      if (!mounted || captureGeneration != _operation) return;
      _check();
      await _readPhoto(bytes);
    } catch (_) {
      if (mounted && cycle == _scanCycle) {
        setState(() => _error = 'Could not take this photo. Try again.');
      }
    } finally {
      _capturing = false;
      if (mounted && cycle == _scanCycle) setState(() => _busy = false);
    }
  }

  Future<void> _readPhoto(Uint8List bytes) async {
    final operation = ++_operation;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 10 MB.');
    }
    setState(() => _photo = bytes);
    await _closeCamera();
    if (!await _chooseDestination() || !mounted || operation != _operation) {
      return;
    }
    _check();
    _cancel = CancelToken();
    _started = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Reading the photo…';
    });
    try {
      final result = await _destination!.api.extractInventoryFromImage(
        bytes: bytes,
        filename: 'scan.jpg',
        cancelToken: _cancel,
        onProgress: (progress) {
          if (mounted && operation == _operation) {
            setState(() => _status = progress);
          }
        },
      );
      if (!mounted || operation != _operation) return;
      _check();
      final added = await _session!.accept(result.items);
      if (!mounted || operation != _operation) return;
      setState(
        () => _status = added.isEmpty
            ? 'No new items in this photo'
            : 'Found ${added.length} ${added.length == 1 ? 'item' : 'items'}',
      );
    } catch (e) {
      if (mounted &&
          operation == _operation &&
          !CancelToken.isCancel(
            e is DioException
                ? e
                : DioException(requestOptions: RequestOptions()),
          )) {
        setState(
          () => _error =
              'Could not finish reading. Your saved items are unchanged. Try again.',
        );
      }
    } finally {
      _saving = false;
      if (mounted && operation == _operation) {
        _elapsedTimer?.cancel();
        _started = null;
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _review(
    PhotoDetection row, {
    bool alreadyReviewed = false,
  }) async {
    if (_busy || _saving || row.ignored || row.savedId != null) return;
    _pause();
    if (!row.attempted && !alreadyReviewed) {
      final reviewed = await showModalBottomSheet<List<ExtractedInventoryItem>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConfirmScanSheet(
          items: [ExtractedInventoryItem.fromJson(row.item.toJson())],
          defaultLocation: _destination!.name,
          existingItems: const [],
        ),
      );
      if (!mounted || reviewed == null || reviewed.isEmpty) return;
      row.item = reviewed.single..location = _destination!.name;
    }
    setState(() => _saving = true);
    try {
      var saved = await _session!.save(row);
      if (!saved &&
          !row.attempted &&
          row.issue?.startsWith('Possible existing item') == true &&
          mounted) {
        final separate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Possible existing item'),
            content: const Text(
              'An item like this is already in this inventory. Save a separate item?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep in review'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save separately'),
              ),
            ],
          ),
        );
        if (separate == true && mounted) {
          saved = await _session!.save(row, allowExisting: true);
        }
      }
      if (saved) await _recordSaved(row);
      InventoryCache.clear();
    } catch (_) {
      if (mounted) _error = 'Could not retain this scan. Try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAll() async {
    if (_busy || _saving) return;
    _pause();
    final rows =
        _session?.rows
            .where((row) => row.savedId == null && !row.ignored)
            .toList() ??
        [];
    final editable = rows.where((row) => !row.attempted).toList();
    if (editable.isNotEmpty) {
      final reviewed = await showModalBottomSheet<List<ExtractedInventoryItem>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConfirmScanSheet(
          items: editable
              .map((row) => ExtractedInventoryItem.fromJson(row.item.toJson()))
              .toList(),
          defaultLocation: _destination!.name,
          existingItems: const [],
        ),
      );
      if (!mounted || reviewed == null || reviewed.length != editable.length) {
        return;
      }
      for (var i = 0; i < editable.length; i++) {
        editable[i].item = reviewed[i]..location = _destination!.name;
      }
    }
    for (final row in rows) {
      if (!mounted) return;
      await _review(row, alreadyReviewed: true);
    }
  }

  Future<void> _recordSaved(PhotoDetection row) async {
    _newSaved.add(row.requestId);
    final actor = widget.api.accountId;
    if (actor == null) return;
    final experience = ScanExperience(
      actor,
      widget.api.worldKey ??
          widget.api.inventoryContext?.organizationId ??
          'personal',
    );
    try {
      await experience.load();
      await experience.saved(
        _session!.rows
            .where((row) => row.savedId != null && !row.ignored)
            .map((row) => row.item.name)
            .toList(),
        _destination?.name,
      );
    } catch (_) {
      /* The inventory receipt remains authoritative. */
    }
  }

  Future<void> _undo(PhotoDetection row) async {
    if (_saving || _busy) return;
    _pause();
    setState(() => _saving = true);
    try {
      if (!await _session!.undo(row)) throw StateError('Undo not confirmed');
      _newSaved.remove(row.requestId);
      final actor = widget.api.accountId;
      if (actor != null) {
        final experience = ScanExperience(
          actor,
          widget.api.worldKey ??
              widget.api.inventoryContext?.organizationId ??
              'personal',
        );
        await experience.load();
        await experience.replaceSuggestions(
          _session!.rows
              .where((row) => row.savedId != null && !row.ignored)
              .map((row) => row.item.name)
              .toList(),
        );
      }
      InventoryCache.clear();
    } catch (_) {
      if (mounted) _error = 'Undo could not be confirmed. Try again.';
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _done() async {
    if (_saving) return;
    _pause();
    final names =
        _session?.rows
            .where(
              (row) => row.savedId != null && _newSaved.contains(row.requestId),
            )
            .map((row) => row.item.name)
            .toList() ??
        <String>[];
    try {
      await _session?.finish();
    } catch (_) {
      /* Receipts remain available for recovery. */
    }
    if (mounted) Navigator.pop(context, ScanOutcome(names, _destination?.name));
  }

  Widget _row(PhotoDetection row) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: PrivateImage(
                row.item.imageUrl!,
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    if (row.item.brand?.isNotEmpty == true) row.item.brand!,
                    if (row.item.partNumber?.isNotEmpty == true)
                      row.item.partNumber!,
                    row.item.scanEvidence?.quantityMissing == true
                        ? 'Count needs review'
                        : 'Qty ${row.item.quantity}',
                  ].join(' · '),
                ),
                Text(
                  row.ignored
                      ? 'Removed'
                      : row.savedId != null
                      ? 'Saved'
                      : row.issue ?? 'Review before saving',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!row.ignored)
            TextButton(
              onPressed: _busy || _saving
                  ? null
                  : () => row.savedId == null ? _review(row) : _undo(row),
              child: Text(
                row.savedId != null
                    ? 'Undo'
                    : row.attempted
                    ? 'Retry'
                    : 'Review',
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final rows = _session?.rows ?? <PhotoDetection>[];
    final pending = rows
        .where((row) => !row.ignored && row.savedId == null)
        .length;
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Close scan',
            onPressed: _saving ? null : _done,
            icon: const Icon(Icons.close),
          ),
          title: const Text('Scan'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _done,
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_photo != null)
                      Image.memory(_photo!, fit: BoxFit.contain)
                    else if (_ready && _camera != null)
                      _camera!.preview()
                    else
                      const Center(
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white54,
                          size: 42,
                        ),
                      ),
                    const IgnorePointer(
                      child: Center(
                        child: FractionallySizedBox(
                          widthFactor: .84,
                          heightFactor: .7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white54),
                              ),
                              borderRadius: BorderRadius.all(
                                Radius.circular(22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Text(
                              _status +
                                  (_started == null
                                      ? ''
                                      : ' · ${DateTime.now().difference(_started!).inSeconds}s'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .48,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(_error!),
                          ),
                        if (_destination != null)
                          Text(
                            '${_destination!.api.inventoryContext?.label ?? ''} · ${_destination!.name}',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            for (final mode in ScanMode.values)
                              ChoiceChip(
                                label: Text(switch (mode) {
                                  ScanMode.photo => 'Take Photo',
                                  ScanMode.library => 'Photo Library',
                                }),
                                selected: _mode == mode,
                                onSelected: _busy || _saving
                                    ? null
                                    : (_) => _switch(mode),
                              ),
                          ],
                        ),
                        if (_busy) const LinearProgressIndicator(),
                        if (_photo == null && _mode == ScanMode.photo)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: IconButton.filled(
                              tooltip: 'Take photo',
                              onPressed: !_ready || _busy ? null : _capture,
                              iconSize: 46,
                              icon: const Icon(Icons.circle_outlined),
                            ),
                          )
                        else if (_busy)
                          TextButton(
                            onPressed: _pause,
                            child: const Text('Stop reading'),
                          )
                        else if (_photo != null && rows.isEmpty)
                          TextButton(
                            onPressed: () => _readPhoto(_photo!),
                            child: const Text('Read photo'),
                          ),
                        if (rows.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final row in rows) _row(row),
                          if (pending > 0)
                            FilledButton(
                              onPressed: _busy || _saving ? null : _saveAll,
                              child: Text(
                                'Save $pending ${pending == 1 ? 'item' : 'items'}',
                              ),
                            ),
                        ],
                      ],
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
