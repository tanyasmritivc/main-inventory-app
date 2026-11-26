import '../../core/spreadsheet_file.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';

const _fields = {
  'order': 'Order number',
  'line': 'Supplier line ID',
  'sku': 'SKU',
  'name': 'Part description',
  'quantity': 'Quantity purchased',
  'pack': 'Units per pack',
  'status': 'Supplier status',
};
const _statuses = [
  'unknown',
  'ordered',
  'shipped',
  'delivered',
  'cancelled',
  'returned',
];
typedef _Json = Map<String, dynamic>;

List<_Json> _maps(dynamic value) =>
    (value as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();

class SpaceOrderImport extends StatefulWidget {
  const SpaceOrderImport({
    super.key,
    required this.api,
    required this.organizationId,
    required this.spaceId,
    required this.spaceName,
  });
  final ApiClient api;
  final String organizationId, spaceId, spaceName;

  @override
  State<SpaceOrderImport> createState() => _SpaceOrderImportState();
}

class _SpaceOrderImportState extends State<SpaceOrderImport> {
  final supplier = TextEditingController();

  Uint8List? bytes;
  String filename = '';
  String? error;
  _Json? preview;
  List<dynamic> assignments = [];
  List<_Json> rows = [];
  bool reviewed = false, historical = false, busy = false;

  @override
  void dispose() {
    supplier.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      widget.api.assertCurrentContext();
      await work();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException ? e.message : describeError(e).$1,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() => run(() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: spreadsheetExtensions,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || !mounted) return;
    final file = picked.files.single;
    setState(() {
      bytes = null;
      filename = '';
      preview = null;
      rows = [];
      assignments = [];
      reviewed = false;
    });
    if (!isSpreadsheetFilename(file.name)) {
      throw const FormatException(
        'Choose an Excel (.xlsx), CSV, or JSON spreadsheet.',
      );
    }
    const limit = spreadsheetByteLimit;
    if (file.size <= 0 ||
        file.size > limit ||
        (file.bytes?.length ?? 0) > limit) {
      throw const FormatException('Choose a nonempty file up to 10 MB.');
    }
    final buffer = BytesBuilder(copy: false);
    if (file.bytes != null) {
      buffer.add(file.bytes!);
    } else {
      if (file.readStream == null) {
        throw const FormatException('Choose the file again.');
      }
      await for (final chunk in file.readStream!) {
        if (buffer.length + chunk.length > limit) {
          throw const FormatException('Choose a file up to 10 MB.');
        }
        buffer.add(chunk);
      }
    }
    if (!mounted) return;
    setState(() {
      bytes = buffer.takeBytes();
      filename = file.name;
      preview = null;
      reviewed = false;
      rows = [];
      assignments = [];
    });
    await readColumns();
    if (mounted &&
        preview?['space_review']?['duplicate'] == false &&
        supplier.text.trim().isNotEmpty &&
        rows.isNotEmpty &&
        rows.every(ready)) {
      await save();
    }
  });

  Future<_Json> upload(Map<String, String> fields, {bool confirm = false}) =>
      widget.api.uploadOrder(
        organizationId: widget.organizationId,
        spaceId: widget.spaceId,
        bytes: bytes!,
        filename: filename,
        fields: fields,
        confirm: confirm,
      );

  Future<void> readColumns({bool apply = false}) async {
    final result = await upload({
      if (apply) 'assignments': jsonEncode(assignments),
    });
    if (result['space_review'] is! Map) {
      throw const FormatException(
        'Space order imports are unavailable on this server.',
      );
    }
    if (!mounted) return;
    setState(() {
      preview = result;
      assignments = List.from(result['assignments']);
      rows = _maps(result['rows']);
      reviewed = true;
    });
  }

  bool ready(_Json row) =>
      [
        'order',
        'line',
        'name',
      ].every((k) => (row[k] ?? '').toString().trim().isNotEmpty) &&
      [
        'quantity',
        'pack',
      ].every((k) => (int.tryParse(row[k].toString()) ?? 0) > 0) &&
      _statuses.contains(row['status']);

  Future<void> save() async {
    if (supplier.text.trim().isEmpty) {
      throw const FormatException('Enter the supplier name.');
    }
    for (final row in rows) {
      if (!ready(row)) {
        throw FormatException(
          'Review row ${row['source_row']} in ${row['source_file']}. Enter the order, line, part, status, quantity and units per pack.',
        );
      }
    }
    final result = await upload({
      'supplier': supplier.text.trim(),
      'historical': historical.toString(),
      'assignments': jsonEncode(assignments),
      'rows': jsonEncode(rows),
      'digest': preview!['digest'],
    }, confirm: true);
    if (mounted) Navigator.pop(context, result['created'] as int);
  }

  Widget mapping(int index) {
    final table = preview!['tables'][index];
    final config = assignments[index];
    final records = _maps(table['records']);
    final width = records.fold(
      0,
      (int w, r) =>
          w > (r['cells'] as List).length ? w : (r['cells'] as List).length,
    );
    final h = config?['header'];
    final cells =
        records.where((r) => r['number'] == h).firstOrNull?['cells'] as List? ??
        [];
    return ExpansionTile(
      title: Text(
        [
          table['file'],
          table['sheet'],
        ].where((s) => s.toString().isNotEmpty).join(' · '),
      ),
      initiallyExpanded: index == 0,
      children: [
        SwitchListTile(
          title: const Text('Include sheet'),
          value: config != null,
          onChanged: (v) => setState(
            () => assignments[index] = v
                ? {
                    'header': table['header'],
                    'mapping': Map.of(table['suggestions']),
                  }
                : null,
          ),
        ),
        if (config != null) ...[
          DropdownButtonFormField<int>(
            initialValue: h,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Header row'),
            items: [
              const DropdownMenuItem(value: 0, child: Text('No header row')),
              for (final r in records)
                DropdownMenuItem(
                  value: r['number'] as int,
                  child: Text(
                    "${r['number']} · ${(r['cells'] as List).join(' · ')}",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              config['header'] = v;
              config['mapping'] = {};
            }),
          ),
          for (final record in records.where((r) => r['number'] > h).take(2))
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Row ${record['number']} · ${(record['cells'] as List).join(' · ')}",
              ),
            ),
          for (final entry in _fields.entries)
            DropdownButtonFormField<int>(
              key: ValueKey('$index-$h-${entry.key}'),
              initialValue: config['mapping'][entry.key] ?? -1,
              isExpanded: true,
              decoration: InputDecoration(labelText: entry.value),
              items: [
                const DropdownMenuItem(
                  value: -1,
                  child: Text('Assign manually'),
                ),
                for (var c = 0; c < width; c++)
                  DropdownMenuItem(
                    value: c,
                    child: Text(
                      "${c + 1} · ${c < cells.length ? cells[c] : ''}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                if (v == null || v < 0) {
                  config['mapping'].remove(entry.key);
                } else {
                  config['mapping'][entry.key] = v;
                }
              }),
            ),
        ],
      ],
    );
  }

  Future<void> edit(_Json row) async {
    final draft = Map<String, dynamic>.of(row);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Review row ${row['source_row']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _fields.entries)
                if (entry.key == 'status')
                  DropdownButtonFormField<String>(
                    initialValue: _statuses.contains(draft['status'])
                        ? draft['status']
                        : null,
                    decoration: InputDecoration(labelText: entry.value),
                    items: [
                      for (final s in _statuses)
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => draft['status'] = v,
                  )
                else
                  TextFormField(
                    initialValue: draft[entry.key]?.toString(),
                    decoration: InputDecoration(labelText: entry.value),
                    keyboardType: ['quantity', 'pack'].contains(entry.key)
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: (v) => draft[entry.key] = v.trim(),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) setState(() => row.addAll(draft));
  }

  @override
  Widget build(BuildContext context) {
    final duplicate = preview?['space_review']?['duplicate'] == true;
    final matches = _maps(preview?['space_review']?['matches'] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('Import orders')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: busy,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.spaceName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'A complete spreadsheet imports directly. You can review missing order details before saving.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: supplier,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              SwitchListTile(
                title: const Text('Purchase history only'),
                subtitle: const Text(
                  'Use for past orders without an expected delivery.',
                ),
                value: historical,
                onChanged: (v) => setState(() => historical = v),
              ),
              const Text('$spreadsheetFormats · 500 order lines maximum'),
              OutlinedButton.icon(
                onPressed: pick,
                icon: const Icon(Icons.upload_file),
                label: Text(filename.isEmpty ? 'Choose order file' : filename),
              ),
              if (bytes != null && preview == null && !busy)
                TextButton(
                  onPressed: () => run(readColumns),
                  child: const Text('Retry preview'),
                ),
              if (duplicate)
                const Text('This file is already in organization Orders.'),
              if (preview != null && !duplicate && !reviewed) ...[
                for (var i = 0; i < (preview!['tables'] as List).length; i++)
                  mapping(i),
                FilledButton(
                  onPressed: () => run(() => readColumns(apply: true)),
                  child: const Text('Review order lines'),
                ),
              ],
              if (reviewed && !duplicate) ...[
                TextButton(
                  onPressed: () => setState(() => reviewed = false),
                  child: const Text('Adjust column mapping'),
                ),
                if (rows.length > 1)
                  ExpansionTile(
                    title: const Text('Fill blank fields'),
                    children: [
                      for (final key in ['order', 'pack'])
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: _fields[key],
                            helperText:
                                'Applies to blank lines when you tap Done',
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (value) {
                            if (value.trim().isEmpty ||
                                (key == 'pack' &&
                                    (int.tryParse(value) ?? 0) < 1)) {
                              return;
                            }
                            setState(() {
                              for (final row in rows) {
                                if (row[key] == '') row[key] = value.trim();
                              }
                            });
                          },
                        ),
                    ],
                  ),
                for (final row in rows)
                  ListTile(
                    title: Text(
                      (row['name'] as String).isEmpty
                          ? 'Unnamed part'
                          : row['name'],
                    ),
                    subtitle: Text(
                      [
                        "${row['source_file']} · row ${row['source_row']}",
                        "Order ${row['order']} · ${row['quantity']} × ${row['pack']} units",
                        for (final m in matches.where(
                          (m) =>
                              m['name'] == row['name'] &&
                              m['sku'] == row['sku'],
                        ))
                          "Possible match · ${m['item_name']} · ${m['recorded_quantity'] ?? 'Unknown quantity'} recorded in ${m['space_name']}${m['location'] == null || m['location'] == m['space_name'] ? '' : ' · ${m['location']}'}",
                      ].join('\n'),
                    ),
                    onTap: () => edit(row),
                    trailing: IconButton(
                      tooltip: 'Exclude line',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() => rows.remove(row)),
                    ),
                  ),
                FilledButton(
                  onPressed: rows.isEmpty ? null : () => run(save),
                  child: Text('Confirm ${rows.length} order lines'),
                ),
              ],
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
