import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
import '../../core/ui/skeleton.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.api, required this.onSaved});

  final ApiClient api;
  final VoidCallback onSaved;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _picker = ImagePicker();

  bool _loading = false;
  bool _saving = false;
  String? _error;

  final _defaultLocation = TextEditingController(text: 'Unsorted');
  Map<int, String> _saveFailures = const {};

  List<ExtractedInventoryItem> _items = const [];

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      final t = error.type;
      if (t == dio.DioExceptionType.connectionTimeout ||
          t == dio.DioExceptionType.sendTimeout ||
          t == dio.DioExceptionType.receiveTimeout) {
        return 'That took longer than expected. Try again.';
      }
    }
    return 'That didn’t work. Try again.';
  }

  Future<void> _pick(ImageSource src) async {
    setState(() {
      _loading = true;
      _saving = false;
      _error = null;
      _items = const [];
      _saveFailures = const {};
    });

    try {
      final x = await _picker.pickImage(source: src, maxWidth: 2048, imageQuality: 92);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      final mf = dio.MultipartFile.fromBytes(
        bytes,
        filename: x.name,
      );

      final res = await widget.api.extractInventoryFromImage(file: mf);
      if (!mounted) return;
      setState(() {
        _items = res.items;
      });
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        setState(() => _error = 'That was too many requests. Try again soon.');
      } else {
        setState(() => _error = _friendlyRequestError(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRequestError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() {
      _saving = true;
      _error = null;
      _saveFailures = const {};
    });

    try {
      final fallbackLocation = _defaultLocation.text.trim().isEmpty ? 'Unsorted' : _defaultLocation.text.trim();
      final normalized = <ExtractedInventoryItem>[];
      final indexMap = <int>[];

      final failures = <int, String>{};
      for (var i = 0; i < _items.length; i++) {
        final it = _items[i];
        final name = it.name.trim();
        final category = it.category.trim();
        final location = (it.location ?? '').trim();

        if (name.isEmpty || category.isEmpty) {
          failures[i] = 'Name and category are required.';
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
        indexMap.add(i);
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

      final backendFailures = <int, String>{};
      for (final f in res.failures) {
        final idx = (f['index'] is num) ? (f['index'] as num).toInt() : int.tryParse((f['index'] ?? '').toString());
        if (idx == null) continue;
        final originalIdx = (idx >= 0 && idx < indexMap.length) ? indexMap[idx] : idx;
        backendFailures[originalIdx] = (f['reason'] ?? 'Couldn’t save this item.').toString();
      }

      if (backendFailures.isNotEmpty || failures.isNotEmpty) {
        final merged = <int, String>{...failures, ...backendFailures};
        setState(() => _saveFailures = merged);
      }

      final inserted = res.inserted.length;
      final failed = (backendFailures.length + failures.length);
      if (inserted > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failed > 0 ? 'Saved $inserted items. $failed need attention.' : 'Saved to inventory'),
          ),
        );
        widget.onSaved();
      } else {
        setState(() => _error = 'Couldn’t save those items. Fix the highlighted rows and try again.');
      }
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        setState(() => _error = 'That was too many requests. Try again soon.');
      } else {
        setState(() => _error = _friendlyRequestError(e));
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Scan'),
        centerTitle: true,
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _saveAll,
              label: Text(_saving ? 'Saving…' : 'Save All'),
              icon: const Icon(Icons.save_outlined),
            ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, isIOS ? 16 : 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: isIOS
                      ? PrimaryGradientButton(
                          onPressed: _loading ? null : () => _pick(ImageSource.camera),
                          height: 52,
                          borderRadius: 18,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_outlined, color: Colors.white.withValues(alpha: 0.92)),
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
                          onPressed: _loading ? null : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
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
                    onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
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
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Couldn’t scan that photo.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Try another photo, or use the camera.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.70),
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_items.isNotEmpty) ...[
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
              child: GlassCard(
                padding: const EdgeInsets.all(6),
                child: _loading
                    ? ListView.separated(
                        itemCount: 6,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) => const SkeletonListTile(),
                      )
                    : (_items.isEmpty
                        ? Center(
                            child: Text(
                              'Your extracted items will appear here.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final it = _items[index];
                              return _ExtractedRow(
                                item: it,
                                errorText: _saveFailures[index],
                                onChanged: (next) {
                                  _items[index] = next;
                                  if (_saveFailures.containsKey(index)) {
                                    setState(() {
                                      final nextFailures = Map<int, String>.from(_saveFailures);
                                      nextFailures.remove(index);
                                      _saveFailures = nextFailures;
                                    });
                                  }
                                },
                              );
                            },
                          )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtractedRow extends StatefulWidget {
  const _ExtractedRow({required this.item, required this.onChanged, this.errorText});

  final ExtractedInventoryItem item;
  final ValueChanged<ExtractedInventoryItem> onChanged;
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
    final showError = widget.errorText != null && widget.errorText!.trim().isNotEmpty;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.85),
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
