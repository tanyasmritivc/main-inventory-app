import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/app_colors.dart';

class TeamDocumentsPage extends StatefulWidget {
  const TeamDocumentsPage({super.key, required this.api, required this.teamId});

  final ApiClient api;
  final String teamId;

  @override
  State<TeamDocumentsPage> createState() => _TeamDocumentsPageState();
}

class _TeamDocumentsPageState extends State<TeamDocumentsPage> {
  static const _maxBytes = 50 * 1024 * 1024;

  bool _loading = true;
  bool _uploading = false;
  String? _error;
  String _role = 'viewer';
  List<Map<String, dynamic>> _documents = const [];

  bool get _canUpload => _role != 'viewer';
  bool get _canManage => _role == 'owner' || _role == 'mentor';
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.getTeamDocuments(widget.teamId);
      if (!mounted) return;
      setState(() {
        _documents = List<Map<String, dynamic>>.from(
          result['documents'] ?? const [],
        );
        _role = result['role']?.toString() ?? 'viewer';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = describeError(error).$1;
        _loading = false;
      });
    }
  }

  Future<void> _chooseUploadSource() async {
    if (_uploading || !_canUpload) return;
    HapticFeedback.selectionClick();
    final source = await showModalBottomSheet<_DocumentSource>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(CupertinoIcons.photo_on_rectangle),
                title: const Text('Photo Library'),
                subtitle: const Text('Photos and videos'),
                onTap: () =>
                    Navigator.pop(sheetContext, _DocumentSource.photoLibrary),
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.folder),
                title: const Text('Files'),
                subtitle: const Text('Documents, spreadsheets, and more'),
                onTap: () => Navigator.pop(sheetContext, _DocumentSource.files),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || source == null) return;
    switch (source) {
      case _DocumentSource.photoLibrary:
        await _pickGalleryAndUpload();
      case _DocumentSource.files:
        await _pickFileAndUpload();
    }
  }

  Future<void> _pickGalleryAndUpload() async {
    final media = await ImagePicker().pickMedia();
    if (media == null || !mounted) return;
    final size = await media.length();
    await _upload(
      filename: media.name,
      size: size,
      multipart: () =>
          dio.MultipartFile.fromFile(media.path, filename: media.name),
    );
  }

  Future<void> _pickFileAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    await _upload(
      filename: file.name,
      size: file.size,
      multipart: () => _multipartFile(file),
    );
  }

  Future<void> _upload({
    required String filename,
    required int size,
    required Future<dio.MultipartFile> Function() multipart,
  }) async {
    if (size <= 0) {
      _showMessage('That file is empty.');
      return;
    }
    if (size > _maxBytes) {
      _showMessage('Choose a file smaller than 50 MB.');
      return;
    }

    setState(() => _uploading = true);
    try {
      final upload = await multipart();
      final document = await widget.api.uploadTeamDocument(
        widget.teamId,
        upload,
      );
      if (!mounted) return;
      setState(() {
        _documents = [document, ..._documents];
        _uploading = false;
      });
      HapticFeedback.mediumImpact();
      _showMessage('File added');
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _showMessage(describeError(error).$1);
    }
  }

  Future<dio.MultipartFile> _multipartFile(PlatformFile file) async {
    final path = file.path;
    if (path != null && path.isNotEmpty) {
      return dio.MultipartFile.fromFile(path, filename: file.name);
    }
    final Uint8List? bytes = file.bytes;
    if (bytes == null) throw StateError('The selected file could not be read.');
    return dio.MultipartFile.fromBytes(bytes, filename: file.name);
  }

  Future<void> _open(Map<String, dynamic> document) async {
    HapticFeedback.selectionClick();
    try {
      final id = document['team_document_id']?.toString() ?? '';
      final url = await widget.api.openTeamDocumentUrl(widget.teamId, id);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('The file could not be opened.');
      }
    } catch (error) {
      if (mounted) _showMessage(describeError(error).$1);
    }
  }

  Future<void> _delete(Map<String, dynamic> document) async {
    final filename = document['filename']?.toString() ?? 'this file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('$filename will be removed for everyone on this team.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final id = document['team_document_id']?.toString() ?? '';
      await widget.api.deleteTeamDocument(widget.teamId, id);
      if (!mounted) return;
      setState(
        () => _documents = _documents
            .where((entry) => entry['team_document_id']?.toString() != id)
            .toList(),
      );
      HapticFeedback.mediumImpact();
      _showMessage('File deleted');
    } catch (error) {
      if (mounted) _showMessage(describeError(error).$1);
    }
  }

  bool _canDelete(Map<String, dynamic> document) {
    return _canManage || document['uploaded_by']?.toString() == _userId;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          if (_canUpload && !_loading)
            IconButton(
              tooltip: 'Add file',
              onPressed: _uploading ? null : _chooseUploadSource,
              icon: const Icon(CupertinoIcons.plus),
            ),
        ],
        bottom: _uploading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: _documents.isEmpty
                  ? _EmptyState(
                      canUpload: _canUpload,
                      onAdd: _chooseUploadSource,
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
                      itemCount: _documents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final document = _documents[index];
                        return _DocumentRow(
                          document: document,
                          canDelete: _canDelete(document),
                          onOpen: () => _open(document),
                          onDelete: () => _delete(document),
                        );
                      },
                    ),
            ),
    );
  }
}

