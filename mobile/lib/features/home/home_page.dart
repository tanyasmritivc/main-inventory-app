import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/primary_gradient_button.dart';
import '../chat/chat_page.dart';
import '../documents/documents_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api});

  final ApiClient api;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = false;
  String? _message;
  String? _error;

  List<ActivityEntry> _activities = const [];

  String _friendlyRequestError(Object error) {
    if (error is dio.DioException) {
      final t = error.type;
      if (t == dio.DioExceptionType.connectionTimeout ||
          t == dio.DioExceptionType.sendTimeout ||
          t == dio.DioExceptionType.receiveTimeout) {
        return 'That took longer than expected. Try again.';
      }
    }
    return 'That didn’t work. Try again.';
  }

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() {
      _error = null;
    });
    try {
      final items = await widget.api.getRecentActivity(limit: 10);
      setState(() => _activities = items);
    } catch (e) {
      setState(() => _error = _friendlyRequestError(e));
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      final file = picked?.files.single;
      if (file == null) return;
      if (file.bytes == null) throw Exception('Unable to read file bytes');

      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        _ => 'application/octet-stream',
      };

      final mf = dio.MultipartFile.fromBytes(
        file.bytes!,
        filename: file.name,
        contentType: MediaType.parse(mime),
      );

      final res = await widget.api.uploadDocument(file: mf);
      setState(() => _message = res.activitySummary.isNotEmpty ? res.activitySummary : 'Uploaded ${res.filename}');
      await _loadActivity();
    } on dio.DioException catch (e) {
      setState(() => _error = _friendlyRequestError(e));
    } catch (e) {
      setState(() => _error = _friendlyRequestError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = Colors.white.withValues(alpha: 0.06);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadActivity,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _loading ? null : () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DocumentsPage(api: widget.api)),
              );
            },
            icon: const Icon(Icons.folder_open),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: PrimaryGradientButton(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(api: widget.api)));
                      },
                      child: const Text('Start a chat'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: overlay,
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.14), width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        onPressed: _loading ? null : _pickAndUpload,
                        child: Text(_loading ? 'Uploading…' : 'Upload a document'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_message != null)
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: 16,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _message!,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderRadius: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _activities.isEmpty
                  ? const GlassCard(
                      child: Center(child: Text('No activity yet.')),
                    )
                  : GlassCard(
                      padding: const EdgeInsets.all(6),
                      child: ListView.separated(
                        itemCount: _activities.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final a = _activities[index];
                          return ListTile(
                            dense: true,
                            title: Text(a.summary),
                            subtitle: Text(
                              a.createdAt.toLocal().toString(),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
