import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/document_link_prefs.dart';
import '../inventory/world_views.dart';
import 'notes_editor_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  bool _loading = true;
  String? _error;
  List<DocumentEntry> _docs = const [];
  Map<String, Map<String, String>> _links = const {};
  String? _busyDocId;

  Map<String, String> _noteContentIndex = const {};
  bool _noteIndexLoading = false;

  late final TextEditingController _search;

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

  Future<void> _prefetchNoteContentIndex(List<DocumentEntry> docs) async {
    try {
      final notes = docs.where(_isNote).toList();
      if (notes.isEmpty) {
        if (!mounted) return;
        setState(() => _noteIndexLoading = false);
        return;
      }

      final next = <String, String>{};
      for (final n in notes) {
        final storagePath = n.documentId;
        if (storagePath.isEmpty) continue;
        try {
          final url = await widget.api.openDocumentUrl(
            storagePath: storagePath,
          );
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            next[storagePath] = utf8.decode(response.bodyBytes).toLowerCase();
          }
        } catch (_) {
          // Best-effort only.
        }
      }

      if (!mounted) return;
      setState(() {
        _noteContentIndex = next;
        _noteIndexLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _noteContentIndex = const {};
        _noteIndexLoading = false;
      });
    }
  }

  DocumentEntry _copyDoc(DocumentEntry d, {String? displayName}) {
    return DocumentEntry(
      documentId: d.documentId,
      filename: d.filename,
      displayName: displayName,
      mimeType: d.mimeType,
      url: d.url,
      createdAt: d.createdAt,
    );
  }

  @override
  void initState() {
    super.initState();
    _search = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final loadedDocs = await widget.api.getDocuments();
      final links = await DocumentLinkPrefs.loadAll();
      final docs = <DocumentEntry>[];
      for (final document in loadedDocs) {
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

      if (!mounted) return;
      setState(() {
        _docs = docs;
        _links = links;
        _noteContentIndex = const {};
        _noteIndexLoading = true;
      });

      unawaited(_prefetchNoteContentIndex(docs));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Couldn’t load documents. Try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      MaterialPageRoute(builder: (_) => NotesEditorPage(api: widget.api)),
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
      final url = await widget.api.openDocumentUrl(storagePath: storagePath);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ensureSignedUrl(DocumentEntry d) async {
    if (d.url != null && (d.url ?? '').isNotEmpty) return d.url;
    final storagePath = d.documentId;
    if (storagePath.isEmpty) return null;
    try {
      return await widget.api.openDocumentUrl(storagePath: storagePath);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDocument(DocumentEntry d) async {
    if (_isNote(d)) {
      final content = await _loadNoteContent(d);
      if (!mounted) return;
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
    if (url == null || url.isEmpty) return;
    if (!mounted) return;

    if (_isImage(d)) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
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
    final controller = TextEditingController(
      text: doc.displayName ?? doc.filename,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rename Document"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: const InputDecoration(hintText: "Document name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.isEmpty) return;

    final nextDocs = _docs
        .map(
          (d) => d.documentId == doc.documentId
              ? _copyDoc(d, displayName: result)
              : d,
        )
        .toList();
    if (mounted) {
      setState(() {
        _docs = nextDocs;
      });
    }

    try {
      await widget.api.renameDocument(
        storagePath: doc.documentId,
        displayName: result,
      );
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t rename. Try again.')),
      );
      await _load();
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t rename. Try again.')),
      );
      await _load();
      return;
    }

    if (!mounted) return;
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
    setState(() => _busyDocId = d.documentId);
    try {
      final msg =
          'Summarize this document in a few short bullets. Document: "${d.filename}". storage_path: "${d.documentId}".';
      final out = await widget.api.aiCommand(message: msg);
      if (!mounted) return;

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
      if (!mounted) return;
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
    final res = await showModalBottomSheet<_LinkResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LinkSheet(document: d, api: widget.api),
    );
    if (res == null) return;

    try {
      await _setBackendLink(storagePath: d.documentId, itemId: res.itemId);
    } on dio.DioException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update link. Try again.')),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t update link. Try again.')),
      );
      return;
    }

    await DocumentLinkPrefs.setLink(
      documentId: d.documentId,
      itemId: res.itemId,
      itemName: res.itemName,
    );

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
    final prev = _links[d.documentId];
    final next = Map<String, Map<String, String>>.from(_links);
    next.remove(d.documentId);
    if (mounted) setState(() => _links = next);

    try {
      await _setBackendLink(storagePath: d.documentId, itemId: null);
      await DocumentLinkPrefs.setLink(
        documentId: d.documentId,
        itemId: null,
        itemName: null,
      );
      await _load();
    } on dio.DioException {
      if (!mounted) return;
      final rollback = Map<String, Map<String, String>>.from(_links);
      if (prev != null) rollback[d.documentId] = prev;
      setState(() => _links = rollback);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t remove link. Try again.')),
      );
    } catch (_) {
      if (!mounted) return;
      final rollback = Map<String, Map<String, String>>.from(_links);
      if (prev != null) rollback[d.documentId] = prev;
      setState(() => _links = rollback);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t remove link. Try again.')),
      );
    }
  }

  Future<void> _uploadDocument() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'txt'],
      );
      if (res == null || res.files.isEmpty) return;

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

      developer.log(
        'UPLOAD START: ${jsonEncode(<String, dynamic>{'filename': safeName, 'mime': mimeType, 'bytes': bytes.length})}',
      );

      final out = await widget.api.uploadDocument(file: file);
      developer.log(
        'UPLOAD RESPONSE: ${jsonEncode(<String, dynamic>{'filename': out.filename, 'activity_summary': out.activitySummary})}',
      );

      if (!mounted) return;
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
    }
  }

  Future<void> _deleteDocument(DocumentEntry d) async {
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
    if (ok != true) return;

    try {
      final storagePath = d.documentId;
      if (storagePath.isEmpty) return;
      await widget.api.deleteDocument(storagePath: storagePath);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t delete. Try again.')),
      );
    }
  }

  Future<void> _documentActions(DocumentEntry document) async {
    final linked = _links[document.documentId] != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final t = AppTokens.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  document.displayName ?? document.filename,
                  style: TextStyle(color: t.ink, fontSize: 20),
                ),
                const SizedBox(height: 12),
                for (final option in <(String, String)>[
                  ('open', 'Open'),
                  ('rename', 'Rename'),
                  ('link', linked ? 'Change linked object' : 'Link to object'),
                  if (linked) ('unlink', 'Remove object link'),
                  ('summary', 'Summarize'),
                  ('delete', 'Delete'),
                ])
                  ListTile(
                    title: Text(option.$2),
                    onTap: () => Navigator.pop(context, option.$1),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case 'open':
        await _openDocument(document);
      case 'rename':
        await _renameDocument(document);
      case 'link':
        await _link(document);
      case 'unlink':
        await _removeLinkedItem(document);
      case 'summary':
        await _summarize(document);
      case 'delete':
        await _deleteDocument(document);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final q = _search.text.trim().toLowerCase();
    final filtered = _docs.where((document) {
      if (q.isEmpty) return true;
      return (document.displayName ?? document.filename).toLowerCase().contains(
            q,
          ) ||
          document.filename.toLowerCase().contains(q) ||
          (_noteContentIndex[document.documentId]?.contains(q) ?? false);
    }).toList();
    final groups = <(String, List<DocumentEntry>)>[
      ('Images', filtered.where(_isImage).toList()),
      (
        'PDFs and notes',
        filtered
            .where((d) => !_isImage(d) && (_isPdf(d) || _isText(d)))
            .toList(),
      ),
      (
        'Other',
        filtered
            .where((d) => !_isImage(d) && !_isPdf(d) && !_isText(d))
            .toList(),
      ),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(
              title: 'Documents',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).pop()
                  : null,
              actions: [
                TextButton(
                  onPressed: _uploadDocument,
                  child: const Text('Add'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Find a document'),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: t.text2)),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        children: [
                          if (_docs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'No documents yet. Add a file or write a note.',
                                style: TextStyle(color: t.text2, fontSize: 15),
                              ),
                            )
                          else if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                _noteIndexLoading
                                    ? 'Searching notes…'
                                    : 'No documents match that search.',
                                style: TextStyle(color: t.text2, fontSize: 15),
                              ),
                            ),
                          for (final group in groups)
                            if (group.$2.isNotEmpty)
                              WorldSection(
                                title: group.$1,
                                children: [
                                  for (final document in group.$2)
                                    WorldRow(
                                      title:
                                          document.displayName ??
                                          document.filename,
                                      subtitle:
                                          _busyDocId == document.documentId
                                          ? 'Summarizing…'
                                          : _links[document
                                                    .documentId]?['item_name'] ==
                                                null
                                          ? _formatDate(document.createdAt)
                                          : 'Linked to ${_links[document.documentId]!['item_name']}',
                                      count: _typeLabel(document).toUpperCase(),
                                      onTap: () => _openDocument(document),
                                      onLongPress: () =>
                                          _documentActions(document),
                                    ),
                                ],
                              ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _newNote,
                            child: const Text('Write a note'),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkResult {
  const _LinkResult({required this.itemId, required this.itemName});

  final String? itemId;
  final String? itemName;
}

class _LinkSheet extends StatefulWidget {
  const _LinkSheet({required this.document, required this.api});

  final DocumentEntry document;
  final ApiClient api;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  late final TextEditingController _q;
  bool _loading = true;
  String? _error;
  List<InventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load objects.';
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
    final t = AppTokens.of(context);
    final query = _q.text.trim().toLowerCase();
    final rows = query.isEmpty
        ? _items
        : _items
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    item.category.toLowerCase().contains(query),
              )
              .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Link to object',
              style: TextStyle(color: t.ink, fontSize: 22),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Find an object'),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: t.text2)),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : rows.isEmpty
                  ? Center(
                      child: Text(
                        'No objects match.',
                        style: TextStyle(color: t.text2),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        return WorldRow(
                          title: item.name,
                          subtitle: item.category,
                          count: '${item.quantity}',
                          onTap: () => Navigator.pop(
                            context,
                            _LinkResult(
                              itemId: item.itemId,
                              itemName: item.name,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                const _LinkResult(itemId: null, itemName: null),
              ),
              child: const Text('Remove link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
