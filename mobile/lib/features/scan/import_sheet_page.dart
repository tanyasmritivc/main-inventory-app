import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_error.dart';
import '../../core/config.dart';

enum _ImportState { empty, parsing, preview, importing }

class ImportSheetPage extends StatefulWidget {
  const ImportSheetPage({super.key});

  @override
  State<ImportSheetPage> createState() => _ImportSheetPageState();
}

class _ImportSheetPageState extends State<ImportSheetPage> {
  _ImportState _state = _ImportState.empty;
  String? _filename;
  List<Map<String, dynamic>> _parsedItems = [];
  String? _errorMessage;
  int _importedCount = 0;
  bool _importComplete = false;
  int _importSuccessCount = 0;
  List<String> _importFailedNames = [];
  String _selectedFilter = 'All';

  dio.Dio _backend() {
    final d = dio.Dio(
      dio.BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 3),
      ),
    );
    d.interceptors.add(
      dio.InterceptorsWrapper(
        onRequest: (options, handler) {
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return d;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _filename = file.name;
      _state = _ImportState.parsing;
      _errorMessage = null;
    });
    await _parseFile(file);
  }

  Future<void> _parseFile(PlatformFile file) async {
    try {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Could not read file bytes');
      final ext = (file.extension ?? '').toLowerCase();
      final sheets = <Map<String, dynamic>>[];

      if (ext == 'csv') {
        final csvString = utf8.decode(bytes);
        final lines = const LineSplitter().convert(csvString);
        if (lines.isEmpty) throw Exception('Empty file');
        final headers = _parseCsvRow(lines.first);
        final rows = lines
            .skip(1)
            .where((l) => l.trim().isNotEmpty)
            .map(_parseCsvRow)
            .toList();
        sheets.add({'name': 'Sheet1', 'headers': headers, 'rows': rows});
      } else {
        final excel = xl.Excel.decodeBytes(bytes);
        for (final sheetName in excel.tables.keys) {
          final table = excel.tables[sheetName]!;
          final allRows = table.rows;
          if (allRows.isEmpty) continue;
          int headerIdx = 0;
          while (headerIdx < allRows.length) {
            final row = allRows[headerIdx];
            if (row.any(
              (c) => c != null && (c.value?.toString().isNotEmpty ?? false),
            )) break;
            headerIdx++;
          }
          if (headerIdx >= allRows.length) continue;
          final headers = allRows[headerIdx]
              .map((c) => c?.value?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
          final rows = allRows.skip(headerIdx + 1).map((row) {
            return row
                .take(headers.length)
                .map((c) => c?.value?.toString() ?? '')
                .toList();
          }).where((r) => r.any((s) => s.isNotEmpty)).toList();
          sheets.add({'name': sheetName, 'headers': headers, 'rows': rows});
        }
      }

      if (sheets.isEmpty) throw Exception('No data found in file');

      final buf = StringBuffer();
      for (final sheet in sheets.take(3)) {
        buf.writeln('Sheet: ${sheet['name']}');
        buf.writeln(
          'Headers: ${(sheet['headers'] as List).join(', ')}',
        );
        buf.writeln('Sample rows:');
        final rows = sheet['rows'] as List;
        for (final row in rows.take(10)) {
          buf.writeln((row as List).join(', '));
        }
        buf.writeln('Total rows: ${rows.length}');
        buf.writeln();
      }
      final summaryString = buf.toString();

      final prompt =
          'You are parsing a spreadsheet for an inventory app. Map every row to an item.\n\n'
          'Return ONLY a valid JSON array. No explanation. No markdown. No code fences. Raw JSON only.\n\n'
          'Each item must have these exact fields:\n'
          '{\n'
          '  "name": "descriptive item name - combine type+size+description e.g. M4 12mm Screw",\n'
          '  "category": "must be exactly one of: Food, Electronics, Clothing, Health, Home, Office, Supplies, Toys, Cosmetics, Other - use Supplies for hardware and mechanical parts",\n'
          '  "subcategory": "part type if available e.g. Screw, Nut, Bearing, Belt",\n'
          '  "quantity": integer or 1 if missing,\n'
          '  "location": "sheet name if it describes a physical location, else Unsorted",\n'
          '  "part_number": "any PN, SKU, or part number column value",\n'
          '  "notes": "combine size, vendor, description into one string"\n'
          '}\n\n'
          'Spreadsheet data:\n'
          '$summaryString\n\n'
          'Map ALL rows. Return complete JSON array.';

      final res = await _backend().post<Map<String, dynamic>>(
        '/ai_command',
        data: {'message': prompt},
        options: dio.Options(
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 3),
        ),
      );

      final data = res.data ?? {};
      String raw = (data['assistant_message'] ?? data['message'] ?? '')
          .toString()
          .trim();
      raw = raw
          .replaceAll(RegExp(r'```[a-z]*\n?'), '')
          .replaceAll('```', '')
          .trim();

      final decoded = json.decode(raw) as List;
      final items = decoded.cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _parsedItems = items;
        _state = _ImportState.preview;
        _selectedFilter = 'All';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ImportState.empty;
        _errorMessage =
            'Could not parse file. Please check the format and try again.';
      });
    }
  }

  List<String> _parseCsvRow(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  Future<void> _startImport() async {
    setState(() {
      _state = _ImportState.importing;
      _importedCount = 0;
      _importComplete = false;
      _importSuccessCount = 0;
      _importFailedNames = [];
    });
    final backend = _backend();
    int successCount = 0;
    final List<String> failedNames = [];
    for (int i = 0; i < _parsedItems.length; i++) {
      final item = _parsedItems[i];
      try {
        await backend.post<Map<String, dynamic>>(
          '/add_item',
          data: {
            'name': (item['name'] ?? '').toString(),
            'category': (item['category'] ?? 'Other').toString(),
            'quantity': (item['quantity'] is int)
                ? item['quantity']
                : int.tryParse((item['quantity'] ?? '1').toString()) ?? 1,
            'location': (item['location'] ?? 'Unsorted').toString(),
            if ((item['notes']?.toString().isNotEmpty ?? false))
              'notes': item['notes'].toString(),
          },
        );
        successCount++;
      } catch (e) {
        final name = (item['name']?.toString().isNotEmpty ?? false)
            ? item['name'].toString()
            : 'Item ${i + 1}';
        failedNames.add(name);
        debugPrint('[Import] failed to save "$name": ${describeError(e).$1}');
      }
      if (!mounted) return;
      setState(() => _importedCount = i + 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    setState(() {
      _importComplete = true;
      _importSuccessCount = successCount;
      _importFailedNames = failedNames;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _state == _ImportState.preview
              ? '${_parsedItems.length} Items Found'
              : 'Import Spreadsheet',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ImportState.empty:
        return _buildEmpty();
      case _ImportState.parsing:
        return _buildParsing();
      case _ImportState.preview:
        return _buildPreview();
      case _ImportState.importing:
        return _buildImporting();
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1),
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_chart_outlined,
                      size: 40, color: Color(0x4DFFFFFF)),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload a spreadsheet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Excel or CSV — AI maps your columns and organizes everything automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _pickFile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Choose File',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Supports .xlsx, .xls, .csv',
                    style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParsing() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Reading your file...',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final subcategories = <String>{};
    for (final item in _parsedItems) {
      final sub = (item['subcategory'] ?? '').toString().trim();
      if (sub.isNotEmpty) subcategories.add(sub);
    }
    final filters = ['All', ...subcategories.toList()..sort()];

    final indexMap = <int>[];
    final filteredItems = <Map<String, dynamic>>[];
    for (int i = 0; i < _parsedItems.length; i++) {
      final item = _parsedItems[i];
      final sub = (item['subcategory'] ?? '').toString().trim();
      if (_selectedFilter == 'All' || sub == _selectedFilter) {
        filteredItems.add(item);
        indexMap.add(i);
      }
    }

    final subCounts = <String, int>{};
    for (final item in _parsedItems) {
      final sub = (item['subcategory'] ?? '').toString().trim();
      if (sub.isNotEmpty) subCounts[sub] = (subCounts[sub] ?? 0) + 1;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_filename != null)
                  Text(
                    _filename!.length > 40
                        ? '${_filename!.substring(0, 37)}...'
                        : _filename!,
                    style: const TextStyle(
                        color: Color(0x73FFFFFF), fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_parsedItems.length} items ready to import',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subCounts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: subCounts.entries
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0x0AFFFFFF),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                      color: const Color(0x14FFFFFF)),
                                ),
                                child: Text(
                                  '${e.value} ${e.key}',
                                  style: const TextStyle(
                                    color: Color(0x73FFFFFF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (filters.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemCount: filters.length,
              itemBuilder: (_, i) {
                final label = filters[i];
                final isActive = _selectedFilter == label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : const Color(0x0AFFFFFF),
                      borderRadius: BorderRadius.circular(99),
                      border: isActive
                          ? null
                          : Border.all(
                              color: const Color(0x14FFFFFF), width: 0.5),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? Colors.black
                            : const Color(0x73FFFFFF),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            itemCount: filteredItems.length,
            itemBuilder: (context, i) {
              final item = filteredItems[i];
              final realIndex = indexMap[i];
              final sub = (item['subcategory'] ?? '').toString().trim();
              final pn = (item['part_number'] ?? '').toString().trim();
              final notes = (item['notes'] ?? '').toString().trim();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0x0AFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0x14FFFFFF), width: 0.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['name'] ?? '').toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (sub.isNotEmpty || pn.isNotEmpty)
                            Row(
                              children: [
                                if (sub.isNotEmpty) _pill(sub),
                                if (sub.isNotEmpty && pn.isNotEmpty)
                                  const SizedBox(width: 4),
                                if (pn.isNotEmpty) _pill(pn),
                              ],
                            ),
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              notes,
                              style: const TextStyle(
                                  color: Color(0x4DFFFFFF), fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Qty ${item['quantity'] ?? 1}',
                          style: const TextStyle(
                              color: Color(0x73FFFFFF), fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(
                              () => _parsedItems.removeAt(realIndex)),
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0x4DFFFFFF)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _parsedItems.isEmpty ? null : _startImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0x33FFFFFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Import ${_parsedItems.length} Items',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Center(
                  child: Text(
                    'Cancel',
                    style:
                        TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0x73FFFFFF), fontSize: 11),
        ),
      );

  Widget _buildImporting() {
    if (_importComplete) {
      final failed = _importFailedNames.length;
      final total = _parsedItems.length;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                failed == 0
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                size: 48,
                color: failed == 0
                    ? const Color(0xFF30D158)
                    : const Color(0xFFFBBF24),
              ),
              const SizedBox(height: 16),
              Text(
                failed == 0 ? 'Import complete!' : 'Import finished with errors',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                failed == 0
                    ? '$_importSuccessCount of $total items saved'
                    : 'Saved $_importSuccessCount of $total — $failed failed',
                style: const TextStyle(
                    color: Color(0x73FFFFFF), fontSize: 14),
              ),
              if (failed > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _importFailedNames.join(', '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0x4DFFFFFF), fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Go to My Stuff',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _state = _ImportState.empty;
                    _parsedItems = [];
                    _filename = null;
                    _importedCount = 0;
                    _importComplete = false;
                    _importSuccessCount = 0;
                    _importFailedNames = [];
                    _errorMessage = null;
                    _selectedFilter = 'All';
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  child: const Text(
                    'Import another',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = _parsedItems.length;
    final progress = total > 0 ? _importedCount / total : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: const Color(0x14FFFFFF),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Importing $_importedCount of $total...',
              style: const TextStyle(
                  color: Color(0x73FFFFFF), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
