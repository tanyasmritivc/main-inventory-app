import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/manual_add_page.dart';
import 'barcode_answer_sheet.dart';
import 'upload_photo_flow.dart';

enum CaptureMode { photo, scan, see }

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.api,
    required this.onSaved,
    this.isActive = false,
    this.onSpaceScanned,
    this.onSkipCoachmark,
    this.showAppBar = true,
    this.requestedMode,
    this.modeRequestSerial = 0,
  });

  final ApiClient api;
  final VoidCallback onSaved;
  final bool isActive;
  final void Function(String spaceName)? onSpaceScanned;
  final VoidCallback? onSkipCoachmark;
  final bool showAppBar;
  final CaptureMode? requestedMode;
  final int modeRequestSerial;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  static const _modeKey = 'capture_mode';
  CaptureMode _mode = CaptureMode.photo;
  CameraController? _camera;
  bool _cameraLoading = false;
  bool _capturing = false;
  bool _answerOpen = false;
  bool _scannerError = false;
  String? _cameraError;
  String? _spaceError;
  String? _barcodeForPhoto;
  List<String> _spaces = const [];
  String? _space;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_restoreMode());
    unawaited(_loadSpaces());
    if (widget.isActive) unawaited(_openCamera());
  }

  @override
  void didUpdateWidget(ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modeRequestSerial != oldWidget.modeRequestSerial &&
        widget.requestedMode != null) {
      unawaited(_selectMode(widget.requestedMode!));
    }
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      if (_mode == CaptureMode.photo) unawaited(_openCamera());
      unawaited(_loadSpaces());
    } else {
      unawaited(_closeCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.isActive &&
        _mode == CaptureMode.photo) {
      unawaited(_openCamera());
    } else if (state != AppLifecycleState.resumed) {
      unawaited(_closeCamera());
    }
  }

  Future<void> _restoreMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (widget.modeRequestSerial > 0 && widget.requestedMode != null) return;
    final saved = prefs.getString(_modeKey);
    if (!mounted || saved == null) return;
    final next = CaptureMode.values.where((mode) => mode.name == saved);
    if (next.isEmpty) return;
    setState(() => _mode = next.first);
    if (_mode == CaptureMode.photo && widget.isActive) {
      await _openCamera();
    } else {
      await _closeCamera();
    }
  }

  Future<void> _loadSpaces() async {
    try {
      final response = await widget.api.listSpaces();
      final spaces =
          response
              .map((row) => (row['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _spaces = spaces;
        _spaceError = null;
        if (_space == null || !spaces.contains(_space)) {
          _space = spaces.isEmpty ? null : spaces.first;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _spaceError = 'Could not load places.');
    }
  }

  Future<void> _openCamera() async {
    if (_cameraLoading ||
        _camera != null ||
        !widget.isActive ||
        _mode != CaptureMode.photo) {
      return;
    }
    _cameraLoading = true;
    if (mounted) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      final back = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final controller = CameraController(
        back.isEmpty ? cameras.first : back.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted || !widget.isActive || _mode != CaptureMode.photo) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } on CameraException catch (error) {
      if (mounted) {
        setState(
          () => _cameraError = error.code.toLowerCase().contains('denied')
              ? 'Camera access is off. Allow access in Settings or choose a photo.'
              : 'Camera could not start. Choose a photo or try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _cameraError =
              'Camera could not start. Choose a photo or try again.',
        );
      }
    } finally {
      _cameraLoading = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _closeCamera() async {
    final controller = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await controller?.dispose();
  }

  Future<void> _selectMode(CaptureMode mode) async {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _scannerError = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
    if (mode == CaptureMode.photo) {
      await _openCamera();
    } else {
      await _closeCamera();
    }
  }

  Future<void> _chooseSpace() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (_spaces.isEmpty) const ListTile(title: Text('No places yet')),
              for (final space in _spaces)
                ListTile(
                  title: Text(space),
                  onTap: () => Navigator.pop(context, space),
                ),
              ListTile(
                title: const Text('Create a place'),
                onTap: () => Navigator.pop(context, '__create__'),
              ),
              if (_spaceError != null)
                ListTile(
                  title: const Text('Try loading places again'),
                  onTap: () => Navigator.pop(context, '__retry__'),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == '__retry__') {
      await _loadSpaces();
    } else if (selected == '__create__') {
      await _createSpace();
    } else if (selected != null && mounted) {
      setState(() => _space = selected);
    }
  }

  Future<void> _createSpace() async {
    final name = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New place'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Place name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
    if (selected == null || selected.isEmpty) return;
    try {
      await widget.api.createSpace(name: selected);
      await _loadSpaces();
      if (mounted && _spaces.contains(selected)) {
        setState(() => _space = selected);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not create the place. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    final destination = _space;
    if (_capturing || camera == null || destination == null) return;
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      if (!mounted) return;
      await runUploadPhotoFlow(
        context: context,
        api: widget.api,
        preselectedSpace: destination,
        capturedImage: photo,
        barcodeToAssociate: _barcodeForPhoto,
        onItemsSaved: () async => widget.onSaved(),
      );
      _barcodeForPhoto = null;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not take the photo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _choosePhoto() async {
    final destination = _space;
    if (_capturing || destination == null) return;
    final photo = await picker.ImagePicker().pickImage(
      source: picker.ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 92,
    );
    if (photo == null || !mounted) return;
    await runUploadPhotoFlow(
      context: context,
      api: widget.api,
      preselectedSpace: destination,
      capturedImage: photo,
      barcodeToAssociate: _barcodeForPhoto,
      onItemsSaved: () async => widget.onSaved(),
    );
    _barcodeForPhoto = null;
  }

  Future<void> _manualAdd() async {
    await _closeCamera();
    if (!mounted) return;
    final item = await showManualAddPage(
      context,
      api: widget.api,
      initialLocation: _space,
      backLabel: 'Camera',
    );
    if (item != null) widget.onSaved();
    if (mounted && widget.isActive && _mode == CaptureMode.photo) {
      await _openCamera();
    }
  }

  Future<void> _readCode(String code) async {
    if (_answerOpen || code.trim().isEmpty || !mounted) return;
    _answerOpen = true;
    try {
      final trimmed = code.trim();
      if (trimmed.startsWith('findez://space/')) {
        final name = Uri.decodeComponent(
          trimmed.substring('findez://space/'.length),
        );
        if (_spaces.contains(name)) {
          setState(() => _space = name);
          widget.onSpaceScanned?.call(name);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('That place is not in this workspace.'),
            ),
          );
        }
        return;
      }
      final itemCode = trimmed.startsWith('findez://item/')
          ? trimmed.substring('findez://item/'.length)
          : trimmed;
      final itemId = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      if (itemId.hasMatch(itemCode)) {
        try {
          final item = await widget.api.itemDetail(itemCode);
          if (mounted) {
            await showItemDetailSheet(context, item: item, api: widget.api);
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('That object is not in this workspace.'),
              ),
            );
          }
        }
        return;
      }
      await showBarcodeAnswerSheet(
        context,
        api: widget.api,
        barcode: trimmed,
        destination: _space ?? '',
        onSaved: widget.onSaved,
        onPhotograph: () {
          _barcodeForPhoto = trimmed;
          unawaited(_selectMode(CaptureMode.photo));
        },
      );
    } finally {
      _answerOpen = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final camera = _camera;
    _camera = null;
    unawaited(camera?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final camera = _camera;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.showAppBar ? AppBar(title: const Text('Capture')) : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Capture',
                      style: TextStyle(
                        color: t.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _chooseSpace,
                    child: Text(
                      _space ?? (_spaceError ?? 'Choose a place'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: t.s1,
                    child: switch (_mode) {
                      CaptureMode.photo =>
                        camera != null && camera.value.isInitialized
                            ? CameraPreview(camera)
                            : _cameraMessage(t),
                      CaptureMode.scan => _scanView(t),
                      CaptureMode.see => _seeMessage(t),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: CaptureMode.values.map((mode) {
                  final selected = mode == _mode;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: TextButton(
                        onPressed: () => _selectMode(mode),
                        style: TextButton.styleFrom(
                          backgroundColor: selected ? t.accent : t.s2,
                          foregroundColor: selected ? t.onAccent : t.text2,
                        ),
                        child: Text(switch (mode) {
                          CaptureMode.photo => 'Photo',
                          CaptureMode.scan => 'Scan',
                          CaptureMode.see => 'See',
                        }),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: Center(
                child: switch (_mode) {
                  CaptureMode.photo => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _space == null ? null : _choosePhoto,
                        child: const Text('Choose photo'),
                      ),
                      const SizedBox(width: 18),
                      FilledButton(
                        onPressed:
                            _capturing || camera == null || _space == null
                            ? null
                            : _takePhoto,
                        child: Text(_capturing ? 'Capturing' : 'Take photo'),
                      ),
                    ],
                  ),
                  CaptureMode.scan => Text(
                    'Point at a barcode or QR code',
                    style: TextStyle(color: t.text2, fontSize: 14),
                  ),
                  CaptureMode.see => TextButton(
                    onPressed: () => _selectMode(CaptureMode.photo),
                    child: const Text('Use Photo instead'),
                  ),
                },
              ),
            ),
            if (_mode == CaptureMode.photo)
              TextButton(
                onPressed: _manualAdd,
                child: const Text('Add without a photo'),
              ),
            const SizedBox(height: AppTokens.bottomBarClearance + 16),
          ],
        ),
      ),
    );
  }

  Widget _cameraMessage(AppTokens t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cameraError == null) const CircularProgressIndicator(),
          if (_cameraError != null)
            Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text2, fontSize: 15),
            ),
          if (_cameraError != null)
            TextButton(
              onPressed: _openCamera,
              child: const Text('Try camera again'),
            ),
        ],
      ),
    ),
  );

  Widget _seeMessage(AppTokens t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'See is coming',
            style: TextStyle(
              color: t.ink,
              fontSize: 23,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Photo to remember what is in front of you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text2, fontSize: 15),
          ),
        ],
      ),
    ),
  );

  Widget _scanView(AppTokens t) => Stack(
    fit: StackFit.expand,
    children: [
      if (widget.isActive)
        MobileScanner(
          errorBuilder: (context, error) {
            if (!_scannerError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _scannerError = true);
              });
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Scanner cannot use the camera. Check camera access in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.ink, fontSize: 15),
                ),
              ),
            );
          },
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final code = barcode.rawValue;
              if (code != null && code.isNotEmpty) {
                unawaited(_readCode(code));
                break;
              }
            }
          },
        )
      else
        Container(color: t.s1),
      if (!_scannerError)
        Center(
          child: Container(
            width: 255,
            height: 190,
            decoration: BoxDecoration(
              border: Border.all(color: t.accent, width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: t.paper.withValues(alpha: 0.65),
                  spreadRadius: 80,
                  blurRadius: 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 22),
              color: t.accent,
            ),
          ),
        ),
    ],
  );
}
