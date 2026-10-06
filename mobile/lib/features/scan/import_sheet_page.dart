import '../../core/app_theme.dart';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import 'package:mobile/core/ui/app_text.dart';

enum _ImportState { ready, uploading, success }

class ImportSheetPage extends StatefulWidget {
  const ImportSheetPage({
    super.key,
    required this.api,
    required this.location,
    this.shareId,
    this.initialFilePath,
    this.initialFilename,
  });

  final ApiClient api;
  final String location;
  final String? shareId;
  final String? initialFilePath;
  final String? initialFilename;

  @override
  State<ImportSheetPage> createState() => _ImportSheetPageState();
}

class _ImportSheetPageState extends State<ImportSheetPage> {
  static const _maxFileBytes = 10 * 1024 * 1024;

  _ImportState _state = _ImportState.ready;
  String? _filename;
  String? _errorMessage;
  SpreadsheetImportResult? _result;

  @override
  void initState() {
    super.initState();
    final path = widget.initialFilePath;
    if (path == null || path.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _importSharedFile(path);
    });
  }

  Future<void> _importSharedFile(String path) async {
    try {
      final source = File(path);
      final size = await source.length();
      if (!mounted) return;
      await _importFile(
        PlatformFile(
          name: widget.initialFilename ?? source.uri.pathSegments.last,
          path: path,
          size: size,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The shared spreadsheet could not be opened.';
        _state = _ImportState.ready;
      });
      debugPrint('[Import] shared file failed: $error');
    }
  }

  Future<dio.MultipartFile> _multipartFile(PlatformFile file) async {
    final safeName = file.name.replaceAll('/', '_').replaceAll('\\', '_');
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return dio.MultipartFile.fromFile(path, filename: safeName);
    }

    final stream = file.readStream;
    if (stream == null) {
      throw StateError('The selected file could not be opened.');
    }
    return dio.MultipartFile.fromStream(
      () => stream,
      file.size,
      filename: safeName,
    );
  }

  Future<void> _pickAndImport() async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The file picker could not open. Please try again.';
      });
      debugPrint('[Import] file picker failed: $error');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    await _importFile(picked.files.single);
  }

  Future<void> _importFile(PlatformFile file) async {
    final extension = (file.extension ?? file.name.split('.').last)
        .trim()
        .toLowerCase();
    if (extension != 'xlsx' && extension != 'csv') {
      setState(() {
        _errorMessage = extension == 'json'
            ? 'JSON import is not supported yet. Choose an Excel (.xlsx) or CSV file.'
            : 'Choose an Excel (.xlsx) or CSV file.';
      });
      return;
    }
    if (file.size <= 0) {
      setState(() => _errorMessage = 'The selected file is empty.');
      return;
    }
    if (file.size > _maxFileBytes) {
      setState(() {
        _errorMessage = 'Choose a spreadsheet smaller than 10 MB.';
      });
      return;
    }

    setState(() {
      _filename = file.name;
      _errorMessage = null;
      _result = null;
      _state = _ImportState.uploading;
    });

    try {
      final multipart = await _multipartFile(file);
      final result = await widget.api.importSpreadsheet(
        file: multipart,
        location: widget.location,
        shareId: widget.shareId,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _ImportState.success;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = describeError(error).$1;
        _state = _ImportState.ready;
      });
    }
  }

  void _importAnother() {
    setState(() {
      _filename = null;
      _errorMessage = null;
      _result = null;
      _state = _ImportState.ready;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != _ImportState.uploading,
      child: Scaffold(
        backgroundColor: AppTheme.adaptive(context, Colors.black),
        appBar: AppBar(
          title: const AppText('Import Spreadsheet'),
          centerTitle: true,
          backgroundColor: AppTheme.adaptive(context, Colors.black),
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: _state != _ImportState.uploading,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_state) {
              _ImportState.ready => _ReadyView(
                key: const ValueKey('ready'),
                location: widget.location,
                errorMessage: _errorMessage,
                onChooseFile: _pickAndImport,
              ),
              _ImportState.uploading => _UploadingView(
                key: const ValueKey('uploading'),
                filename: _filename ?? 'Spreadsheet',
                location: widget.location,
              ),
              _ImportState.success => _SuccessView(
                key: const ValueKey('success'),
                result: _result!,
                location: widget.location,
                onViewItems: () => Navigator.of(context).pop(true),
                onImportAnother: _importAnother,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    super.key,
    required this.location,
    required this.errorMessage,
    required this.onChooseFile,
  });

  final String location;
  final String? errorMessage;
  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.adaptive(context, const Color(0xFF171717)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.adaptive(context, const Color(0x1FFFFFFF)),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.adaptive(context, const Color(0x1AFFFFFF)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  color: AppTheme.foreground(context, Colors.white),
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              AppText(
                'Import a spreadsheet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.foreground(context, Colors.white),
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              AppText(
                'Items will be organized and added to “$location”.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x99FFFFFF)),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: onChooseFile,
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: const AppText('Choose Spreadsheet'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.adaptive(context, Colors.white),
                    foregroundColor: AppTheme.adaptive(context, Colors.black),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppText(
                'Excel (.xlsx) or CSV · Maximum 10 MB',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0x66FFFFFF)),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0x1AFF453A)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.adaptive(context, const Color(0x4DFF453A)),
              ),
            ),
            child: AppText(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0xFFFF6961)),
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _InfoRow(
          icon: Icons.cloud_upload_outlined,
          title: 'Processed securely',
          subtitle:
              'The file is sent to FindEZ for processing, not parsed on your phone.',
        ),
        const _InfoRow(
          icon: Icons.auto_awesome_outlined,
          title: 'Columns mapped automatically',
          subtitle:
              'Names, quantities, categories, brands, and part numbers are detected.',
        ),
        const _InfoRow(
          icon: Icons.inventory_2_outlined,
          title: 'Added in one import',
          subtitle:
              'Valid rows are saved together and your inventory refreshes afterward.',
        ),
      ],
    );
  }
}

