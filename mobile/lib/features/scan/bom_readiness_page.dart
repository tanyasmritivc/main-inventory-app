import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';

class BomReadinessPage extends StatefulWidget {
  const BomReadinessPage({
    super.key,
    required this.api,
    required this.location,
    this.shareId,
  });

  final ApiClient api;
  final String location;
  final String? shareId;

  @override
  State<BomReadinessPage> createState() => _BomReadinessPageState();
}

class _BomReadinessPageState extends State<BomReadinessPage> {
  bool _loading = false;
  String? _error;
  BomAnalysisResult? _result;

  Future<void> _chooseBom() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final extension = (file.extension ?? file.name.split('.').last)
        .toLowerCase();
    if (extension != 'xlsx' && extension != 'csv') {
      setState(() => _error = 'Choose an Excel (.xlsx) or CSV file.');
      return;
    }
    if (file.size <= 0 || file.size > 10 * 1024 * 1024) {
      setState(
        () => _error = 'Choose a non-empty spreadsheet smaller than 10 MB.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final multipart = file.path != null
          ? await dio.MultipartFile.fromFile(file.path!, filename: file.name)
          : dio.MultipartFile.fromStream(
              () => file.readStream!,
              file.size,
              filename: file.name,
            );
      final result = await widget.api.analyzeBom(
        file: multipart,
        location: widget.location,
        shareId: widget.shareId,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error).$1);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyMissing() async {
    final missing =
        _result?.items.where((item) => item.missingQuantity > 0).toList() ?? [];
    final text = missing
        .map((item) {
          final part = item.partNumber == null ? '' : ' (${item.partNumber})';
          return '${item.missingQuantity}× ${item.name}$part';
        })
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Missing-parts list copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Build Readiness'),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: result == null ? _emptyView() : _resultsView(result),
      ),
    );
  }

  Widget _emptyView() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.fact_check_outlined,
          size: 68,
          color: Color(0xFF7CA2E4),
        ),
        const SizedBox(height: 20),
        const Text(
          'Can you build it today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Choose a BOM to compare every required part with ${widget.location}. Your inventory will not be changed.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 16,
            height: 1.4,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _loading ? null : _chooseBom,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(_loading ? 'Analyzing…' : 'Choose BOM'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Supported columns: Name or Part Number, and Quantity',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _resultsView(BomAnalysisResult result) {
    final summary = result.summary;
    final missingCount = result.items
        .where((item) => item.missingQuantity > 0)
        .length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF171717),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  '${summary.readinessPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'ready in ${result.location}',
                  style: const TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: summary.readinessPercent / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: Colors.white12,
                  color: summary.readinessPercent == 100
                      ? Colors.greenAccent
                      : const Color(0xFF7CA2E4),
                ),
                const SizedBox(height: 12),
                Text(
                  '${summary.readyLines} ready · ${summary.partialLines} partial · ${summary.missingLines} missing',
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            itemCount: result.items.length,
            separatorBuilder: (_, _) =>
                const Divider(color: Colors.white12, height: 1),
            itemBuilder: (_, index) {
              final item = result.items[index];
              final ready = item.status == 'ready';
              final partial = item.status == 'partial';
              final color = ready
                  ? Colors.greenAccent
                  : (partial ? Colors.orangeAccent : Colors.redAccent);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                leading: Icon(
                  ready
                      ? Icons.check_circle
                      : (partial ? Icons.timelapse : Icons.cancel),
                  color: color,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  [
                    if (item.brand != null) item.brand!,
                    if (item.partNumber != null) item.partNumber!,
                  ].join(' · '),
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: Text(
                  '${item.availableQuantity}/${item.requiredQuantity}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _chooseBom,
                  child: const Text('Check Another'),
                ),
              ),
              if (missingCount > 0) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _copyMissing,
                    icon: const Icon(Icons.copy),
                    label: Text('Copy Missing ($missingCount)'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
