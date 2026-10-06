import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import 'item_detail_drag_sheet.dart';
import 'package:mobile/core/ui/app_text.dart';

/// Opens the comprehensive item detail bottom sheet.
///
/// [permission] should be `'edit'` or `'view'`. Write actions (checkout,
/// edit notes, add documents) are hidden for `'view'`.
/// [initialThreshold] is the alert threshold from LowStockPrefs.
/// [spaceName] is passed when checking out an item (used as the space label).
Future<void> showItemDetailSheet(
  BuildContext context, {
  required InventoryItem item,
  required ApiClient api,
  String permission = 'edit',
  String? shareId,
  int? initialThreshold,
  String spaceName = '',
  ValueChanged<int?>? onThresholdChanged,
  ValueChanged<InventoryItem>? onItemUpdated,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: false,
    builder: (_) => _ItemDetailSheet(
      item: item,
      api: api,
      permission: permission,
      shareId: shareId,
      initialThreshold: initialThreshold,
      spaceName: spaceName,
      onThresholdChanged: onThresholdChanged,
      onItemUpdated: onItemUpdated,
    ),
  );
}

class _ItemDetailSheet extends StatefulWidget {
  const _ItemDetailSheet({
    required this.item,
    required this.api,
    required this.permission,
    required this.spaceName,
    this.shareId,
    this.initialThreshold,
    this.onThresholdChanged,
    this.onItemUpdated,
  });

  final InventoryItem item;
  final ApiClient api;
  final String permission;
  final String? shareId;
  final String spaceName;
  final int? initialThreshold;
  final ValueChanged<int?>? onThresholdChanged;
  final ValueChanged<InventoryItem>? onItemUpdated;

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
  late InventoryItem _item;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _purchaseSourceCtrl;
  late final TextEditingController _thresholdCtrl;

  // Checkout dialog controllers are owned by this State (not local to
  // _showCheckoutDialog) because await showDialog() returns the moment
  // Navigator.pop() is called — BEFORE the dialog's exit animation (~150ms)
  // finishes. The dialog's TextFields still hold live cursor-blink listeners
  // on these controllers during that animation window. Disposing them as
  // locals immediately after showDialog caused the "disposed
  // TextEditingController used" assert, which cascaded into every other
  // crash ("wrong build scope", "_dependents.isEmpty", RenderFlex overflow).
  // Owning them here means they are only disposed when the sheet itself is
  // disposed — safely after all child animations have ended.
  late final TextEditingController _checkoutNameCtrl;
  late final TextEditingController _checkoutNotesCtrl;

  final GlobalKey _qrCardKey = GlobalKey();

  bool _isEditingNotes = false;
  bool _notesSaving = false;
  bool _closing = false;
  bool _allowPop = false;
  late String _lastSavedNotes;
  late String _lastSavedPurchaseSource;
  Future<bool>? _purchaseSourceSave;
  Future<bool>? _thresholdSave;
  bool _checkingOut = false;
  bool _purchaseSourceSaveFailed = false;
  bool _photosLoading = true;
  bool _photoSaving = false;
  bool _documentSaving = false;
  bool _returnSaving = false;
  int _selectedPhotoIndex = 0;
  Timer? _thresholdDebounce;
  int? _lastSavedThreshold;
  Timer? _purchaseSourceDebounce;

  List<DocumentEntry> _localDocs = [];
  List<ItemPhoto> _photos = [];