class _UploadingView extends StatelessWidget {
  const _UploadingView({
    super.key,
    required this.filename,
    required this.location,
  });

  final String filename;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: AppTheme.adaptive(context, Colors.white),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 24),
            AppText(
              'Importing your inventory…',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              '$filename\nAdding items to “$location”',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            AppText(
              'Keep FindEZ open while the file is processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x4DFFFFFF)),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    super.key,
    required this.result,
    required this.location,
    required this.onViewItems,
    required this.onImportAnother,
  });

  final SpreadsheetImportResult result;
  final String location;
  final VoidCallback onViewItems;
  final VoidCallback onImportAnother;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.adaptive(context, Color(0x1A30D158)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: AppTheme.foreground(context, Color(0xFF30D158)),
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            AppText(
              'Import complete',
              style: TextStyle(
                color: AppTheme.foreground(context, Colors.white),
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AppText(
              '${result.inserted} item${result.inserted == 1 ? '' : 's'} added to “$location”.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(context, Color(0x99FFFFFF)),
                fontSize: 15,
              ),
            ),
            if (result.failures > 0) ...[
              const SizedBox(height: 8),
              AppText(
                '${result.failures} row${result.failures == 1 ? '' : 's'} could not be imported.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.foreground(context, Color(0xFFFF9F0A)),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: onViewItems,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.adaptive(context, Colors.white),
                  foregroundColor: AppTheme.adaptive(context, Colors.black),
                  shape: const StadiumBorder(),
                ),
                child: const AppText('View Items'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onImportAnother,
              child: const AppText('Import Another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.adaptive(context, const Color(0x0FFFFFFF)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: AppTheme.foreground(context, const Color(0xB3FFFFFF)),
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Colors.white),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                AppText(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.foreground(context, Color(0x73FFFFFF)),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
