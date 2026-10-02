import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/document_link_prefs.dart';
import '../../core/config.dart';
import '../../core/ui/skeleton.dart';
import '../home/home_overview.dart';
import 'notes_editor_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({
    super.key,
    required this.api,
    this.ownerId,
    this.contentClient,
  });

  final ApiClient api;
  final String? Function()? ownerId;
  final http.Client? contentClient;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  bool _loading = true;
  String? _error;
  List<DocumentEntry> _docs = const [];
  Map<String, Map<String, String>> _links = const {};
  String? _busyDocId;
  bool _uploading = false;
  int _generation = 0;
  String? _owner;
  StreamSubscription<AuthState>? _auth;
  late final http.Client _contentClient;
  String? get _currentOwner =>
      widget.ownerId?.call() ?? Supabase.instance.client.auth.currentUser?.id;

  Map<String, String> _noteContentIndex = const {};
  bool _noteIndexLoading = false;

  late final TextEditingController _search;
  bool _openImages = true;
  bool _openPdfs = true;
  bool _openOther = true;
  bool _openNotes = true;

  String? _trustedUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    final owner = _currentOwner;
    if (owner == null ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    final origins = [widget.api.baseUrl, AppConfig.supabaseUrl];
    if (!origins.any((origin) {
      final allowed = Uri.tryParse(origin);
      return allowed?.hasAuthority == true && allowed!.origin == uri.origin;
    })) {
      return null;
    }
    final p = uri.pathSegments;
    if (p.length < 7 ||
        p[0] != 'storage' ||
        p[1] != 'v1' ||
        p[2] != 'object' ||
        !{'sign', 'public'}.contains(p[3]) ||
        p[4] != 'documents' ||
        p[5] != owner ||
        p
            .skip(6)
            .any(
              (part) =>
                  part == '..' ||
                  part == '.' ||
                  part.contains('/') ||
                  part.contains('\\'),
            )) {
      return null;
    }
    return uri.toString();
  }

  bool _isVideoFile(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  bool _isText(DocumentEntry d) {
    final mime = (d.mimeType ?? '').toLowerCase();
    if (mime.contains('text')) return true;
    return d.filename.toLowerCase().endsWith('.txt');
  }

  bool _isNote(DocumentEntry d) {
    if (!_isText(d)) return false;
    final f = d.filename.toLowerCase();
    return f.startsWith('note-') && f.endsWith('.txt');
  }

  Future<void> _prefetchNoteContentIndex(
    List<DocumentEntry> docs,
    int generation,
    String? owner,
  ) async {
    bool current() =>
        mounted && generation == _generation && owner == _currentOwner;
    try {
      final notes = docs.where(_isNote).toList();
      if (notes.isEmpty) {
        if (!current()) return;
        setState(() => _noteIndexLoading = false);
        return;
      }

      final next = <String, String>{};
      for (final n in notes) {
        final storagePath = n.documentId;
        if (storagePath.isEmpty) continue;
        try {
          final url = _trustedUrl(
            await widget.api.openDocumentUrl(storagePath: storagePath),
          );
          if (!current()) return;
          if (url == null) continue;
          final response = await _contentClient.get(Uri.parse(url));
          if (response.statusCode == 200) {
            next[storagePath] = utf8.decode(response.bodyBytes).toLowerCase();
          }
        } catch (_) {
          // Best-effort only.
        }
      }

      if (!current()) return;
      setState(() {
        _noteContentIndex = next;
        _noteIndexLoading = false;
      });
    } catch (_) {
      if (!current()) return;
      setState(() {
        _noteContentIndex = const {};
        _noteIndexLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _contentClient = widget.contentClient ?? http.Client();
    _owner = _currentOwner;
    _auth = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      if (!mounted || _owner == _currentOwner) return;
      _owner = _currentOwner;
      _generation++;
      _search.clear();
      setState(() {
        _docs = [];
        _links = {};
        _noteContentIndex = {};
        _error = null;
        _loading = false;
        _noteIndexLoading = false;
      });
      if (_owner != null) unawaited(_load());
    });
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _auth?.cancel();
    _generation++;
    if (widget.contentClient == null) _contentClient.close();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_generation;
    final owner = _currentOwner;
    bool current() =>
        mounted && generation == _generation && owner == _currentOwner;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loadedDocs = await widget.api.getDocuments();
      if (!current()) return;
      final links = await DocumentLinkPrefs.loadAll();
      if (!current()) return;
      final docs = <DocumentEntry>[];
      for (final document in loadedDocs) {
        if (!current()) return;
        var url = document.url;
        final mime = (document.mimeType ?? '').toLowerCase();
        if ((url ?? '').isEmpty && mime.startsWith('image/')) {
          try {
            url = await widget.api.openDocumentUrl(
              storagePath: document.documentId,
            );
          } catch (_) {
            url = null;
          }
        }
        docs.add(
          DocumentEntry(
            documentId: document.documentId,
            filename: document.filename,
            displayName: document.displayName,
            mimeType: document.mimeType,
            url: url,
            createdAt: document.createdAt,
          ),
        );
      }

      if (!current()) return;
      setState(() {
        _docs = docs;
        _links = links;
        _noteContentIndex = const {};
        _noteIndexLoading = true;
      });

      unawaited(_prefetchNoteContentIndex(docs, generation, owner));
    } catch (e) {
      if (!current()) return;
      setState(() => _error = "Couldn't load documents. Try again.");
    } finally {
      if (current()) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final trusted = _trustedUrl(url);
      if (trusted == null ||
          !await launchUrl(
            Uri.parse(trusted),
            mode: LaunchMode.externalApplication,
          )) {
        throw StateError('Document could not open');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open document. Try again.")),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  bool _isPdf(DocumentEntry d) {
    final mime = (d.mimeType ?? '').toLowerCase();
    if (mime.contains('pdf')) return true;
    return d.filename.toLowerCase().endsWith('.pdf');
  }

  bool _isImage(DocumentEntry d) {
    final mime = (d.mimeType ?? '').toLowerCase();
    if (mime.contains('image')) return true;
    final lower = d.filename.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  String _typeLabel(DocumentEntry d) {
    final mime = (d.mimeType ?? '').toLowerCase();
    if (mime.contains('image')) return 'Image';
    if (mime.contains('pdf')) return 'PDF';
    if (mime.contains('text')) return 'Text';
    return 'File';
  }

  bool _isAllowedUpload(String filename, String mimeType) {
    final lowerName = filename.toLowerCase();
    final lowerMime = mimeType.toLowerCase();

    final isImage =
        lowerMime.contains('image') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png');
    if (isImage) {
      return lowerName.endsWith('.jpg') ||
          lowerName.endsWith('.jpeg') ||
          lowerName.endsWith('.png');
    }

    final isPdf = lowerMime == 'application/pdf' || lowerName.endsWith('.pdf');
    if (isPdf) return true;

    final isText = lowerMime.contains('text') || lowerName.endsWith('.txt');
    if (isText) return true;

    return false;
  }

  Future<void> _newNote() async {
    final didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            NotesEditorPage(api: widget.api, ownerId: () => _currentOwner),
      ),
    );
    if (didSave == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note saved successfully')));
      await _load();
    }
  }

  Future<String?> _loadNoteContent(DocumentEntry d) async {
    final storagePath = d.documentId;
    if (storagePath.isEmpty) return null;
    try {
      final owner = _currentOwner;
      final url = _trustedUrl(
        await widget.api.openDocumentUrl(storagePath: storagePath),
      );
      if (url == null || owner != _currentOwner) return null;
      final response = await _contentClient.get(Uri.parse(url));
      if (owner != _currentOwner) return null;
      if (response.statusCode != 200) return null;
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ensureSignedUrl(DocumentEntry d) async {
    final storagePath = d.documentId;
    if (storagePath.isEmpty) return null;
    try {
      final owner = _currentOwner;
      final url = await widget.api.openDocumentUrl(storagePath: storagePath);
      return owner == _currentOwner ? _trustedUrl(url) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDocument(DocumentEntry d) async {
    final owner = _currentOwner;
    if (_isNote(d)) {
      final content = await _loadNoteContent(d);
      if (!mounted || owner != _currentOwner) return;
      if (content == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn’t open note.')));
        return;
      }

      final didSave = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => NotesEditorPage(
            api: widget.api,
            ownerId: () => _currentOwner,
            note: Note(
              id: d.documentId,
              storagePath: d.documentId,
              content: content,
              filename: d.filename,
              displayName: d.displayName,
            ),
          ),
        ),
      );
      if (didSave == true) {
        await _load();
      }
      return;
    }

    final url = await _ensureSignedUrl(d);
    if (url == null || url.isEmpty) {
      if (mounted && owner == _currentOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open document. Try again.")),
        );
      }
      return;
    }
    if (!mounted || owner != _currentOwner) return;

    if (_isImage(d)) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Photo unavailable.'),
                  ),
                ),
              ),
            ),
          );
        },
      );
      return;
    }

    await _openUrl(url);
  }

  Future<void> _renameDocument(DocumentEntry doc) async {
    final owner = _currentOwner;
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _RenameDocumentDialog(name: doc.displayName ?? doc.filename),
    );

    if (result == null ||
        result.isEmpty ||
        !mounted ||
        owner != _currentOwner) {
      return;
    }

    try {
      await widget.api.renameDocument(
        storagePath: doc.documentId,
        displayName: result,
      );
    } on dio.DioException {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t rename. Try again.')),
      );
      await _load();
      return;
    } catch (_) {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t rename. Try again.')),
      );
      await _load();
      return;
    }

    if (!mounted || owner != _currentOwner) return;
    await _load();
  }

  Future<void> _setBackendLink({
    required String storagePath,
    String? itemId,
  }) async {
    await widget.api.linkDocument(storagePath: storagePath, itemId: itemId);
  }

  Future<void> _summarize(DocumentEntry d) async {
    if (!mounted) return;
    final owner = _currentOwner;
    setState(() => _busyDocId = d.documentId);
    try {
      final msg =
          'Summarize this document in a few short bullets. Document: "${d.filename}". storage_path: "${d.documentId}".';
      final out = await widget.api.aiCommand(message: msg);
      if (!mounted || owner != _currentOwner) return;

      final text = out.assistantMessage.trim().isEmpty
          ? 'No summary available.'
          : out.assistantMessage.trim();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Summary'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t summarize. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDocId = null);
      }
    }
  }

  Future<void> _link(DocumentEntry d) async {
    final owner = _currentOwner;
    final res = await showModalBottomSheet<_LinkResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomeColors.surface,
      builder: (context) => _LinkSheet(
        document: d,
        api: widget.api,
        ownerId: () => _currentOwner,
      ),
    );
    if (res == null || !mounted || owner != _currentOwner) return;

    try {
      await _setBackendLink(storagePath: d.documentId, itemId: res.itemId);
    } on dio.DioException {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update link. Try again.')),
      );
      return;
    } catch (_) {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update link. Try again.')),
      );
      return;
    }

    if (!mounted || owner != _currentOwner) return;
    try {
      await DocumentLinkPrefs.setLink(
        documentId: d.documentId,
        itemId: res.itemId,
        itemName: res.itemName,
      );
    } catch (_) {
      if (mounted && owner == _currentOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Link saved, but could not refresh its label. Try again.',
            ),
          ),
        );
      }
    }
    if (!mounted || owner != _currentOwner) return;

    final next = Map<String, Map<String, String>>.from(_links);
    if (res.itemId == null || (res.itemId ?? '').trim().isEmpty) {
      next.remove(d.documentId);
    } else {
      next[d.documentId] = {
        'item_id': res.itemId!,
        if (res.itemName != null) 'item_name': res.itemName!,
      };
    }
    if (mounted) setState(() => _links = next);
    await _load();
  }

  Future<void> _removeLinkedItem(DocumentEntry d) async {
    final owner = _currentOwner;
    try {
      await _setBackendLink(storagePath: d.documentId, itemId: null);
    } catch (_) {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't remove link. Try again.")),
      );
      return;
    }
    if (!mounted || owner != _currentOwner) return;
    final next = Map<String, Map<String, String>>.from(_links)
      ..remove(d.documentId);
    setState(() => _links = next);
    try {
      await DocumentLinkPrefs.setLink(
        documentId: d.documentId,
        itemId: null,
        itemName: null,
      );
    } catch (_) {
      if (mounted && owner == _currentOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Link removed, but could not refresh its label. Try again.',
            ),
          ),
        );
      }
      return;
    }
    if (mounted && owner == _currentOwner) await _load();
  }

  Future<void> _uploadDocument() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final owner = _currentOwner;
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'txt'],
      );
      if (res == null ||
          res.files.isEmpty ||
          !mounted ||
          owner != _currentOwner) {
        return;
      }

      final f = res.files.first;
      final name = (f.name).trim();
      if (name.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again.')),
        );
        return;
      }
      if (_isVideoFile(name)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Videos aren’t supported.')),
        );
        return;
      }

      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again.')),
        );
        return;
      }

      final safeName = name.replaceAll('/', '_').replaceAll('\\', '_');
      final mimeType = _guessMimeType(safeName);

      if (!_isAllowedUpload(safeName, mimeType)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File type not supported.')),
        );
        return;
      }

      final media = MediaType.parse(mimeType);
      final file = dio.MultipartFile.fromBytes(
        bytes,
        filename: safeName,
        contentType: media,
      );

      await widget.api.uploadDocument(file: file);

      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document uploaded successfully')),
      );
      await _load();
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteDocument(DocumentEntry d) async {
    final owner = _currentOwner;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(d.filename),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || owner != _currentOwner) return;

    try {
      final storagePath = d.documentId;
      if (storagePath.isEmpty) return;
      await widget.api.deleteDocument(storagePath: storagePath);
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _load();
    } catch (e) {
      if (!mounted || owner != _currentOwner) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t delete. Try again.')),
      );
    }
  }

  Widget _documentRow(DocumentEntry document) {
    final title = (document.displayName ?? '').trim().isEmpty
        ? document.filename
        : document.displayName!.trim();
    final linked = _links[document.documentId];
    final linkedName = linked?['item_name']?.trim() ?? '';
    final busy = _busyDocId == document.documentId;
    final imageUrl = _trustedUrl(document.url);
    return Dismissible(
      key: ValueKey(document.documentId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: const Color(0xFF35191B),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        await _deleteDocument(document);
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _isImage(document) && imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: HomeColors.secondary,
                      ),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HomeColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        subtitle: Text(
          '${_isNote(document) ? 'Note' : _typeLabel(document)} - ${_formatDate(document.createdAt)}'
          '${linkedName.isEmpty ? '' : '\nLinked to $linkedName'}',
          style: const TextStyle(
            color: HomeColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        onTap: busy ? null : () => _openDocument(document),
        trailing: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : PopupMenuButton<String>(
                tooltip: 'Actions for $title',
                icon: const Icon(Icons.more_horiz, color: HomeColors.secondary),
                onSelected: (value) async {
                  switch (value) {
                    case 'open':
                      await _openDocument(document);
                    case 'rename':
                      await _renameDocument(document);
                    case 'summarize':
                      await _summarize(document);
                    case 'link':
                      await _link(document);
                    case 'unlink':
                      await _removeLinkedItem(document);
                    case 'delete':
                      await _deleteDocument(document);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(
                    value: 'summarize',
                    child: Text('Summarize'),
                  ),
                  const PopupMenuItem(
                    value: 'link',
                    child: Text('Link to item'),
                  ),
                  if ((linked?['item_id'] ?? '').isNotEmpty)
                    const PopupMenuItem(
                      value: 'unlink',
                      child: Text('Remove link'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
      ),
    );
  }

  Widget _section(
    String title,
    List<DocumentEntry> documents,
    bool open,
    VoidCallback toggle,
  ) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      children: [
        TextButton(
          onPressed: toggle,
          style: TextButton.styleFrom(
            foregroundColor: HomeColors.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                documents.length.toString(),
                style: const TextStyle(fontWeight: FontWeight.w400),
              ),
              const SizedBox(width: 10),
              Icon(open ? Icons.expand_more : Icons.chevron_right, size: 18),
            ],
          ),
        ),
        if (open)
          Material(
            color: HomeColors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < documents.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: Color(0xFF2A2A2E),
                      indent: 16,
                      endIndent: 16,
                    ),
                  _documentRow(documents[i]),
                ],
              ],
            ),
          ),
      ],
    ),
  );

  Widget _status(String text, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: HomeColors.secondary,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (retry) TextButton(onPressed: _load, child: const Text('Retry')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _docs
        .where(
          (d) =>
              query.isEmpty ||
              (d.displayName ?? '').toLowerCase().contains(query) ||
              d.filename.toLowerCase().contains(query) ||
              (_isNote(d) &&
                  (_noteContentIndex[d.documentId] ?? '').contains(query)),
        )
        .toList();
    final images = filtered.where(_isImage).toList();
    final notes = filtered.where(_isNote).toList();
    final pdfs = filtered.where(_isPdf).toList();
    final files = filtered
        .where((d) => !_isImage(d) && !_isNote(d) && !_isPdf(d))
        .toList();
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Documents',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !_uploading,
            tooltip: 'Add document',
            onSelected: (value) {
              if (value == 'note') unawaited(_newNote());
              if (value == 'upload') unawaited(_uploadDocument());
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'note', child: Text('New note')),
              PopupMenuItem(value: 'upload', child: Text('Upload file')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                _uploading ? 'Uploading...' : 'Add',
                style: const TextStyle(
                  color: HomeColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                color: HomeColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Search documents and notes',
                hintStyle: const TextStyle(
                  color: HomeColors.hint,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: HomeColors.surface,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: HomeColors.secondary),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _status(_error!, retry: true)
            else if (_docs.isEmpty)
              _status('No documents yet.\nAdd a note or upload a file.')
            else if (filtered.isEmpty)
              _status(
                _noteIndexLoading
                    ? 'Searching note contents...'
                    : 'No matching documents or notes.',
              )
            else ...[
              if (notes.isNotEmpty)
                _section(
                  'Notes',
                  notes,
                  _openNotes,
                  () => setState(() => _openNotes = !_openNotes),
                ),
              if (pdfs.isNotEmpty)
                _section(
                  'PDFs',
                  pdfs,
                  _openPdfs,
                  () => setState(() => _openPdfs = !_openPdfs),
                ),
              if (images.isNotEmpty)
                _section(
                  'Images',
                  images,
                  _openImages,
                  () => setState(() => _openImages = !_openImages),
                ),
              if (files.isNotEmpty)
                _section(
                  'Files',
                  files,
                  _openOther,
                  () => setState(() => _openOther = !_openOther),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RenameDocumentDialog extends StatefulWidget {
  const _RenameDocumentDialog({required this.name});
  final String name;
  @override
  State<_RenameDocumentDialog> createState() => _RenameDocumentDialogState();
}

class _RenameDocumentDialogState extends State<_RenameDocumentDialog> {
  late final TextEditingController _name;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename document'),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 200,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: const InputDecoration(hintText: 'Document name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _name.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _LinkResult {
  const _LinkResult({required this.itemId, required this.itemName});

  final String? itemId;
  final String? itemName;
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({
    required this.document,
    required this.api,
    required this.ownerId,
  });

  final DocumentEntry document;
  final ApiClient api;
  final String? Function() ownerId;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _q;
  bool _loading = true;
  bool _failed = false;
  List<InventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final owner = widget.ownerId();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted || owner != widget.ownerId()) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || owner != widget.ownerId()) return;
      setState(() {
        _failed = true;
        _items = const [];
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final query = _q.text.trim().toLowerCase();
    final rows = query.isEmpty
        ? _items
        : _items
              .where(
                (it) =>
                    it.name.toLowerCase().contains(query) ||
                    it.category.toLowerCase().contains(query),
              )
              .toList();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Link to inventory item',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search items',
                  filled: true,
                  fillColor: HomeColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HomeColors.secondary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const SizedBox(
                  height: 220,
                  child: Center(
                    child: SkeletonBox(
                      height: 14,
                      width: 160,
                      borderRadius: 10,
                    ),
                  ),
                )
              else if (_failed)
                Column(
                  children: [
                    const Text("Couldn't load items. Try again."),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Material(
                    color: HomeColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: rows.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No matches.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: rows.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final it = rows[index];
                              return ListTile(
                                dense: true,
                                title: Text(it.name),
                                subtitle: Text(
                                  it.category,
                                  style: const TextStyle(
                                    color: HomeColors.secondary,
                                  ),
                                ),
                                onTap: () => Navigator.of(context).pop(
                                  _LinkResult(
                                    itemId: it.itemId,
                                    itemName: it.name,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _LinkResult(itemId: null, itemName: null)),
                child: const Text('Remove link'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
