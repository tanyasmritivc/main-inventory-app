import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../inventory/item_detail_sheet.dart';

class _KitNeed {
  const _KitNeed(this.name, this.required, this.missing);

  final String name;
  final int required;
  final int missing;
}

class _AnswerData {
  const _AnswerData(this.lookup, this.owned, this.kits);

  final BarcodeLookupResult lookup;
  final InventoryItem? owned;
  final List<_KitNeed> kits;
}

Future<void> showBarcodeAnswerSheet(
  BuildContext context, {
  required ApiClient api,
  required String barcode,
  required String destination,
  required VoidCallback onSaved,
  required VoidCallback onPhotograph,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppTokens.of(context).bg,
  builder: (_) => _BarcodeAnswer(
    api: api,
    barcode: barcode,
    destination: destination,
    onSaved: onSaved,
    onPhotograph: onPhotograph,
  ),
);

class _BarcodeAnswer extends StatefulWidget {
  const _BarcodeAnswer({
    required this.api,
    required this.barcode,
    required this.destination,
    required this.onSaved,
    required this.onPhotograph,
  });

  final ApiClient api;
  final String barcode;
  final String destination;
  final VoidCallback onSaved;
  final VoidCallback onPhotograph;

  @override
  State<_BarcodeAnswer> createState() => _BarcodeAnswerState();
}

class _BarcodeAnswerState extends State<_BarcodeAnswer> {
  late Future<_AnswerData> _lookup;
  bool _saving = false;
  String? _error;

  bool _hasIdentity(String? name) {
    final value = name?.trim().toLowerCase() ?? '';
    return value.isNotEmpty &&
        value != 'unknown item' &&
        value != 'unidentified item' &&
        value != 'unknown';
  }

  @override
  void initState() {
    super.initState();
    _lookup = _read();
  }

  Future<_AnswerData> _read() async {
    final result = await widget.api.barcodeLookup(barcode: widget.barcode);
    final id = result.existingItem?['item_id']?.toString();
    final owned = id == null ? null : await widget.api.itemDetail(id);
    if (owned == null) return _AnswerData(result, null, const []);
    final relations = await widget.api.itemRelationships(owned.itemId);
    final ids = relations
        .where((relation) => relation['kind'] == 'needed_by')
        .map((relation) => (relation['project_kit'] as Map?)?['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final kits = await Future.wait(ids.map(widget.api.getProjectKit));
    final needs = <_KitNeed>[];
    for (final kit in kits) {
      final itemPart = owned.partNumber?.trim().toLowerCase();
      final line = kit.items.where((row) {
        final part = row.partNumber?.trim().toLowerCase();
        return (itemPart != null && itemPart.isNotEmpty && part == itemPart) ||
            row.name.trim().toLowerCase() == owned.name.trim().toLowerCase();
      }).firstOrNull;
      if (line != null) {
        needs.add(
          _KitNeed(kit.name, line.requiredQuantity, line.missingQuantity),
        );
      }
    }
    return _AnswerData(result, owned, needs);
  }

  String _path(InventoryItem item) =>
      [
            item.workspaceName,
            item.spaceName ?? item.location,
            item.binName,
            item.container,
          ]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' / ');

  Future<void> _add(BarcodeLookupResult result, InventoryItem? owned) async {
    if (_saving) return;
    var saved = false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (owned != null) {
        await widget.api.updateItem(
          request: UpdateItemRequest(
            itemId: owned.itemId,
            quantity: owned.quantity + 1,
            barcode: widget.barcode,
          ),
        );
      } else {
        final name = result.name?.trim() ?? '';
        if (!_hasIdentity(name)) {
          setState(() => _error = 'Photograph the label or add a name first.');
          return;
        }
        await widget.api.addItem(
          item: AddItemRequest(
            name: name,
            category: (result.category ?? '').trim().isEmpty
                ? 'Other'
                : result.category!.trim(),
            quantity: 1,
            location: widget.destination,
            barcode: widget.barcode,
            imageUrl: result.imageUrl,
          ),
        );
      }
      widget.onSaved();
      saved = true;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save this object. Try again.');
      }
    } finally {
      if (mounted && !saved) setState(() => _saving = false);
    }
  }

  Future<void> _recount(InventoryItem owned) async {
    final count = TextEditingController(text: owned.quantity.toString());
    final next = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recount stock'),
        content: TextField(
          controller: count,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Count now'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(count.text.trim())),
            child: const Text('Save count'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    count.dispose();
    if (next == null || next < 0) return;
    var saved = false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(itemId: owned.itemId, quantity: next),
      );
      widget.onSaved();
      saved = true;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save the count. Try again.');
      }
    } finally {
      if (mounted && !saved) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            child: FutureBuilder<_AnswerData>(
              future: _lookup,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not read this code.'),
                      TextButton(
                        onPressed: () => setState(() => _lookup = _read()),
                        child: const Text('Try again'),
                      ),
                    ],
                  );
                }
                final data = snapshot.data!;
                final result = data.lookup;
                final owned = data.owned;
                final name = owned?.name ?? result.name?.trim();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasIdentity(name) ? name! : 'No match yet',
                      style: TextStyle(color: t.ink, fontSize: 25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.barcode}  ·  ${owned == null ? 'not in this workspace' : 'matched to what you own'}',
                      style: TextStyle(color: t.text2, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (owned != null) ...[
                      _answerRow(t, 'You have', '${owned.quantity}'),
                      if (_path(owned).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _path(owned),
                            style: TextStyle(color: t.text2),
                          ),
                        ),
                      for (final kit in data.kits) ...[
                        const SizedBox(height: 14),
                        _answerRow(t, '${kit.name} needs', '${kit.required}'),
                        if (kit.missing > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${kit.missing} missing',
                              style: TextStyle(color: t.warn, fontSize: 14),
                            ),
                          ),
                      ],
                    ] else
                      Text(
                        _hasIdentity(name)
                            ? 'This code has an identity, but no stock here yet.'
                            : 'Photograph the product label so it can be named.',
                        style: TextStyle(color: t.text2, fontSize: 15),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: t.danger)),
                    ],
                    const SizedBox(height: 24),
                    if (_hasIdentity(name))
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : () => _add(result, owned),
                          child: const Text('Add to stock'),
                        ),
                      ),
                    if (owned != null) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _recount(owned),
                          child: const Text('Recount'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showItemDetailSheet(
                          context,
                          item: owned,
                          api: widget.api,
                        ),
                        child: const Text('Open object'),
                      ),
                    ] else
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onPhotograph();
                        },
                        child: const Text('Photograph label'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerRow(AppTokens t, String label, String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: t.ink, fontSize: 15)),
        ),
        Text(
          value,
          style: TextStyle(
            color: t.ink,
            fontFamily: 'IBMPlexMono',
            fontSize: 18,
          ),
        ),
      ],
    ),
  );
}
