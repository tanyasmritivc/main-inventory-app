import 'package:mobile/core/ui/glass_control.dart';
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
          title: const AppText('Import spreadsheet'),
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
        AppText(
          'Save to',
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        AppText(
          location,
          style: TextStyle(
            color: AppTheme.textPrimary(context),
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onChooseFile,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const AppText('Choose file'),
          ),
        ),
        const SizedBox(height: 12),
        AppText(
          'Excel (.xlsx) or CSV, up to 10 MB',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 20),
          AppText(
            errorMessage!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 14,
            ),
          ),
        ],
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
                style: GlassControl.buttonStyle(
                  context,
                  radius: 99,
                  base: FilledButton.styleFrom(shape: const StadiumBorder()),
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
