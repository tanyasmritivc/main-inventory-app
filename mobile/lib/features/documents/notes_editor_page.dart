import '../../core/app_theme.dart';
import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../home/home_overview.dart';
import 'package:mobile/core/ui/app_text.dart';

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
  const NotesEditorPage({
    super.key,
    required this.api,
    this.note,
    this.ownerId,
  });

  final ApiClient api;
  final Note? note;
  final String? Function()? ownerId;

  @override
  State<NotesEditorPage> createState() => _NotesEditorPageState();
}

class _NotesEditorPageState extends State<NotesEditorPage> {
  late final TextEditingController _controller;
  bool _saving = false;
  bool _allowPop = false;
  late final String _initialText;
  late final String? _owner;
  String? get _currentOwner => widget.ownerId == null
      ? Supabase.instance.client.auth.currentUser?.id
      : widget.ownerId!();

  @override
  void initState() {
    super.initState();
    _owner = _currentOwner;
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

  Future<void> _finish(bool saved) async {
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<bool> _save({required bool popOnSuccess}) async {
    if (_saving) return false;
    if (_owner != _currentOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Your account changed. Reopen this note.'),
        ),
      );
      return false;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Note is empty.')));
      return false;
    }

    if (!mounted) return false;
    setState(() => _saving = true);
    try {
      if (widget.note != null) {
        final note = widget.note!;
        final bytes = utf8.encode(text);
        final supabase = Supabase.instance.client;
        await supabase.storage
            .from('documents')
            .uploadBinary(
              note.storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'text/plain',
                upsert: true,
              ),
            );

        if (!mounted || _owner != _currentOwner) return false;

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
        if (popOnSuccess) await _finish(true);
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
        if (!mounted || _owner != _currentOwner) return false;
        if (popOnSuccess) await _finish(true);
        return true;
      }
    } on dio.DioException {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Failed to save note')));
      return false;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('Failed to save note')));
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
        : 'New note';

    final blockPopForAutosave =
        _saving || (_controller.text.trim().isNotEmpty && _hasChanges());

    return PopScope(
      canPop: _allowPop || !blockPopForAutosave,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_saving) return;

        if (_controller.text.trim().isEmpty || !_hasChanges()) {
          await _finish(false);
          return;
        }

        final ok = await _save(popOnSuccess: false);
        if (!mounted || !context.mounted) return;
        if (ok) {
          await _finish(true);
        } else {
          final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const AppText('Note was not saved'),
              content: const AppText(
                'Keep editing to try again, or discard this draft.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const AppText('Keep editing'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const AppText('Discard'),
                ),
              ],
            ),
          );
          if (discard == true) await _finish(false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.adaptive(context, HomeColors.background),
        appBar: AppBar(
          backgroundColor: AppTheme.adaptive(context, HomeColors.background),
          surfaceTintColor: Colors.transparent,
          title: AppText(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => _save(popOnSuccess: true),
              child: AppText(
                _saving ? 'Saving...' : 'Save',
                style: TextStyle(
                  color: AppTheme.foreground(context, HomeColors.text),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  color: AppTheme.foreground(context, HomeColors.text),
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
              autofocus: true,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Start typing...',
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    color: AppTheme.foreground(context, HomeColors.hint),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
