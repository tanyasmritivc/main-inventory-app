import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'bin_label_sheet.dart';
import 'world_views.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    super.key,
    required this.api,
    required this.onScan,
    required this.onAddPlace,
  });

  final ApiClient api;
  final VoidCallback onScan;
  final VoidCallback onAddPlace;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  List<Map<String, dynamic>>? _spaces;
  List<InventoryItem> _items = const [];
  String? _error;
  bool _sharing = false;
  final GlobalKey _sheetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final spaces = await widget.api.listSpaces();
      if (!mounted) return;
      setState(() => _spaces = spaces);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Places could not be loaded.');
      return;
    }
    try {
      final result = await widget.api.searchItems(query: '');
      if (mounted) setState(() => _items = result.items);
    } catch (_) {
      // Labels still work when the optional item summary is unavailable.
    }
  }

  List<InventoryItem> _itemsFor(Map<String, dynamic> space) {
    final id = (space['id'] ?? '').toString();
    final name = (space['name'] ?? '').toString();
    return _items.where((item) {
      return id.isNotEmpty && item.spaceId == id ||
          (item.spaceId == null && item.location == name);
    }).toList();
  }

  Future<void> _shareSheet() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _sheetKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('Label sheet is not ready');
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Label sheet could not be rendered');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/findez-place-labels.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'FindEZ place labels'),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share labels. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _showSheet(List<Map<String, dynamic>> spaces) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Place labels',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _sheetKey,
                    child: _PrintableLabels(spaces: spaces),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _shareSheet,
                child: const Text('Share or print'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final spaces = _spaces;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(title: 'Labels', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    'Scanning a place label sets the destination before you capture.',
                    style: TextStyle(color: t.text2, fontSize: 15),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: widget.onScan,
                    child: const Text('Scan a label'),
                  ),
                  const SizedBox(height: 20),
                  if (spaces == null && _error == null)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Column(
                      children: [
                        Text(_error!, style: TextStyle(color: t.ink)),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  else ...[
                    if (spaces!.isEmpty)
                      Text(
                        'No places yet. Add a place to make its label.',
                        style: TextStyle(color: t.text2),
                      )
                    else
                      WorldSection(
                        title: 'Places',
                        children: [
                          for (final space in spaces)
                            WorldRow(
                              title: (space['name'] ?? '').toString(),
                              subtitle: 'Open label',
                              count: '',
                              onTap: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (_) => BinLabelSheet(
                                  spaceName: (space['name'] ?? '').toString(),
                                  items: _itemsFor(space),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (spaces.isNotEmpty) ...[
                      OutlinedButton(
                        onPressed: _sharing ? null : () => _showSheet(spaces),
                        child: const Text('Print a sheet'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton(
                      onPressed: widget.onAddPlace,
                      child: const Text('Add places'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Labels belong to places. Put one on a drawer or shelf, then scan it before capturing what is inside.',
                      style: TextStyle(color: t.text2, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintableLabels extends StatelessWidget {
  const _PrintableLabels({required this.spaces});

  final List<Map<String, dynamic>> spaces;

  @override
  Widget build(BuildContext context) {
    final print = AppTokens.light;
    return ColoredBox(
      color: print.paper,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final space in spaces)
              SizedBox(
                width: 126,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data:
                          'findez://space/${Uri.encodeComponent((space['name'] ?? '').toString())}',
                      size: 116,
                      backgroundColor: print.paper,
                      eyeStyle: QrEyeStyle(color: print.ink),
                      dataModuleStyle: QrDataModuleStyle(color: print.ink),
                    ),
                    Text(
                      (space['name'] ?? '').toString(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: print.ink, fontSize: 14),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
