import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';

class Note {
  const Note({
    required this.id,
    required this.storagePath,
    required this.content,
    required this.filename,
    this.displayName,
  });

  final String id;
  final String storagePath;
  final String content;
  final String filename;
  final String? displayName;
}

class NotesEditorPage extends StatefulWidget {
  const NotesEditorPage({super.key, required this.api, this.note});

  final ApiClient api;
  final Note? note;

  @override
  State<NotesEditorPage> createState() => _NotesEditorPageState();
}

class _NotesEditorPageState extends State<NotesEditorPage> {
  late final TextEditingController _controller;
  bool _saving = false;
  late final String _initialText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.note != null) {
      _controller.text = widget.note!.content;
    }
    _initialText = _controller.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasChanges() {
    return _controller.text != _initialText;
  }

  Future<bool> _save({required bool popOnSuccess}) async {
    if (_saving) return false;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note is empty.')),
      );
      return false;
    }

    setState(() => _saving = true);
    try {
      if (widget.note != null) {
        final note = widget.note!;
        final bytes = utf8.encode(text);
        final supabase = Supabase.instance.client;
        await supabase.storage.from('documents').uploadBinary(
              note.storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'text/plain',
                upsert: true,
              ),
            );

        try {
          final uid = supabase.auth.currentUser?.id;
          if (uid != null && uid.isNotEmpty) {
            await supabase
                .from('documents')
                .update(<String, dynamic>{
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('user_id', uid)
                .eq('storage_path', note.storagePath);
          }
        } catch (_) {
          // Best-effort only.
        }

        if (!mounted) return false;
        if (popOnSuccess) Navigator.of(context).pop(true);
        return true;
      } else {
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        final filename = 'note-$id.txt';
        final bytes = utf8.encode(text);
        final file = dio.MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse('text/plain'),
        );

        await widget.api.uploadDocument(file: file);
        if (!mounted) return false;
        if (popOnSuccess) Navigator.of(context).pop(true);
        return true;
      }
    } on dio.DioException {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save note')),
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save note')),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;
    final title = isEditing
        ? ((widget.note!.displayName ?? '').trim().isEmpty
            ? widget.note!.filename
            : widget.note!.displayName!.trim())
        : 'New Note';

    final blockPopForAutosave =
        !_saving && _controller.text.trim().isNotEmpty && _hasChanges();

    return PopScope(
      canPop: !blockPopForAutosave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_saving) return;

        final nav = Navigator.of(context);

        if (_controller.text.trim().isEmpty || !_hasChanges()) {
          if (!mounted) return;
          nav.pop(false);
          return;
        }

        final ok = await _save(popOnSuccess: false);
        if (!mounted) return;
        if (ok) {
          nav.pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(popOnSuccess: true),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: 'Start typing...',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
