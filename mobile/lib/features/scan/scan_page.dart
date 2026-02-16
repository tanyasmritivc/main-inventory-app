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

  List<ExtractedInventoryItem> _items = const [];

  Future<void> _pick(ImageSource src) async {
    setState(() {
      _loading = true;
      _saving = false;
      _error = null;
      _items = const [];
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
        setState(() => _error = 'Rate limited. Try again in ~20 seconds.');
      } else {
        setState(() => _error = e.message ?? 'Request failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.bulkCreateInventory(items: _items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to inventory')));
      widget.onSaved();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        setState(() => _error = 'Rate limited. Try again in ~20 seconds.');
      } else {
        setState(() => _error = e.message ?? 'Request failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        padding: EdgeInsets.fromLTRB(20, isIOS ? 18 : 20, 20, 20),
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
                              const Text('Scan with camera'),
                            ],
                          ),
                        )
                      : FilledButton.icon(
                          onPressed: _loading ? null : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Scan with camera'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Upload photo'),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                                onChanged: (next) => setState(() => _items[index] = next),
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
  const _ExtractedRow({required this.item, required this.onChanged});

  final ExtractedInventoryItem item;
  final ValueChanged<ExtractedInventoryItem> onChanged;

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
        child: Row(
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
      ),
    );
  }
}
