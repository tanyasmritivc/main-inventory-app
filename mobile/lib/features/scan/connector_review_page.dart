import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/liquid_surface.dart';

class ConnectorReviewPage extends StatefulWidget {
  const ConnectorReviewPage({
    super.key,
    required this.api,
    required this.source,
  });
  final ApiClient api;
  final Map<String, dynamic> source;
  @override
  State<ConnectorReviewPage> createState() => _ConnectorReviewPageState();
}

class _ConnectorReviewPageState extends State<ConnectorReviewPage> {
  late Map<String, dynamic> source = widget.source;
  final Map<String, int> columns = {};
  final Map<String, String> decisions = {};
  int sheet = 0;
  int page = 0;
  bool busy = false;
  bool mappingDirty = false;
  int invalidBomRows = 0;
  int excludedBomRows = 0;
  String? error;
  List<Map<String, dynamic>>? bom;
  String? purchasingCsv;
  bool get started => source['decisions'] != null;
  bool get isBom => source['kind'] == 'bom';
  List<Map> get sheets =>
      (source['sheets'] as List? ?? []).whereType<Map>().toList();
  List<Map> get rows =>
      (source['rows'] as List? ?? []).whereType<Map>().toList();
  @override
  void initState() {
    super.initState();
    if (sheets.isNotEmpty) _selectSheet(0);
    final mapping = source['mapping'];
    if (mapping is Map && mapping['columns'] is Map) {
      sheet = (mapping['sheet'] as num).toInt();
      columns.clear();
      (mapping['columns'] as Map).forEach(
        (key, value) => columns[key.toString()] = (value as num).toInt(),
      );
    }
    mappingDirty = false;
    _choices();
  }

  void _mappingChanged() {
    mappingDirty = true;
    bom = null;
    purchasingCsv = null;
    page = 0;
  }

  void _selectSheet(int value) {
    _mappingChanged();
    sheet = value;
    columns.clear();
    for (final entry in (sheets[sheet]['suggested_mapping'] as Map).entries) {
      columns[entry.key.toString()] = (entry.value as num).toInt();
    }
  }