enum _DocumentSource { photoLibrary, files }

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  final Map<String, dynamic> document;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  String get _filename => document['filename']?.toString() ?? 'Untitled file';

  ({IconData icon, Color color}) get _appearance {
    final name = _filename.toLowerCase();
    final mime = document['mime_type']?.toString().toLowerCase() ?? '';
    if (mime.startsWith('image/') ||
        name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return (icon: CupertinoIcons.photo, color: const Color(0xFFB9A4E8));
    }
    if (mime == 'application/pdf' || name.endsWith('.pdf')) {
      return (icon: CupertinoIcons.doc_text, color: const Color(0xFFE5A0A9));
    }
    if (name.endsWith('.csv') ||
        name.endsWith('.xls') ||
        name.endsWith('.xlsx')) {
      return (icon: CupertinoIcons.table, color: const Color(0xFF8FCBB6));
    }
    if (name.endsWith('.zip') || name.endsWith('.rar')) {
      return (icon: CupertinoIcons.archivebox, color: const Color(0xFFE8B184));
    }
    return (icon: CupertinoIcons.doc, color: const Color(0xFF9FC3E8));
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance;
    final size = _formatBytes(document['size_bytes']);
    final date = _formatDate(document['created_at']?.toString());
    return Material(
      color: const Color(0xFF19191B),
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        minVerticalPadding: 16,
        contentPadding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
        leading: Icon(appearance.icon, color: appearance.color, size: 25),
        title: Text(
          _filename,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [size, date].where((value) => value.isNotEmpty).join(' · '),
        ),
        trailing: canDelete
            ? PopupMenuButton<String>(
                tooltip: 'File options',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              )
            : const Icon(
                CupertinoIcons.chevron_forward,
                color: AppColors.muted,
                size: 16,
              ),
        onTap: onOpen,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canUpload, required this.onAdd});

  final bool canUpload;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 36),
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .23),
      const Icon(CupertinoIcons.doc_on_doc, size: 40, color: Colors.white),
      const SizedBox(height: 20),
      const Text(
        'No files yet',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Shared files will appear here.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
      if (canUpload) ...[
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(CupertinoIcons.plus),
            label: const Text('Add file'),
          ),
        ),
      ],
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Couldn’t load files',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _formatBytes(dynamic value) {
  final bytes = value is int ? value : int.tryParse(value?.toString() ?? '');
  if (bytes == null || bytes < 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '')?.toLocal();
  if (date == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
