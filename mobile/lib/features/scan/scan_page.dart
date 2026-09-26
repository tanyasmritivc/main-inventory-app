import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/pro_status.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/upgrade_sheet.dart';
import '../inventory/item_detail_sheet.dart';
import 'bom_readiness_page.dart';
import 'capture_client.dart';
import 'capture_controller.dart';
import 'confirm_scan_sheet.dart';
import 'import_sheet_page.dart';
import 'project_kits_page.dart';
import 'qr_sheet.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.api,
    required this.onSaved,
    this.isActive = false,
    this.onSpaceScanned,
    this.onSkipCoachmark,
    this.showAppBar = true,
    this.controller,
    this.imagePicker,
    this.spacesLoader,
  });

  final ApiClient api;
  final VoidCallback onSaved;
  final bool isActive;
  final void Function(String spaceName)? onSpaceScanned;
  final VoidCallback? onSkipCoachmark;
  final bool showAppBar;
  final CaptureController? controller;
  final ImagePicker? imagePicker;
  final Future<List<Map<String, dynamic>>> Function()? spacesLoader;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

enum _CaptureTool { barcode, spreadsheet, bom, projectKits }

class _ScanPageState extends State<ScanPage> {
  late final CaptureController _capture;
  late final bool _ownsController;
  late final ImagePicker _picker;
  final _destination = TextEditingController();
  List<String> _spaces = const [];
  bool _loadingSpaces = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _capture =
        widget.controller ??
        CaptureController(gateway: CaptureClient(widget.api));
    _picker = widget.imagePicker ?? ImagePicker();
    _capture.addListener(_refresh);
    unawaited(_loadSpaces());
  }

  @override
  void didUpdateWidget(ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive && _capture.isAnalyzing) {
      unawaited(_capture.cancelActive());
    }
  }

  @override
  void dispose() {
    _capture.removeListener(_refresh);
    if (_ownsController) _capture.dispose();
    _destination.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSpaces() async {
    if (_loadingSpaces) return;
    _loadingSpaces = true;
    try {
      final rows =
          await (widget.spacesLoader?.call() ?? widget.api.listSpaces());
      final names =
          rows
              .map((row) => (row['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _spaces = names;
        if (_destination.text.isEmpty && names.length == 1) {
          _destination.text = names.single;
        }
      });
    } catch (error) {
      debugPrint('[capture] Space load failed: $error');
    } finally {
      _loadingSpaces = false;
    }
  }

  Future<ImageSource?> _photoSource() => showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(CupertinoIcons.camera),
            title: const Text('Take a photo'),
            subtitle: const Text('Capture objects in front of you'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(CupertinoIcons.photo),
            title: const Text('Choose a photo'),
            subtitle: const Text('Use an image from your library'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  Future<void> _startPhoto([ImageSource? source, String? barcode]) async {
    final selected = source ?? await _photoSource();
    if (selected == null || !mounted) return;
    try {
      final file = await _picker.pickImage(
        source: selected,
        maxWidth: 2048,
        imageQuality: 92,
      );
      if (file == null || !mounted) return;
      final outcome = await _capture.analyzePhoto(
        bytes: await file.readAsBytes(),
        filename: file.name,
        barcodeToAssociate: barcode,
      );
      if (!mounted) return;
      if (outcome == CaptureRunOutcome.failed &&
          _capture.failureKind == CaptureFailureKind.limit &&
          !ProStatus.isPro) {
        await showUpgradeSheet(
          context,
          widget.api,
          reason: _capture.errorMessage ?? 'Your photo scan limit was reached.',
        );
      }
    } catch (error) {
      if (mounted) _message('The camera or photo library could not be opened.');
    }
  }

  Future<void> _retryPhoto() async {
    final outcome = await _capture.retryPhoto();
    if (!mounted) return;
    if (outcome == CaptureRunOutcome.failed &&
        _capture.failureKind == CaptureFailureKind.limit &&
        !ProStatus.isPro) {
      await showUpgradeSheet(
        context,
        widget.api,
        reason: _capture.errorMessage ?? 'Your photo scan limit was reached.',
      );
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final value = code.trim();
    if (value.startsWith('findez://space/')) {
      widget.onSpaceScanned?.call(
        Uri.decodeComponent(value.substring('findez://space/'.length)),
      );
      return;
    }
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (uuid.hasMatch(value)) {
      final match = InventoryCache.items
          .where((item) => item.itemId == value)
          .firstOrNull;
      if (match == null) {
        _message('That FindEZ item is not in the current inventory.');
      } else {
        await showItemDetailSheet(context, item: match, api: widget.api);
      }
      return;
    }

    final result = await _capture.lookupBarcode(value);
    if (!mounted || result == null) return;
    if (result.foundInInventory && result.existingItem != null) {
      final existing = InventoryItem.fromJson(result.existingItem!);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: AppTokens.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Already remembered',
                  style: TextStyle(color: AppColors.success),
                ),
                const SizedBox(height: 8),
                Text(
                  existing.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('${existing.location}  |  Quantity ${existing.quantity}'),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showItemDetailSheet(
                      context,
                      item: existing,
                      api: widget.api,
                    );
                  },
                  child: const Text('View item'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    final name = (result.name ?? '').trim();
    if (name.isEmpty || name.toLowerCase() == 'unknown item') {
      final usePhoto = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Barcode not recognized'),
          content: const Text(
            'Photograph the product label so FIND can read the item.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Enter manually'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Take photo'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (usePhoto == true) {
        await _startPhoto(null, value);
      } else if (usePhoto == false) {
        _capture.replaceDrafts([
          ExtractedInventoryItem(
            name: '',
            category: 'Other',
            quantity: 1,
            barcode: value,
          ),
        ]);
        await _review();
      }
      return;
    }
    _capture.useBarcodeResult(result, value);
  }

  Future<void> _review() async {
    if (_capture.drafts.isEmpty) return;
    final destination = await _requireDestination();
    if (destination == null || !mounted) return;
    final edited = await showModalBottomSheet<List<ExtractedInventoryItem>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmScanSheet(
        items: _capture.drafts.map((draft) => draft.item).toList(),
        defaultLocation: destination,
      ),
    );
    if (edited != null) _capture.replaceDrafts(edited);
  }

  Future<void> _save() async {
    final destination = await _requireDestination();
    if (destination == null || !mounted) return;
    final edited = await showModalBottomSheet<List<ExtractedInventoryItem>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmScanSheet(
        items: _capture.drafts.map((draft) => draft.item).toList(),
        defaultLocation: destination,
      ),
    );
    if (edited == null || !mounted) return;
    _capture.replaceDrafts(edited);
    final outcome = await _capture.save(destination: destination);
    if (outcome == null || !mounted) return;
    if (outcome.inserted.isNotEmpty) {
      widget.onSaved();
      _message(
        outcome.allSucceeded
            ? 'Remembered ${outcome.inserted.length} ${outcome.inserted.length == 1 ? 'item' : 'items'} in $destination.'
            : 'Remembered ${outcome.inserted.length} of ${outcome.total} results. The rest are still here.',
      );
    }
    if (!outcome.allSucceeded) return;
    final noBarcode = outcome.inserted
        .where((item) => (item.barcode ?? '').trim().isEmpty)
        .toList();
    if (noBarcode.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: noBarcode.length > 1,
        builder: (_) => noBarcode.length == 1
            ? QrOfferSheet(item: noBarcode.single)
            : BulkQrOfferSheet(items: noBarcode),
      );
    });
  }

  Future<String?> _requireDestination() async {
    if (_destination.text.trim().isNotEmpty) return _destination.text.trim();
    await _showSpacePicker();
    final value = _destination.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _showSpacePicker() async {
    await _loadSpaces();
    if (!mounted) return;
    final newSpace = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose a Space',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text('Captured items need a physical home in your memory.'),
            const SizedBox(height: 16),
            if (_spaces.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _spaces
                    .map(
                      (space) => ActionChip(
                        label: Text(space),
                        onPressed: () => Navigator.pop(sheetContext, space),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: newSpace,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'New Space',
                hintText: 'Workshop cabinet',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.pop(sheetContext, value.trim());
                }
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final value = newSpace.text.trim();
                if (value.isNotEmpty) Navigator.pop(sheetContext, value);
              },
              child: const Text('Use this Space'),
            ),
          ],
        ),
      ),
    );
    newSpace.dispose();
    if (selected != null && mounted) {
      setState(() => _destination.text = selected);
    }
  }

  Future<void> _openTool(_CaptureTool tool) async {
    if (tool == _CaptureTool.barcode) return _scanBarcode();
    final destination = await _requireDestination();
    if (destination == null || !mounted) return;
    final Widget page = switch (tool) {
      _CaptureTool.spreadsheet => ImportSheetPage(
        api: widget.api,
        location: destination,
      ),
      _CaptureTool.bom => BomReadinessPage(
        api: widget.api,
        location: destination,
      ),
      _CaptureTool.projectKits => ProjectKitsPage(
        api: widget.api,
        location: destination,
      ),
      _CaptureTool.barcode => throw StateError('handled above'),
    };
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (changed == true) widget.onSaved();
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  String _stageLabel() => switch (_capture.stage) {
    CaptureStage.preparing => 'Preparing your photo',
    CaptureStage.detecting => 'Finding objects',
    CaptureStage.understanding => 'Reading labels and identifying items',
    CaptureStage.saving => 'Saving to your memory',
    null => 'Working',
  };

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Capture'),
              actions: [
                if (_capture.isAnalyzing)
                  TextButton(
                    onPressed: _capture.cancelActive,
                    child: const Text('Stop'),
                  ),
              ],
            )
          : null,
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('capture-page'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Remember this.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Take a photo and FIND will turn what it can see into reviewable inventory.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _PhotoCard(
              busy: _capture.isAnalyzing,
              onCamera: _capture.isAnalyzing
                  ? null
                  : () => _startPhoto(ImageSource.camera),
              onLibrary: _capture.isAnalyzing
                  ? null
                  : () => _startPhoto(ImageSource.gallery),
            ),
            if (_capture.isAnalyzing) ...[
              const SizedBox(height: 14),
              _ProgressCard(
                label: _stageLabel(),
                longWait: _capture.showLongWaitHint,
                reduceMotion: reduceMotion,
                onCancel: _capture.cancelActive,
              ),
            ],
            if (_capture.errorMessage != null) ...[
              const SizedBox(height: 14),
              _ErrorCard(
                message: _capture.errorMessage!,
                canRetry: _capture.canRetryPhoto,
                onRetry: _retryPhoto,
                onDismiss: _capture.clear,
              ),
            ],
            if (_capture.drafts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '${_capture.drafts.length} ${_capture.drafts.length == 1 ? 'result' : 'results'} found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  if (_capture.summary?.partial == true)
                    const Text(
                      'Partial result',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  TextButton(onPressed: _review, child: const Text('Edit all')),
                ],
              ),
              ..._capture.drafts.map(
                (draft) => _ResultCard(
                  key: ValueKey(draft.id),
                  item: draft.item,
                  error: _capture.saveFailures[draft.id],
                  onRemove: () => _capture.removeDraft(draft.id),
                ),
              ),
              _DestinationTile(
                value: _destination.text,
                onTap: _showSpacePicker,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _capture.isSaving ? null : _save,
                  icon: _capture.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.checkmark_alt),
                  label: Text(
                    _capture.isSaving ? 'Saving...' : 'Review and remember',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            Text(
              'Other ways to capture',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _ToolGrid(onSelected: _openTool),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.busy,
    required this.onCamera,
    required this.onLibrary,
  });
  final bool busy;
  final VoidCallback? onCamera;
  final VoidCallback? onLibrary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Semantics(
            image: true,
            label: 'Photo capture for FindEZ object recognition',
            child: const Center(
              child: Icon(
                CupertinoIcons.viewfinder,
                color: AppColors.accent,
                size: 62,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('capture-take-photo'),
            onPressed: onCamera,
            icon: const Icon(CupertinoIcons.camera_fill),
            label: Text(busy ? 'Processing photo...' : 'Take a photo'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: AppTokens.minimumTouchTarget,
          child: OutlinedButton.icon(
            key: const ValueKey('capture-choose-photo'),
            onPressed: onLibrary,
            icon: const Icon(CupertinoIcons.photo),
            label: const Text('Choose from library'),
          ),
        ),
      ],
    ),
  );
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.label,
    required this.longWait,
    required this.reduceMotion,
    required this.onCancel,
  });
  final String label;
  final bool longWait;
  final bool reduceMotion;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
              TextButton(onPressed: onCancel, child: const Text('Stop')),
            ],
          ),
          if (!reduceMotion) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (longWait) ...[
            const SizedBox(height: 10),
            const Text(
              'Complex scenes can take longer while FIND separates and identifies each object.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onDismiss,
  });
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Capture needs attention',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.muted)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
              if (canRetry)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.item,
    required this.error,
    required this.onRemove,
  });
  final ExtractedInventoryItem item;
  final String? error;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final evidence = item.scanEvidence;
    final needsReview =
        evidence?.needsReview == true ||
        (item.confidence != null && item.confidence! < 0.6);
    final details = <String>[
      if ((item.brand ?? '').trim().isNotEmpty) item.brand!.trim(),
      if ((item.partNumber ?? '').trim().isNotEmpty) item.partNumber!.trim(),
      if ((item.barcode ?? '').trim().isNotEmpty) 'Barcode ${item.barcode}',
      if (evidence?.hasDimensions == true)
        '${evidence!.lengthMm!.toStringAsFixed(1)} x ${evidence.widthMm!.toStringAsFixed(1)} mm',
      if ((evidence?.ocrText ?? '').trim().isNotEmpty)
        'Text: ${evidence!.ocrText}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: error == null ? AppColors.border : AppColors.danger,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            needsReview
                ? CupertinoIcons.exclamationmark
                : CupertinoIcons.cube_box,
            color: needsReview ? AppColors.warning : AppColors.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.trim().isEmpty ? 'Needs a name' : item.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${item.category}  |  Quantity ${item.quantity}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join('  |  '),
                    style: const TextStyle(color: AppColors.hint, fontSize: 12),
                  ),
                if (needsReview)
                  const Text(
                    'Check this result before saving',
                    style: TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${item.name}',
            onPressed: onRemove,
            icon: const Icon(CupertinoIcons.xmark),
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: value.isEmpty
        ? 'Choose destination Space'
        : 'Destination Space $value',
    child: ListTile(
      minTileHeight: 52,
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      leading: const Icon(CupertinoIcons.archivebox),
      title: Text(value.isEmpty ? 'Choose a Space' : value),
      subtitle: const Text('Where these objects live'),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
      onTap: onTap,
    ),
  );
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.onSelected});
  final ValueChanged<_CaptureTool> onSelected;

  @override
  Widget build(BuildContext context) {
    const tools = [
      (
        _CaptureTool.barcode,
        CupertinoIcons.barcode_viewfinder,
        'Barcode or QR',
      ),
      (_CaptureTool.spreadsheet, CupertinoIcons.table, 'Spreadsheet'),
      (_CaptureTool.bom, CupertinoIcons.checkmark_seal, 'Check a BOM'),
      (_CaptureTool.projectKits, CupertinoIcons.cube_box, 'Project Kits'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.25,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: tools
          .map(
            (tool) => Semantics(
              button: true,
              label: tool.$3,
              child: OutlinedButton.icon(
                onPressed: () => onSelected(tool.$1),
                icon: Icon(tool.$2),
                label: Text(tool.$3, textAlign: TextAlign.center),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();
  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _returned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Scan barcode or FindEZ QR')),
    body: Semantics(
      label: 'Camera view for scanning a barcode or FindEZ QR code',
      child: MobileScanner(
        controller: _controller,
        errorBuilder: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Camera is unavailable. Return to Capture and choose a photo instead.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        onDetect: (capture) {
          if (_returned || capture.barcodes.isEmpty) return;
          final value = capture.barcodes.first.rawValue?.trim();
          if (value == null || value.isEmpty) return;
          _returned = true;
          Navigator.pop(context, value);
        },
      ),
    ),
  );
}
