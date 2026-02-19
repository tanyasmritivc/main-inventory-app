import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/document_link_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final token = session?.accessToken;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Please sign in again.');
        return;
      }

      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Please sign in again.');
        return;
      }

      final resp = await supabase
          .from('documents')
          .select('user_id,filename,storage_path,mime_type,file_type,size_bytes,created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(200);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final links = await DocumentLinkPrefs.loadAll();
      final ttl = 3600;
      final docs = <DocumentEntry>[];
      for (final r in rows) {
        final storagePath = (r['storage_path'] ?? '').toString();
        String? signedUrl;
        final mime = (r['mime_type'] ?? '').toString().toLowerCase();
        if (storagePath.isNotEmpty && mime.startsWith('image/')) {
          try {
            final signed = await supabase.storage.from('documents').createSignedUrl(storagePath, ttl);
            signedUrl = signed;
          } catch (_) {
            signedUrl = null;
          }
        }
        docs.add(
          DocumentEntry.fromJson(
            <String, dynamic>{
              ...r,
              'url': signedUrl,
            },
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _docs = docs;
        _links = links;
      });
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
    if (mime == 'application/pdf') return true;
    return d.filename.toLowerCase().endsWith('.pdf');
  }

  bool _isImage(DocumentEntry d) {
    final mime = (d.mimeType ?? '').toLowerCase();
    return mime.startsWith('image/');
  }

  Future<String?> _ensureSignedUrl(DocumentEntry d) async {
    if (d.url != null && (d.url ?? '').isNotEmpty) return d.url;
    final supabase = Supabase.instance.client;
    final storagePath = d.documentId;
    if (storagePath.isEmpty) return null;
    try {
      return await supabase.storage.from('documents').createSignedUrl(storagePath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDocument(DocumentEntry d) async {
    final url = await _ensureSignedUrl(d);
    if (url == null || url.isEmpty) return;
    if (!mounted) return;

    final mime = (d.mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) {
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

  Future<void> _summarize(DocumentEntry d) async {
    setState(() => _busyDocId = d.documentId);
    try {
      final msg =
          'Summarize this document in a few short bullets. Document: "${d.filename}". storage_path: "${d.documentId}".';
      final out = await widget.api.aiCommand(message: msg);
      if (!mounted) return;

      final text = out.assistantMessage.trim().isEmpty ? 'No summary available.' : out.assistantMessage.trim();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Summary'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t summarize. Try again.')));
    } finally {
      if (mounted) setState(() => _busyDocId = null);
    }
  }

  Future<void> _link(DocumentEntry d) async {
    final res = await showModalBottomSheet<_LinkResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LinkSheet(document: d),
    );
    if (res == null) return;

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
  }

  Future<void> _deleteDocument(DocumentEntry d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(d.filename),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final supabase = Supabase.instance.client;
      final storagePath = d.documentId;
      final uid = supabase.auth.currentUser?.id;

      if (storagePath.isNotEmpty) {
        await supabase.storage.from('documents').remove([storagePath]);
      }

      if (uid != null && uid.isNotEmpty && storagePath.isNotEmpty) {
        await supabase.from('documents').delete().eq('user_id', uid).eq('storage_path', storagePath);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t delete. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = _docs.where(_isImage).toList();
    final pdfs = _docs.where((d) => !_isImage(d) && _isPdf(d)).toList();
    final other = _docs.where((d) => !_isImage(d) && !_isPdf(d)).toList();

    final sections = <({String title, List<DocumentEntry> docs})>[
      (title: 'Images', docs: images),
      (title: 'PDFs', docs: pdfs),
      (title: 'Other', docs: other),
    ].where((s) => s.docs.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('My Documents'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? GlassCard(
                padding: const EdgeInsets.all(6),
                child: ListView.separated(
                  itemCount: 8,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) => const SkeletonListTile(),
                ),
              )
            : _error != null
                ? Center(
                    child: GlassCard(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : (_docs.isEmpty
                    ? Center(
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.description_outlined, color: Colors.white.withValues(alpha: 0.75)),
                              const SizedBox(width: 10),
                              Text(
                                'No documents yet.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GlassCard(
                        padding: const EdgeInsets.all(6),
                        child: ListView.builder(
                          itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.docs.length),
                          itemBuilder: (context, i) {
                            var index = i;
                            for (final s in sections) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                                  child: Text(
                                    s.title,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.70),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                );
                              }
                              index -= 1;
                              if (index < s.docs.length) {
                                final d = s.docs[index];
                                final linked = _links[d.documentId];
                                final linkedName = linked?['item_name'];

                                final isBusy = _busyDocId == d.documentId;
                                final leading = _isImage(d)
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          color: Colors.white.withValues(alpha: 0.06),
                                          child: (d.url != null && (d.url ?? '').isNotEmpty)
                                              ? Image.network(
                                                  d.url!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Icon(
                                                    Icons.image_outlined,
                                                    color: Colors.white.withValues(alpha: 0.70),
                                                  ),
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Center(
                                                      child: Icon(
                                                        Icons.image_outlined,
                                                        color: Colors.white.withValues(alpha: 0.55),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : Icon(Icons.image_outlined, color: Colors.white.withValues(alpha: 0.70)),
                                        ),
                                      )
                                    : Icon(
                                        _isPdf(d) ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined,
                                        color: Colors.white.withValues(alpha: 0.70),
                                      );

                                return Column(
                                  children: [
                                    Dismissible(
                                      key: ValueKey(d.documentId),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                                        child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                      ),
                                      confirmDismiss: (dir) async {
                                        await _deleteDocument(d);
                                        return false;
                                      },
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        leading: leading,
                                        title: Text(d.filename),
                                        subtitle: Text(
                                          '${(d.mimeType ?? 'unknown')} · ${_formatDate(d.createdAt)}'
                                          '${(linkedName != null && linkedName.trim().isNotEmpty) ? ' · Linked to $linkedName' : ''}',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                                        ),
                                        trailing: isBusy
                                            ? Text(
                                                '…',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                      color: Colors.white.withValues(alpha: 0.55),
                                                    ),
                                              )
                                            : PopupMenuButton<String>(
                                                onSelected: (v) async {
                                                  if (v == 'open') await _openDocument(d);
                                                  if (v == 'summarize') await _summarize(d);
                                                  if (v == 'link') await _link(d);
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(value: 'open', child: Text('Open')),
                                                  PopupMenuItem(value: 'summarize', child: Text('Summarize')),
                                                  PopupMenuItem(value: 'link', child: Text('Link to item')),
                                                ],
                                              ),
                                        onTap: () => _openDocument(d),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              }
                              index -= s.docs.length;
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      )),
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
  const _LinkSheet({required this.document});

  final DocumentEntry document;

  @override
  State<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends State<_LinkSheet> {
  final _q = TextEditingController();
  bool _loading = true;
  List<InventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _items = const [];
        });
        return;
      }
      final resp = await supabase
          .from('items')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(200);
      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
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
        : _items.where((it) => it.name.toLowerCase().contains(query) || it.category.toLowerCase().contains(query)).toList();

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Link to inventory item',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
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
              child: Center(child: SkeletonBox(height: 14, width: 160, borderRadius: 10)),
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
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: rows.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final it = rows[index];
                          return ListTile(
                            dense: true,
                            title: Text(it.name),
                            subtitle: Text(
                              it.category,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                            onTap: () => Navigator.of(context).pop(_LinkResult(itemId: it.itemId, itemName: it.name)),
                          );
                        },
                      ),
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(const _LinkResult(itemId: null, itemName: null)),
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