  void _choices() {
    decisions.clear();
    if (source['decisions'] is Map) {
      (source['decisions'] as Map).forEach(
        (key, value) => decisions[key.toString()] = value.toString(),
      );
      return;
    }
    for (final row in rows) {
      decisions[row['index'].toString()] =
          (row['errors'] as List).isNotEmpty ||
              (row['duplicates'] as List).isNotEmpty ||
              (row['duplicate_rows'] as List).isNotEmpty
          ? 'skip'
          : 'create';
    }
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (e) {
      if (mounted) setState(() => error = describeError(e).$1);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _preview() => _run(() async {
    final result = await widget.api.connectorImport(
      source['id'],
      action: 'preview',
      data: {
        'revision': source['revision'],
        'sheet': sheet,
        'columns': columns,
      },
    );
    if (!mounted) return;
    setState(() {
      source = result;
      mappingDirty = false;
      purchasingCsv = null;
      page = 0;
      bom = null;
      _choices();
    });
  });
  Future<void> _commit({bool retry = false}) => _run(() async {
    // A frozen set of choices is reused after any unknown network outcome.
    final frozen = Map<String, String>.from(decisions);
    setState(
      () => source = {...source, 'decisions': frozen, 'status': 'importing'},
    );
    do {
      final result = await widget.api.connectorImport(
        source['id'],
        action: 'commit',
        data: {
          'revision': source['revision'],
          'decisions': frozen,
          'retry_failed': retry,
        },
      );
      if (!mounted) return;
      setState(() => source = {...source, ...result});
      retry = false;
    } while (source['status'] == 'importing');
  });
  Future<void> _analyze() => _run(() async {
    final result = await widget.api.connectorImport(
      source['id'],
      action: 'bom',
    );
    invalidBomRows = (result['invalid_rows'] as num? ?? 0).toInt();
    excludedBomRows = (result['excluded_rows'] as num? ?? 0).toInt();
    purchasingCsv = invalidBomRows == 0
        ? result['purchasing_csv'] as String?
        : null;
    page = 0;
    if (mounted) {
      setState(
        () => bom = (result['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );
    }
  });
  Widget _panel(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: LiquidSurface(
      radius: 16,
      shadow: false,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final counts = source['counts'] as Map? ?? {};
    final headers = sheets.isEmpty
        ? <dynamic>[]
        : sheets[sheet]['headers'] as List;
    final shown = bom ?? rows;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isBom ? 'Review parts list' : 'Review import'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              source['filename'].toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${source['location']} · ${rows.isEmpty ? sheets[sheet]['row_count'] : rows.length} rows',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (!started)
              _panel(
                ExpansionTile(
                  initiallyExpanded: rows.isEmpty,
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Column mapping'),
                  subtitle: const Text(
                    'Unmapped category: Supplies. Unmapped quantity: 1.',
                  ),
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: sheet,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Worksheet'),
                      items: [
                        for (var i = 0; i < sheets.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(sheets[i]['name'].toString()),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectSheet(value));
                              }
                            },
                    ),
                    for (final warning
                        in (sheets[sheet]['warnings'] as List? ?? []))
                      Text(warning.toString()),
                    for (final field in (source['fields'] as List? ?? []))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: DropdownButtonFormField<int>(
                          key: ValueKey('$sheet-$field-${columns[field]}'),
                          initialValue: columns[field] ?? -1,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: field.toString().replaceAll('_', ' '),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: -1,
                              child: Text('Not mapped'),
                            ),
                            for (var i = 0; i < headers.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i + 1}. ${headers[i]}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (value) => setState(() {
                                  _mappingChanged();
                                  if (value == null || value < 0) {
                                    columns.remove(field);
                                  } else {
                                    columns[field.toString()] = value;
                                  }
                                }),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy ? null : _preview,
                      child: const Text('Preview rows'),
                    ),
                  ],
                ),
              ),
            if (rows.isNotEmpty && !started && !isBom)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Invalid rows and likely duplicates start as Skip. Review each choice. Existing items are never overwritten.',
                ),
              ),
            if (mappingDirty && rows.isNotEmpty)
              const Text(
                'Mapping changed. Preview rows again before continuing.',
              ),
            if (bom != null && (invalidBomRows > 0 || excludedBomRows > 0))
              Text(
                '$invalidBomRows invalid rows omitted · $excludedBomRows do-not-populate rows excluded. ${invalidBomRows > 0 ? "Correct invalid rows before exporting the purchasing list." : ""}',
              ),
            if (started)
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source['status'] == 'complete'
                          ? 'Import results'
                          : 'Import in progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${counts['imported'] ?? 0} imported · ${counts['skipped'] ?? 0} skipped · ${counts['failed'] ?? 0} failed',
                    ),
                    if ((counts['pending'] as num? ?? 0) > 0)
                      Text('${counts['pending']} rows remaining'),
                  ],
                ),
              ),
            for (final row in shown.skip(page * 50).take(50)) _panel(_row(row)),
            if (shown.length > 50)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous rows',
                    onPressed: page == 0 ? null : () => setState(() => page--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${page + 1} / ${(shown.length / 50).ceil()}'),
                  IconButton(
                    tooltip: 'Next rows',
                    onPressed: (page + 1) * 50 >= shown.length
                        ? null
                        : () => setState(() => page++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (rows.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isBom)
                    FilledButton(
                      onPressed: busy || mappingDirty ? null : _analyze,
                      child: const Text('Check available stock'),
                    )
                  else if (!started || source['status'] != 'complete')
                    FilledButton(
                      onPressed: busy || mappingDirty ? null : _commit,
                      child: Text(started ? 'Resume import' : 'Confirm import'),
                    ),
                  if (started && (counts['failed'] as num? ?? 0) > 0)
                    OutlinedButton(
                      onPressed: busy ? null : () => _commit(retry: true),
                      child: const Text('Retry failed rows'),
                    ),
                  if (started)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.of(context).pop(true),
                      child: const Text('View inventory'),
                    ),
                  if (purchasingCsv != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => _run(() async {
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              await SharePlus.instance.share(
                                ShareParams(
                                  files: [
                                    XFile.fromData(
                                      Uint8List.fromList(
                                        utf8.encode(purchasingCsv!),
                                      ),
                                      mimeType: 'text/csv',
                                    ),
                                  ],
                                  fileNameOverrides: ['findez-shortages.csv'],
                                  sharePositionOrigin: box == null
                                      ? null
                                      : box.localToGlobal(Offset.zero) &
                                            box.size,
                                ),
                              );
                            }),
                      child: const Text('Export shortage CSV'),
                    ),
                  if (bom != null && invalidBomRows == 0)
                    TextButton(
                      onPressed: () async {
                        final text = bom!
                            .where((r) => (r['missing_quantity'] as num) > 0)
                            .map(
                              (r) =>
                                  '${r['name']}: ${r['missing_quantity']} needed (${r['match_status']})',
                            )
                            .join('\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shortage list copied'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy shortages'),
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _row(Map row) {
    if (bom != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['name'].toString(),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Required ${row['required_quantity']} · Available ${row['available_quantity']} · Short ${row['missing_quantity']}',
          ),
          Text('Match: ${row['match_status']}'),
          if (row['match_status'] == 'review')
            const Text(
              'Possible matches need verification; they do not count as available.',
            ),
        ],
      );
    }
    final item = row['item'] as Map;
    final errors = row['errors'] as List;
    final duplicate =
        (row['duplicates'] as List).isNotEmpty ||
        (row['duplicate_rows'] as List).isNotEmpty;
    final receipt =
        (source['receipts'] as Map? ?? {})[row['index'].toString()] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item['name']?.toString().isNotEmpty == true
              ? item['name'].toString()
              : 'Missing name',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          'Row ${row['source_row']} · Qty ${item['quantity']} · ${item['location']}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final e in errors)
          Text(
            e.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (duplicate)
          Text(
            'Possible duplicate${(row['duplicates'] as List).isNotEmpty ? ': ${(row['duplicates'] as List).map((e) => '${e['name']} (${e['location']})').join(', ')}' : ' in this file'}',
          ),
        if (isBom && row['excluded'] == true)
          const Text('Excluded: do not populate'),
        if (receipt != null)
          Text(
            '${receipt['status']}${receipt['message'] == null ? '' : ': ${receipt['message']}'}',
          ),
        if (!started && !isBom)
          DropdownButton<String>(
            isExpanded: true,
            value: decisions[row['index'].toString()],
            items: [
              const DropdownMenuItem(value: 'skip', child: Text('Skip row')),
              if (errors.isEmpty)
                DropdownMenuItem(
                  value: duplicate ? 'create_duplicate' : 'create',
                  child: Text(
                    duplicate ? 'Create a separate item' : 'Create item',
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(
                        () => decisions[row['index'].toString()] = value,
                      );
                    }
                  },
          ),
      ],
    );
  }
}
