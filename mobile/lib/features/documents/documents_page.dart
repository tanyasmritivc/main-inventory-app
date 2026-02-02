import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';

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

      final docs = await widget.api.getDocuments();

      if (!mounted) return;
      setState(() => _docs = docs);
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        if (e.response?.statusCode == 404) {
          _error = 'GET /documents is not available on the backend yet.';
        } else {
          _error = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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

  Future<void> _openDocument(DocumentEntry d) async {
    final url = d.url;
    if (url == null || url.isEmpty) return;

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

      final row = await supabase.from('documents').select('storage_path').eq('document_id', d.documentId).maybeSingle();
      final storagePath = (row as Map?)?['storage_path']?.toString();

      if (storagePath != null && storagePath.isNotEmpty) {
        await supabase.storage.from('item-images').remove([storagePath]);
      }

      await supabase.from('documents').delete().eq('document_id', d.documentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Documents'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
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
                : GlassCard(
                    padding: const EdgeInsets.all(6),
                    child: ListView.separated(
                      itemCount: _docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _docs[index];
                        return Dismissible(
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
                            title: Text(
                              d.filename,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${d.mimeType ?? 'unknown'} · ${d.createdAt.toLocal()}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                            trailing: d.url != null ? const Icon(Icons.open_in_new) : null,
                            onTap: () => _openDocument(d),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
