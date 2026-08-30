import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/document_link_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';
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
  bool _openImages = true;
  bool _openPdfs = true;
  bool _openOther = false;

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
          final url = await widget.api.openDocumentUrl(storagePath: storagePath);
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
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
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

    final isImage = lowerMime.contains('image') ||
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
        builder: (_) => NotesEditorPage(api: widget.api),
      ),
    );
    if (didSave == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved successfully')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open note.')),
        );
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
    await widget.api.linkDocument(
      storagePath: storagePath,
      itemId: itemId,
    );
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
        'UPLOAD START: ${jsonEncode(<String, dynamic>{
          'filename': safeName,
          'mime': mimeType,
          'bytes': bytes.length,
        })}',
      );

      final out = await widget.api.uploadDocument(file: file);
      developer.log(
        'UPLOAD RESPONSE: ${jsonEncode(<String, dynamic>{
          'filename': out.filename,
          'activity_summary': out.activitySummary,
        })}',
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

  @override
  Widget build(BuildContext context) {
    const accent = LinearGradient(
      colors: [
        Color(0xFF5EEAD4),
        Color(0xFF5E5CE6),
        Color(0xFFC084FC),
        Color(0xFFF472B6),
        Color(0xFFFCA5A5),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _docs
        : _docs.where((d) {
            final name = (d.displayName ?? '').toLowerCase();
            final file = d.filename.toLowerCase();
            if (name.contains(q) || file.contains(q)) return true;
            if (_isNote(d)) {
              final content = _noteContentIndex[d.documentId];
              if (content != null && content.contains(q)) return true;
            }
            return false;
          }).toList();

    final noSearchResults = q.isNotEmpty && filtered.isEmpty;

    final images = filtered.where(_isImage).toList();
    final files = filtered
        .where((d) => !_isImage(d) && (_isPdf(d) || _isText(d)))
        .toList();
    final other = filtered
        .where((d) => !_isImage(d) && !_isPdf(d) && !_isText(d))
        .toList();

    final sections = <({String title, List<DocumentEntry> docs, bool open})>[
      (title: 'Images', docs: images, open: _openImages),
      (title: 'PDFs', docs: files, open: _openPdfs),
      (title: 'Other', docs: other, open: _openOther),
    ].where((s) => s.docs.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Documents'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _newNote,
            icon: ShaderMask(
              shaderCallback: (rect) => accent.createShader(rect),
              blendMode: BlendMode.srcIn,
              child: const Icon(Icons.note_add_outlined, color: Colors.white),
            ),
          ),
          IconButton(
            onPressed: _uploadDocument,
            icon: ShaderMask(
              shaderCallback: (rect) => accent.createShader(rect),
              blendMode: BlendMode.srcIn,
              child: const Icon(Icons.upload_file, color: Colors.white),
            ),
          ),
          ShaderMask(
            shaderCallback: (rect) => accent.createShader(rect),
            blendMode: BlendMode.srcIn,
            child: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ),
        ],
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        itemCount: 8,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) => const SkeletonListTile(),
                      ),
                    ),
                  ),
                )
              : _error != null
                  ? Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : (_docs.isEmpty
                      ? Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'No documents yet.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.70),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                hintText: 'Search documents…',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ListView(
                                      children: [
                                        if (noSearchResults)
                                          ListTile(
                                            dense: true,
                                            title: Text(
                                              _noteIndexLoading
                                                  ? 'Searching notes…'
                                                  : 'No notes found.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.70,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          for (final s in sections) ...[
                                            ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              title: Text(
                                                s.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: Colors.white.withValues(
                                                        alpha: 0.70,
                                                      ),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                              trailing: Icon(
                                                s.open
                                                    ? Icons.expand_more
                                                    : Icons.chevron_right,
                                                color: Colors.white.withValues(
                                                  alpha: 0.70,
                                                ),
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  if (s.title == 'Images') {
                                                    _openImages = !_openImages;
                                                  }
                                                  if (s.title == 'PDFs') {
                                                    _openPdfs = !_openPdfs;
                                                  }
                                                  if (s.title == 'Other') {
                                                    _openOther = !_openOther;
                                                  }
                                                });
                                              },
                                            ),
                                            if (s.open)
                                              for (final d in s.docs) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final linked = _links[d.documentId];
                                                    final linkedName =
                                                        linked?['item_name'];

                                                    final isBusy =
                                                        _busyDocId == d.documentId;
                                                    final leading = _isImage(d)
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(10),
                                                            child: Container(
                                                              width: 42,
                                                              height: 42,
                                                              color: Colors.white
                                                                  .withValues(
                                                                alpha: 0.06,
                                                              ),
                                                              child:
                                                                  (d.url != null &&
                                                                          (d.url ?? '')
                                                                              .isNotEmpty)
                                                                      ? Image.network(
                                                                          d.url!,
                                                                          fit: BoxFit.cover,
                                                                          errorBuilder: (
                                                                            context,
                                                                            error,
                                                                            stackTrace,
                                                                          ) => Icon(
                                                                            Icons.image_outlined,
                                                                            color: Colors.white
                                                                                .withValues(
                                                                              alpha: 0.70,
                                                                            ),
                                                                          ),
                                                                          loadingBuilder: (
                                                                            context,
                                                                            child,
                                                                            loadingProgress,
                                                                          ) {
                                                                            if (loadingProgress ==
                                                                                null) {
                                                                              return child;
                                                                            }
                                                                            return Center(
                                                                              child: Icon(
                                                                                Icons.image_outlined,
                                                                                color: Colors.white
                                                                                    .withValues(
                                                                                  alpha: 0.55,
                                                                                ),
                                                                              ),
                                                                            );
                                                                          },
                                                                        )
                                                                      : Icon(
                                                                          Icons.image_outlined,
                                                                          color: Colors.white
                                                                              .withValues(
                                                                            alpha: 0.70,
                                                                          ),
                                                                        ),
                                                            ),
                                                          )
                                                        : Icon(
                                                            _isPdf(d)
                                                                ? Icons
                                                                    .picture_as_pdf_outlined
                                                                : Icons
                                                                    .insert_drive_file_outlined,
                                                            color: Colors.white
                                                                .withValues(alpha: 0.70),
                                                          );

                                                    return Column(
                                                      children: [
                                                        Dismissible(
                                                          key: ValueKey(d.documentId),
                                                          direction:
                                                              DismissDirection.endToStart,
                                                          background: Container(
                                                            alignment:
                                                                Alignment.centerRight,
                                                            padding:
                                                                const EdgeInsets.only(
                                                              right: 16,
                                                            ),
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .error
                                                                .withValues(alpha: 0.15),
                                                            child: Icon(
                                                              Icons.delete_outline,
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                            ),
                                                          ),
                                                          confirmDismiss: (dir) async {
                                                            await _deleteDocument(d);
                                                            return false;
                                                          },
                                                          child: ListTile(
                                                            dense: true,
                                                            contentPadding:
                                                                const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                            leading: leading,
                                                            title: Text(
                                                              (d.displayName ?? '')
                                                                      .trim()
                                                                      .isEmpty
                                                                  ? d.filename
                                                                  : d.displayName!.trim(),
                                                            ),
                                                            subtitle: Text(
                                                              '${_typeLabel(d)} · ${(d.mimeType ?? 'unknown')} · ${_formatDate(d.createdAt)}'
                                                              '${(linkedName != null && linkedName.trim().isNotEmpty) ? ' · Linked to $linkedName' : ''}',
                                                              style: TextStyle(
                                                                color: Colors.white
                                                                    .withValues(
                                                                  alpha: 0.65,
                                                                ),
                                                              ),
                                                            ),
                                                            trailing: isBusy
                                                                ? Text(
                                                                    '…',
                                                                    style: Theme.of(context)
                                                                        .textTheme
                                                                        .bodyLarge
                                                                        ?.copyWith(
                                                                          color: Colors.white
                                                                              .withValues(
                                                                            alpha: 0.55,
                                                                          ),
                                                                        ),
                                                                  )
                                                                : PopupMenuButton<String>(
                                                                    onSelected: (v) async {
                                                                      if (v == 'open') {
                                                                        await _openDocument(
                                                                          d,
                                                                        );
                                                                      }
                                                                      if (v == 'rename') {
                                                                        await _renameDocument(
                                                                          d,
                                                                        );
                                                                      }
                                                                      if (v == 'summarize') {
                                                                        await _summarize(
                                                                          d,
                                                                        );
                                                                      }
                                                                      if (v == 'link') {
                                                                        await _link(d);
                                                                      }
                                                                      if (v ==
                                                                          'remove_link') {
                                                                        await _removeLinkedItem(
                                                                          d,
                                                                        );
                                                                      }
                                                                    },
                                                                    itemBuilder: (context) {
                                                                      final hasLink =
                                                                          (linked?['item_id'] ??
                                                                                  '')
                                                                              .trim()
                                                                              .isNotEmpty;
                                                                      return [
                                                                        const PopupMenuItem(
                                                                          value: 'open',
                                                                          child: Text(
                                                                            'Open',
                                                                          ),
                                                                        ),
                                                                        const PopupMenuItem(
                                                                          value: 'rename',
                                                                          child: Text(
                                                                            'Rename',
                                                                          ),
                                                                        ),
                                                                        const PopupMenuItem(
                                                                          value: 'summarize',
                                                                          child: Text(
                                                                            'Summarize',
                                                                          ),
                                                                        ),
                                                                        const PopupMenuItem(
                                                                          value: 'link',
                                                                          child: Text(
                                                                            'Link to item',
                                                                          ),
                                                                        ),
                                                                        if (hasLink)
                                                                          const PopupMenuItem(
                                                                            value:
                                                                                'remove_link',
                                                                            child: Text(
                                                                              'Remove Link',
                                                                            ),
                                                                          ),
                                                                      ];
                                                                    },
                                                                  ),
                                                            onTap: () =>
                                                                _openDocument(d),
                                                          ),
                                                        ),
                                                        const Divider(height: 1),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                          ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )),
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
  List<InventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _q = TextEditingController();
    _load();
  }

  Future<void> _load() async {
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

    return Padding(
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
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search items…',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const SizedBox(
              height: 220,
              child: Center(
                child: SkeletonBox(height: 14, width: 160, borderRadius: 10),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: GlassCard(
                padding: const EdgeInsets.all(6),
                child: rows.isEmpty
                    ? Center(
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
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                            onTap: () => Navigator.of(context).pop(
                              _LinkResult(itemId: it.itemId, itemName: it.name),
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
    );
  }
}