  // Stable future — not recreated on every build; reset explicitly when checkout/return mutates state.
  Future<List<Map<String, dynamic>>>? _checkoutsFuture;
  Future<VerifiedCatalogPart?>? _catalogFuture;
  Future<CatalogCompatibilityResult?>? _compatibilityFuture;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _notesCtrl = TextEditingController(text: widget.item.notes ?? '');
    _lastSavedNotes = _notesCtrl.text.trim();
    _purchaseSourceCtrl = TextEditingController(
      text: widget.item.purchaseSource ?? '',
    );
    _lastSavedPurchaseSource = _purchaseSourceCtrl.text.trim();
    _thresholdCtrl = TextEditingController(
      text: (widget.initialThreshold != null && widget.initialThreshold! > 0)
          ? widget.initialThreshold.toString()
          : '',
    );
    _lastSavedThreshold = _parsedThreshold();
    _checkoutNameCtrl = TextEditingController();
    _checkoutNotesCtrl = TextEditingController();
    _checkoutsFuture = _fetchCheckouts();
    final catalogId = widget.item.catalogId;
    if (catalogId != null && catalogId.isNotEmpty) {
      _catalogFuture = widget.api
          .getVerifiedCatalogPart(catalogId)
          .then<VerifiedCatalogPart?>((part) => part)
          .catchError((_) => null);
      _compatibilityFuture = widget.api
          .getCompatibleCatalogParts(catalogId)
          .then<CatalogCompatibilityResult?>((result) => result)
          .catchError((_) => null);
    }
    _loadDocuments();
    _loadPhotos();
  }

  @override
  void dispose() {
    _thresholdDebounce?.cancel();
    // All user dismissals flush edits before popping. Never start a write
    // from dispose, where failures cannot be shown and accounts may have changed.
    _notesCtrl.dispose();
    _purchaseSourceCtrl.dispose();
    _thresholdCtrl.dispose();
    _checkoutNameCtrl.dispose();
    _checkoutNotesCtrl.dispose();
    _purchaseSourceDebounce?.cancel();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  void _loadDocuments() {
    widget.api
        .getDocuments(itemId: widget.item.itemId)
        .then((docs) {
          if (!mounted) return;
          setState(() => _localDocs = docs);
        })
        .catchError((_) {});
  }

  List<ItemPhoto> _fallbackPhotos() {
    final imageUrl = (_item.imageUrl ?? '').trim();
    if (imageUrl.isEmpty) return const [];
    return [
      ItemPhoto(
        photoId: 'primary',
        imageUrl: imageUrl,
        isPrimary: true,
        createdAt: _item.createdAt,
      ),
    ];
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await widget.api.getItemPhotos(
        itemId: _item.itemId,
        shareId: widget.shareId,
      );
      if (!mounted) return;
      setState(() {
        _photos = photos.isEmpty ? _fallbackPhotos() : photos;
        _photosLoading = false;
        if (_selectedPhotoIndex >= _photos.length) {
          _selectedPhotoIndex = _photos.isEmpty ? 0 : _photos.length - 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _photos = _fallbackPhotos();
        _photosLoading = false;
      });
    }
  }

  Future<void> _addPhoto() async {
    if (_photoSaving || _closing) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const AppText('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const AppText('Choose from Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 88,
    );
    if (photo == null || !mounted || _closing) return;

    setState(() => _photoSaving = true);
    try {
      final result = await widget.api.addItemPhoto(
        itemId: _item.itemId,
        bytes: await photo.readAsBytes(),
        filename: photo.name,
        shareId: widget.shareId,
      );
      if (!mounted) return;
      setState(() {
        _item = result.item;
        _photos = result.photos;
        _selectedPhotoIndex = 0;
      });
      InventoryCache.updateItem(result.item);
      widget.onItemUpdated?.call(result.item);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Photo added')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _photoSaving = false);
    }
  }

  Future<void> _deletePhoto(ItemPhoto photo) async {
    if (_photoSaving || _closing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Delete photo?'),
        content: const AppText('This photo will be removed from the item.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _photoSaving = true);
    try {
      final result = await widget.api.deleteItemPhoto(
        itemId: _item.itemId,
        photoId: photo.photoId,
        shareId: widget.shareId,
      );
      if (!mounted) return;
      setState(() {
        _item = result.item;
        _photos = result.photos;
        if (_selectedPhotoIndex >= _photos.length) {
          _selectedPhotoIndex = _photos.isEmpty ? 0 : _photos.length - 1;
        }
      });
      InventoryCache.updateItem(result.item);
      widget.onItemUpdated?.call(result.item);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Photo deleted')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _photoSaving = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<bool> _saveNotes() async {
    if (_notesSaving || widget.permission != 'edit') return false;
    final notes = _notesCtrl.text.trim();
    setState(() => _notesSaving = true);
    try {
      final updated = await widget.api.updateItem(
        request: UpdateItemRequest(itemId: widget.item.itemId, notes: notes),
      );
      if (!mounted) return false;
      setState(() {
        _isEditingNotes = false;
        _lastSavedNotes = notes;
        _item = updated;
      });
      InventoryCache.updateItem(updated);
      widget.onItemUpdated?.call(updated);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Could not save notes. Try again.')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _notesSaving = false);
    }
  }

  void _scheduleThresholdSave() {
    _thresholdDebounce?.cancel();
    _thresholdDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_saveThresholdNow());
    });
  }

  int? _parsedThreshold() {
    final raw = int.tryParse(_thresholdCtrl.text.trim());
    return (raw != null && raw >= 0) ? raw : null;
  }

  Future<bool> _saveThresholdNow() {
    _thresholdDebounce?.cancel();
    if (widget.permission != 'edit') return Future.value(true);
    return _thresholdSave ??= _flushThreshold().whenComplete(() {
      _thresholdSave = null;
    });
  }

  Future<bool> _flushThreshold() async {
    while (mounted) {
      final threshold = _parsedThreshold();
      if (threshold == _lastSavedThreshold) return true;
      if (!await _saveThresholdValue(threshold)) return false;
    }
    return false;
  }

  Future<bool> _saveThresholdValue(int? threshold) async {
    try {
      await LowStockPrefs.setThreshold(
        itemId: widget.item.itemId,
        threshold: threshold,
      );
      _lastSavedThreshold = threshold;
      widget.onThresholdChanged?.call(threshold);
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Could not save the low-stock threshold.'),
        ),
      );
      return false;
    }
  }

  void _schedulePurchaseSourceSave() {
    _purchaseSourceDebounce?.cancel();
    _purchaseSourceDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_savePurchaseSourceNow());
    });
  }

  Future<bool> _savePurchaseSourceNow() {
    _purchaseSourceDebounce?.cancel();
    if (widget.permission != 'edit') return Future.value(true);
    return _purchaseSourceSave ??= _flushPurchaseSource().whenComplete(() {
      _purchaseSourceSave = null;
    });
  }

  Future<bool> _flushPurchaseSource() async {
    while (mounted) {
      final source = _purchaseSourceCtrl.text.trim();
      if (source == _lastSavedPurchaseSource) return true;
      if (!await _persistPurchaseSource(source)) return false;
    }
    return false;
  }

  Future<bool> _persistPurchaseSource(String source) async {
    try {
      final updated = await widget.api.updateItem(
        request: UpdateItemRequest(
          itemId: widget.item.itemId,
          purchaseSource: source,
        ),
      );
      _lastSavedPurchaseSource = source;
      if (mounted) {
        setState(() {
          _purchaseSourceSaveFailed = false;
          _item = updated;
        });
        InventoryCache.updateItem(updated);
        widget.onItemUpdated?.call(updated);
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _purchaseSourceSaveFailed = true);
      return false;
    }
  }

  Future<bool> _requestClose() async {
    if (_closing || ModalRoute.of(context)?.isCurrent != true) return false;
    if (_notesSaving ||
        _photoSaving ||
        _checkingOut ||
        _documentSaving ||
        _returnSaving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Please wait for the current save to finish.'),
        ),
      );
      return false;
    }
    setState(() => _closing = true);
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      if (widget.permission == 'edit') {
        if (_notesCtrl.text.trim() != _lastSavedNotes) {
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const AppText('Save your notes?'),
              content: const AppText('Your notes have unsaved changes.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const AppText('Keep editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'discard'),
                  child: const AppText('Discard'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  child: const AppText('Save and close'),
                ),
              ],
            ),
          );
          if (!mounted || choice == null) return false;
          if (choice == 'save' && !await _saveNotes()) return false;
          if (choice == 'discard') {
            _notesCtrl.text = _lastSavedNotes;
            setState(() => _isEditingNotes = false);
          }
        }
        if (!await _savePurchaseSourceNow()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: AppText(
                  'Could not save the purchase source. Try again before closing.',
                ),
              ),
            );
          }
          return false;
        }
        if (!await _saveThresholdNow()) return false;
      }
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return true;
    } finally {
      if (mounted && !_allowPop) setState(() => _closing = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCheckouts() => widget.api
      .getItemCheckouts(itemId: widget.item.itemId)
      .catchError((_) => <Map<String, dynamic>>[]);

  Future<void> _showCheckoutDialog() async {
    if (_checkingOut || _closing) return;
    setState(() => _checkingOut = true);
    debugPrint('[CheckOut] dialog opening for item=${widget.item.itemId}');

    // Re-use the state-owned controllers (cleared here so each dialog open
    // starts blank). Do NOT create local controllers: await showDialog()
    // returns the moment Navigator.pop() is called — before the exit animation
    // (~150ms) finishes — so any locally-created controller disposed right
    // after showDialog still has live cursor-blink listeners from the dialog's
    // TextFields, causing "disposed TextEditingController used" → crash cascade.
    _checkoutNameCtrl.clear();
    _checkoutNotesCtrl.clear();
    DateTime? dueBack;
    var dlgQty = 1;
    // Prevents duplicate API calls if the user double-taps "Check Out"
    // inside the dialog before the first request completes.
    var dlgSubmitting = false;

    // Closure vars written inside the dialog callback; read after showDialog
    // returns. All parent-side effects (setState, snackbar) are deferred
    // until AFTER showDialog resolves so they never fire while the dialog's
    // exit animation is still running. Interleaving a parent setState with an
    // ongoing dialog teardown causes "wrong build scope" / "_dependents not
    // empty" assertion crashes because the dialog's InheritedWidget
    // subscriptions are still live during the animation.
    String? successCheckedOutBy;
    String? failureMessage;

    // Pre-capture ScaffoldMessenger before any async gap so context lookups
    // don't happen across awaits or while the dialog is mid-dismissal.
    final messenger = ScaffoldMessenger.of(context);

    debugPrint('[CheckOut] showing dialog');
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface2(ctx),
          title: AppText(
            'Check Out ${widget.item.name}',
            style: TextStyle(
              color: AppTheme.foreground(ctx, Colors.white),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _checkoutNameCtrl,
                textInputAction: TextInputAction.next,
                style: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
                ),
                decoration: InputDecoration(
                  hintText: 'Who is taking this?',
                  hintStyle: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(ctx, Color(0x4DFFFFFF)),
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.adaptive(ctx, Color(0x14FFFFFF)),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.adaptive(ctx, Colors.white38),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _checkoutNotesCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
                ),
                decoration: InputDecoration(
                  hintText: 'Notes (optional)',
                  hintStyle: AppTypography.bodyStyleOf(
                    context,
                    TextStyle(
                      color: AppTheme.foreground(ctx, Color(0x4DFFFFFF)),
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.adaptive(ctx, Color(0x14FFFFFF)),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.adaptive(ctx, Colors.white38),
                    ),
                  ),
                ),
              ),
              if (widget.item.quantity > 1) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      'How many?',
                      style: TextStyle(
                        color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: dlgQty > 1
                              ? () => setDlgState(() => dlgQty--)
                              : null,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.adaptive(
                                ctx,
                                const Color(0xFF171717),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.adaptive(
                                  ctx,
                                  const Color(0x14FFFFFF),
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: dlgQty > 1
                                  ? AppTheme.foreground(ctx, Colors.white)
                                  : AppTheme.foreground(
                                      ctx,
                                      const Color(0x33FFFFFF),
                                    ),
                              size: 16,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: AppText(
                            '$dlgQty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.foreground(ctx, Colors.white),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: dlgQty < widget.item.quantity
                              ? () => setDlgState(() => dlgQty++)
                              : null,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.adaptive(
                                ctx,
                                const Color(0xFF171717),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.adaptive(
                                  ctx,
                                  const Color(0x14FFFFFF),
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: dlgQty < widget.item.quantity
                                  ? AppTheme.foreground(ctx, Colors.white)
                                  : AppTheme.foreground(
                                      ctx,
                                      const Color(0x33FFFFFF),
                                    ),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark(),
                      child: AppTypography(child: child!),
                    ),
                  );
                  if (picked != null) {
                    setDlgState(() => dueBack = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(ctx, const Color(0xFF171717)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.adaptive(ctx, const Color(0x14FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      AppText(
                        dueBack == null
                            ? 'Set due date (optional)'
                            : 'Due: ${dueBack!.day}/${dueBack!.month}/${dueBack!.year}',
                        style: TextStyle(
                          color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('[CheckOut] dialog cancelled');
                Navigator.of(ctx).pop();
              },
              child: AppText(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
                ),
              ),
            ),
            TextButton(
              onPressed: dlgSubmitting
                  ? null
                  : () async {
                      if (_checkoutNameCtrl.text.trim().isEmpty) return;
                      setDlgState(() => dlgSubmitting = true);
                      final name = _checkoutNameCtrl.text.trim();
                      debugPrint(
                        '[CheckOut] API call starting for item=${widget.item.itemId}',
                      );
                      try {
                        await widget.api.checkoutItem(
                          itemId: widget.item.itemId,
                          checkedOutBy: name,
                          spaceName: widget.spaceName,
                          dueBackAt: dueBack?.toIso8601String(),
                          notes: _checkoutNotesCtrl.text.trim().isEmpty
                              ? null
                              : _checkoutNotesCtrl.text.trim(),
                          checkoutQuantity: widget.item.quantity > 1
                              ? dlgQty
                              : null,
                        );
                        debugPrint('[CheckOut] API call succeeded');
                        // Store result for post-dialog processing. Do NOT setState
                        // on the parent here — that would trigger a parent rebuild
                        // while the dialog is still in its exit animation, which
                        // corrupts InheritedWidget dependency tracking and causes
                        // "wrong build scope" / "disposed controller used" crashes.
                        successCheckedOutBy = name;
                        debugPrint('[CheckOut] closing dialog');
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e, stack) {
                        debugPrint('[CheckOut] API call failed: $e');
                        debugPrint('[CheckOut] Stack: $stack');
                        failureMessage = 'Failed to check out. Try again.';
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }
                    },
              child: dlgSubmitting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppTheme.adaptive(ctx, Colors.white),
                      ),
                    )
                  : AppText(
                      'Check Out',
                      style: TextStyle(
                        color: AppTheme.foreground(ctx, Colors.white),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    // showDialog() returns the moment Navigator.pop() is called, which is
    // BEFORE the dialog's exit animation (~150ms) finishes. Controllers are
    // NOT disposed here — they are state-owned and disposed in dispose().
    // setState and the snackbar are deferred until this point (after pop) to
    // ensure they don't interleave with any dialog internals while it's still
    // mid-submission, but the dialog's TextFields may still be animating out.
    debugPrint(
      '[CheckOut] dialog popped (exit animation may still be running)',
    );

    if (!mounted) return;

    if (successCheckedOutBy != null) {
      debugPrint('[CheckOut] refreshing checkouts');
      // Single setState to apply both _checkingOut reset and future refresh
      // atomically — one rebuild instead of two.
      setState(() {
        _checkingOut = false;
        _checkoutsFuture = _fetchCheckouts();
      });
      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            '${widget.item.name} checked out to $successCheckedOutBy',
          ),
        ),
      );
    } else {
      setState(() => _checkingOut = false);
      if (failureMessage != null) {
        messenger.showSnackBar(SnackBar(content: AppText(failureMessage!)));
      }
    }
  }

  Future<void> _showStoreLinks() async {
    final itemName = Uri.encodeComponent(widget.item.name);
    final links = [
      {
        'name': 'Amazon',
        'url': 'https://www.amazon.com/s?k=$itemName',
        'icon': Icons.shopping_bag_outlined,
      },
      {
        'name': 'Google Shopping',
        'url': 'https://www.google.com/search?tbm=shop&q=$itemName',
        'icon': Icons.search,
      },
      {
        'name': 'eBay',
        'url': 'https://www.ebay.com/sch/i.html?_nkw=$itemName',
        'icon': Icons.store_outlined,
      },
      {
        'name': 'Walmart',
        'url': 'https://www.walmart.com/search?q=$itemName',
        'icon': Icons.local_grocery_store_outlined,
      },
      {
        'name': 'Target',
        'url': 'https://www.target.com/s?searchTerm=$itemName',
        'icon': Icons.shopping_cart_outlined,
      },
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: AppText(
                'Where to buy "${widget.item.name}"',
                style: TextStyle(
                  color: AppTheme.foreground(ctx, Colors.white),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: AppText(
                'Tap to open in browser',
                style: TextStyle(
                  color: AppTheme.foreground(ctx, Color(0x73FFFFFF)),
                  fontSize: 12,
                ),
              ),
            ),
            ...links.map(
              (link) => ListTile(
                leading: Icon(
                  link['icon'] as IconData,
                  color: AppTheme.foreground(ctx, Colors.white70),
                  size: 20,
                ),
                title: AppText(
                  link['name'] as String,
                  style: TextStyle(
                    color: AppTheme.foreground(ctx, Colors.white),
                    fontSize: 15,
                  ),
                ),
                trailing: Icon(
                  Icons.open_in_new,
                  color: AppTheme.foreground(ctx, Color(0x4DFFFFFF)),
                  size: 16,
                ),
                onTap: () async {
                  final uri = Uri.parse(link['url'] as String);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadDocument() async {
    if (_documentSaving || _closing) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface2(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: AppTheme.foreground(ctx, Colors.white),
              ),
              title: AppText(
                'Choose Photo',
                style: TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
              ),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: Icon(
                Icons.picture_as_pdf_outlined,
                color: AppTheme.foreground(ctx, Colors.white),
              ),
              title: AppText(
                'Choose PDF',
                style: TextStyle(color: AppTheme.foreground(ctx, Colors.white)),
              ),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    String? filename;

    if (choice == 'photo') {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x == null) return;
      bytes = await x.readAsBytes();
      filename = x.name;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.bytes == null) return;
      bytes = picked.bytes!.toList();
      filename = picked.name;
    }

    if (!mounted || _closing) return;
    setState(() => _documentSaving = true);
    try {
      final file = dio.MultipartFile.fromBytes(bytes, filename: filename);
      await widget.api.uploadDocument(file: file, itemId: widget.item.itemId);
      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: AppText('Document uploaded')));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Upload failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _documentSaving = false);
    }
  }

  Future<void> _returnCheckout(String checkoutId) async {
    if (_returnSaving || _closing) return;
    setState(() => _returnSaving = true);
    try {
      await widget.api.returnItem(checkoutId: checkoutId);
      if (mounted) setState(() => _checkoutsFuture = _fetchCheckouts());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText('Could not return the item. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _returnSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 24;
    final labelText = AppText(
      label,
      style: TextStyle(
        color: AppTheme.foreground(context, const Color(0x73FFFFFF)),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
    final valueText = AppText(
      value,
      style: TextStyle(
        color: AppTheme.foreground(context, Colors.white),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      textAlign: largeText ? TextAlign.left : TextAlign.right,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, const SizedBox(height: 8), valueText],
            )
          : Row(
              children: [
                Expanded(child: labelText),
                const SizedBox(width: 16),
                Expanded(child: valueText),
              ],
            ),
    );
  }

  List<String> _catalogValues(Map<String, dynamic> metadata) {
    final values = <String>[];
    for (final value in metadata.values) {
      if (value is List) {
        values.addAll(value.map((entry) => entry.toString()));
      } else if (value != null && value.toString().trim().isNotEmpty) {
        values.add(value.toString());
      }
    }
    return values;
  }

  Widget _verifiedCatalogCard(VerifiedCatalogPart part) {
    final specs = _catalogValues(part.specifications);
    final compatibility = _catalogValues(part.compatibility);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, const Color(0x1230D158)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.adaptive(context, const Color(0x4430D158)),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppTheme.foreground(context, Color(0xFF30D158)),
                  size: 17,
                ),
                SizedBox(width: 7),
                AppText(
                  'Manufacturer verified',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0xFF30D158)),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (part.description?.isNotEmpty == true) ...[
              const SizedBox(height: 9),
              AppText(
                part.description!,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0xB3FFFFFF)),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (specs.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText(
                specs.join(' • '),
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x99FFFFFF)),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (compatibility.isNotEmpty) ...[
              const SizedBox(height: 10),
              AppText(
                'VERIFIED COMPATIBILITY',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x8030D158)),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                compatibility.join(' • '),
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0xCC30D158)),
                  fontSize: 12,
                ),
              ),
            ],
            if (part.productUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.tryParse(part.productUrl!);
                  if (uri == null ||
                      !await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: AppText(
                          'Could not open the manufacturer page.',
                        ),
                      ),
                    );
                  }
                },
                child: AppText(
                  'View manufacturer source ↗',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0xFF30D158)),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compatibilityCard(CatalogCompatibilityResult result) {
    if (result.interfaces.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.adaptive(context, const Color(0x126997DD)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.adaptive(context, const Color(0x446997DD)),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'MATCHING INTERFACES',
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0xFF64D2FF)),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              result.interfaces.join(' • '),
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0xCC64D2FF)),
                fontSize: 13,
              ),
            ),
            if (result.matches.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...result.matches
                  .take(6)
                  .map(
                    (match) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: match.productUrl == null
                            ? null
                            : () async {
                                final uri = Uri.tryParse(match.productUrl!);
                                if (uri == null ||
                                    !await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    )) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: AppText(
                                        'Could not open the manufacturer page.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    match.name,
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Colors.white,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  AppText(
                                    '${match.brand} • ${match.partNumber}',
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0x80FFFFFF),
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (match.productUrl != null)
                              Icon(
                                Icons.open_in_new,
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x8064D2FF),
                                ),
                                size: 15,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              AppText(
                'Matches share an exact interface published in manufacturer product data. Confirm fit for your application.',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x66FFFFFF)),
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
    height: 0.5,
    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
    margin: const EdgeInsets.symmetric(horizontal: 18),
  );

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _photoGallery({required bool canEdit}) {
    if (_photosLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: canEdit && !_photoSaving ? _addPhoto : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0xFF171717)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x1FFFFFFF)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppTheme.foreground(context, Color(0x66FFFFFF)),
                  size: 34,
                ),
                const SizedBox(height: 8),
                AppText(
                  canEdit ? 'Add an item photo' : 'No photos yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x99FFFFFF)),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(height: 4),
                  AppText(
                    'Take a photo or choose one from your library',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x55FFFFFF)),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: PageView.builder(
              key: ValueKey(
                '${_photos.length}:${_photos.map((photo) => photo.photoId).join(',')}',
              ),
              itemCount: _photos.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _selectedPhotoIndex = index);
              },
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0xFF171717),
                          ),
                        ),
                        Image.network(
                          photo.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                          errorBuilder: (_, _, _) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x66FFFFFF),
                                  ),
                                  size: 32,
                                ),
                                SizedBox(height: 6),
                                AppText(
                                  'Photo unavailable',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0x66FFFFFF),
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (canEdit)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppTheme.adaptive(
                                  context,
                                  Color(0xB3000000),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Delete photo',
                                onPressed: _photoSaving
                                    ? null
                                    : () => _deletePhoto(photo),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.foreground(
                                    context,
                                    Colors.white,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        if (_photoSaving)
                          ColoredBox(
                            color: AppTheme.adaptive(
                              context,
                              Color(0x66000000),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppText(
                '${_selectedPhotoIndex + 1} of ${_photos.length}',
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (canEdit)
                TextButton.icon(
                  onPressed: _photoSaving ? null : _addPhoto,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: AppText(
                    _photos.length == 1 ? 'Add another' : 'Add photo',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareQrAsImage() async {
    try {
      final boundary =
          _qrCardKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final item = widget.item;
      final safeName = item.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim()
          .replaceAll(' ', '_');
      final file = File('${dir.path}/findez_qr_$safeName.png');
      await file.writeAsBytes(pngBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'FindEZ item: ${item.name}',
        ),
      );
    } catch (e) {
      debugPrint('[QRShare] Failed to share QR image: $e');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestClose());
      },
      child: ItemDetailDragSheet(
        onDismiss: _requestClose,
        builder: (context, scrollController) =>
            _buildContent(context, scrollController),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
  ) {
    final item = _item;
    final canEdit = widget.permission == 'edit';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.adaptive(context, Color(0xFF0A0A0A)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.adaptive(context, Color(0x14FFFFFF)),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        key: const ValueKey('item-detail-scroll'),
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Semantics(
              label: 'Dismiss item details',
              onDismiss: () => unawaited(_requestClose()),
              child: Center(
                child: Container(
                  key: const ValueKey('item-detail-drag-handle'),
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppText(
                item.displayName,
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AppText(
                item.displayDescription ?? item.category,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _photoGallery(canEdit: canEdit),
            const SizedBox(height: 18),

            // ── Info rows ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0xFF171717)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.adaptive(context, const Color(0x14FFFFFF)),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    _infoRow('Category', item.category),
                    _divider(),
                    _infoRow('Location', item.location),
                    _divider(),
                    _infoRow('Quantity', '${item.quantity}'),
                    if (item.brand != null && item.brand!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Brand', item.brand!),
                    ],
                    if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Barcode', item.barcode!),
                    ],
                    if (item.displayDescription != null) ...[
                      _divider(),
                      _infoRow('Description', item.displayDescription!),
                    ],
                    if (item.subcategory != null &&
                        item.subcategory!.isNotEmpty) ...[
                      _divider(),
                      _infoRow('Subcategory', item.subcategory!),
                    ],
                    _divider(),
                    _infoRow('Date added', _formatDate(item.createdAt)),
                    if (item.confidence != null) ...[
                      _divider(),
                      _infoRow(
                        'AI confidence',
                        '${(item.confidence! * 100).toStringAsFixed(0)}%',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_catalogFuture != null)
              FutureBuilder<VerifiedCatalogPart?>(
                future: _catalogFuture,
                builder: (context, snapshot) {
                  final part = snapshot.data;
                  return part == null
                      ? const SizedBox.shrink()
                      : _verifiedCatalogCard(part);
                },
              ),
            if (_compatibilityFuture != null)
              FutureBuilder<CatalogCompatibilityResult?>(
                future: _compatibilityFuture,
                builder: (context, snapshot) {
                  final result = snapshot.data;
                  return result == null
                      ? const SizedBox.shrink()
                      : _compatibilityCard(result);
                },
              ),

            // ── Check Out ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          'CHECK OUT',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x4DFFFFFF),
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canEdit)
                        GestureDetector(
                          onTap: _checkingOut ? null : _showCheckoutDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.adaptive(
                                context,
                                const Color(0xFF171717),
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: AppTheme.adaptive(
                                  context,
                                  const Color(0x14FFFFFF),
                                ),
                              ),
                            ),
                            child: AppText(
                              'Check Out',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x73FFFFFF),
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _checkoutsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: AppText(
                            "Couldn't load checkout status",
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Colors.white.withValues(alpha: 0.35),
                              ),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }
                      final active = (snapshot.data ?? [])
                          .where((c) => c['is_active'] == true)
                          .toList();
                      if (active.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.adaptive(
                              context,
                              const Color(0x0A30D158),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.adaptive(
                                context,
                                const Color(0x1A30D158),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: AppTheme.foreground(
                                  context,
                                  Color(0xFF30D158),
                                ),
                                size: 14,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: AppText(
                                  'Available - not checked out',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0xFF30D158),
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final checkout = active.first;
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x0AFBBF24),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.adaptive(
                              context,
                              const Color(0x33FBBF24),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: AppTheme.foreground(
                                context,
                                Color(0xFFFBBF24),
                              ),
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppText(
                                'Checked out by ${checkout['checked_out_by']}',
                                style: TextStyle(
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0xFFFBBF24),
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (canEdit)
                              GestureDetector(
                                onTap: () => _returnCheckout(
                                  checkout['checkout_id'] as String,
                                ),
                                child: AppText(
                                  'Return',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Notes ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      AppText(
                        'NOTES',
                        style: TextStyle(
                          color: AppTheme.foreground(
                            context,
                            Color(0x4DFFFFFF),
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      if (canEdit)
                        _isEditingNotes
                            ? GestureDetector(
                                onTap: _notesSaving || _closing
                                    ? null
                                    : _saveNotes,
                                child: AppText(
                                  'Save',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: () =>
                                    setState(() => _isEditingNotes = true),
                                child: AppText(
                                  'Edit',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0x73FFFFFF),
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 80),
                    decoration: BoxDecoration(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0xFF171717),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0x14FFFFFF),
                        ),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: _isEditingNotes
                        ? TextField(
                            key: const ValueKey('item-detail-notes'),
                            readOnly: _notesSaving || _closing,
                            controller: _notesCtrl,
                            maxLines: null,
                            autofocus: true,
                            style: AppTypography.bodyStyleOf(
                              context,
                              TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Colors.white,
                                ),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Add notes about this item...',
                              hintStyle: AppTypography.bodyStyleOf(
                                context,
                                TextStyle(
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x33FFFFFF),
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : AppText(
                            _notesCtrl.text.isNotEmpty
                                ? _notesCtrl.text
                                : 'Tap Edit to add notes...',
                            style: TextStyle(
                              color: _notesCtrl.text.isNotEmpty
                                  ? AppTheme.foreground(
                                      context,
                                      const Color(0x73FFFFFF),
                                    )
                                  : AppTheme.foreground(
                                      context,
                                      const Color(0x33FFFFFF),
                                    ),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // ── Documents ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          'DOCUMENTS',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x4DFFFFFF),
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canEdit)
                        GestureDetector(
                          onTap: _pickAndUploadDocument,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.adaptive(
                                context,
                                const Color(0xFF171717),
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: AppTheme.adaptive(
                                  context,
                                  const Color(0x14FFFFFF),
                                ),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x73FFFFFF),
                                  ),
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                AppText(
                                  'Add',
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Color(0x73FFFFFF),
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_localDocs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: AppTheme.foreground(
                              context,
                              Color(0x20FFFFFF),
                            ),
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          AppText(
                            'No documents yet',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Color(0x33FFFFFF),
                              ),
                              fontSize: 13,
                            ),
                          ),
                          AppText(
                            'Add receipts, manuals, or warranties',
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Color(0x20FFFFFF),
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: _localDocs.asMap().entries.map((entry) {
                          final doc = entry.value;
                          final isLast = entry.key == _localDocs.length - 1;
                          return Column(
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Icon(
                                  (doc.mimeType?.contains('pdf') == true)
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  color: AppTheme.foreground(
                                    context,
                                    const Color(0x73FFFFFF),
                                  ),
                                  size: 20,
                                ),
                                title: AppText(
                                  doc.displayName ?? doc.filename,
                                  style: TextStyle(
                                    color: AppTheme.foreground(
                                      context,
                                      Colors.white,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x33FFFFFF),
                                  ),
                                  size: 12,
                                ),
                                onTap: () {
                                  if (doc.url != null) {
                                    launchUrl(Uri.parse(doc.url!));
                                  }
                                },
                              ),
                              if (!isLast)
                                Container(
                                  height: 0.5,
                                  color: AppTheme.adaptive(
                                    context,
                                    const Color(0x14FFFFFF),
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // ── Tags ──────────────────────────────────────────────────
            // Note: GET /sharing/{shareId}/inventory may omit `tags` —
            // if the field is absent the section simply won't render.
            if (item.tags != null && item.tags!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AppText(
                  'TAGS',
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.tags!
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.adaptive(
                              context,
                              const Color(0xFF171717),
                            ),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: AppTheme.adaptive(
                                context,
                                const Color(0x14FFFFFF),
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: AppText(
                            tag,
                            style: TextStyle(
                              color: AppTheme.foreground(
                                context,
                                Color(0x73FFFFFF),
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            // ── Where to Buy ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppText(
                          'WHERE TO BUY',
                          style: TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x4DFFFFFF),
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          onTap: _showStoreLinks,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.adaptive(
                                context,
                                const Color(0xFF171717),
                              ),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: AppTheme.adaptive(
                                  context,
                                  const Color(0x14FFFFFF),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 11,
                                  color: AppTheme.foreground(
                                    context,
                                    Color(0x73FFFFFF),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: AppText(
                                    'Find stores',
                                    style: TextStyle(
                                      color: AppTheme.foreground(
                                        context,
                                        Color(0x73FFFFFF),
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0xFF171717),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0x14FFFFFF),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: TextField(
                      key: const ValueKey('item-detail-purchase-source'),
                      controller: _purchaseSourceCtrl,
                      readOnly: !canEdit || _closing,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) async {
                        if (canEdit) await _savePurchaseSourceNow();
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      style: AppTypography.bodyStyleOf(
                        context,
                        TextStyle(
                          color: AppTheme.foreground(context, Colors.white),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Where to buy this item...',
                        hintStyle: AppTypography.bodyStyleOf(
                          context,
                          TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x33FFFFFF),
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      onChanged: canEdit
                          ? (_) => _schedulePurchaseSourceSave()
                          : null,
                    ),
                  ),
                  if (_purchaseSourceSaveFailed)
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 13,
                            color: AppTheme.foreground(
                              context,
                              Color(0xFFFF9F0A),
                            ),
                          ),
                          SizedBox(width: 5),
                          AppText(
                            'Not saved',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.foreground(
                                context,
                                Color(0xFFFF9F0A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── Item QR Code ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  AppText(
                    'ITEM QR CODE',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RepaintBoundary(
                    key: _qrCardKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          QrImageView(
                            data: item.itemId,
                            size: 80,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  item.displayName,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                AppText(
                                  item.displayDescription ?? item.location,
                                  style: TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  'Qty: ${item.quantity}',
                                  style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AppText(
                                  'FindEZ AI',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                AppText(
                                  'findez.ai',
                                  style: TextStyle(
                                    color: Color(0xFF888888),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppText(
                    'Scan this code to quickly find this item in FindEZ',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _shareQrAsImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0xFF171717),
                        ),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: AppTheme.adaptive(
                            context,
                            const Color(0x14FFFFFF),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 12,
                            color: AppTheme.foreground(
                              context,
                              Color(0x73FFFFFF),
                            ),
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: AppText(
                              'Share item',
                              style: TextStyle(
                                color: AppTheme.foreground(
                                  context,
                                  Color(0x73FFFFFF),
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Alert threshold ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  AppText(
                    'ALERT ME AT OR BELOW',
                    style: TextStyle(
                      color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0xFF171717),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.adaptive(
                          context,
                          const Color(0x14FFFFFF),
                        ),
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: TextField(
                      key: const ValueKey('item-detail-threshold'),
                      controller: _thresholdCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      readOnly: !canEdit || _closing,
                      style: AppTypography.bodyStyleOf(
                        context,
                        TextStyle(
                          color: AppTheme.foreground(context, Colors.white),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Quantity threshold',
                        hintStyle: AppTypography.bodyStyleOf(
                          context,
                          TextStyle(
                            color: AppTheme.foreground(
                              context,
                              Color(0x33FFFFFF),
                            ),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      onChanged: canEdit
                          ? (_) => _scheduleThresholdSave()
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Close ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => unawaited(_requestClose()),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.adaptive(context, const Color(0xFF171717)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.adaptive(
                        context,
                        const Color(0x14FFFFFF),
                      ),
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: AppText(
                      'Close',
                      style: TextStyle(
                        color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
