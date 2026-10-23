import '../../core/ui/native_presentation.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/liquid_surface.dart';

Future<String?> showChatHistory(
  BuildContext context, {
  required ApiClient api,
  String? currentId,
  ValueChanged<String>? onDeleted,
}) async {
  if (!usesNativePresentation) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .86,
        child: ChatHistorySheet(
          api: api,
          currentId: currentId,
          onDeleted: onDeleted,
        ),
      ),
    );
  }
  List<ConversationSummary> rows = [];
  Map<String, dynamic> model({bool loading = false, String? error}) => {
    'title': 'Chats',
    'search': true,
    'searchPlaceholder': 'Search chats',
    'large': true,
    'load': loading,
    'loading': loading,
    'empty': error ?? 'Start your first chat',
    'primary': {
      'id': ChatHistorySheet.newChat,
      'title': 'New chat',
      'symbol': 'square.and.pencil',
    },
    'sections': [
      {
        'rows': [
          if (error != null)
            {
              'id': 'load',
              'title': 'Retry',
              'symbol': 'arrow.clockwise',
              'close': false,
            },
          for (final row in rows)
            {
              'id': row.id,
              'title': row.title,
              'subtitle': historyTime(row.updatedAt),
              'checked': row.id == currentId,
              'delete': {
                'id': 'delete:${row.id}',
                'close': false,
                'confirmation': {
                  'title': 'Delete chat?',
                  'message': row.title,
                  'confirmLabel': 'Delete',
                  'destructive': true,
                },
              },
            },
        ],
      },
    ],
  };
  final selected = await NativePresentation.show(
    context,
    model: model(loading: true),
    onAction: (id, _) async {
      if (!context.mounted) return {};
      try {
        api.assertCurrentContext();
        if (id == 'load') {
          rows = await api.listConversations();
          api.assertCurrentContext();
        } else if (id.startsWith('delete:')) {
          final target = id.substring(7);
          if (!rows.any((r) => r.id == target)) return model();
          await api.deleteConversation(target);
          api.assertCurrentContext();
          rows.removeWhere((r) => r.id == target);
          if (context.mounted) onDeleted?.call(target);
        }
        return model();
      } catch (error) {
        return {
          ...model(error: rows.isEmpty ? "Couldn't load history." : null),
          'error': describeError(error).$1,
        };
      }
    },
  );
  if (!context.mounted) return null;
  if (selected?['error'] is String) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(selected!['error'] as String)));
  }
  return selected?['action'] as String?;
}

String historyTime(DateTime date) {
  final age = DateTime.now().difference(date);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 24) return '${age.inHours}h ago';
  if (age.inDays == 1) return 'Yesterday';
  if (age.inDays < 7) return '${age.inDays}d ago';
  return '${date.month}/${date.day}/${date.year}';
}

/// A route-owned sheet keeps history loading/search separate from the composer.
class ChatHistorySheet extends StatefulWidget {
  const ChatHistorySheet({
    super.key,
    required this.api,
    this.currentId,
    this.onDeleted,
  });
  final ApiClient api;
  final String? currentId;
  final ValueChanged<String>? onDeleted;
  static const newChat = '__new_chat__';
  @override
  State<ChatHistorySheet> createState() => _ChatHistorySheetState();
}

class _ChatHistorySheetState extends State<ChatHistorySheet> {
  List<ConversationSummary>? _rows;
  Object? _error;
  String _query = '';
  bool _searching = false;
  final Set<String> _deleting = {};
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _rows = null;
    });
    try {
      final rows = await widget.api.listConversations();
      widget.api.assertCurrentContext();
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<bool> _delete(ConversationSummary row) async {
    if (_deleting.contains(row.id)) return false;
    final approved = await showAppConfirmation(
      context,
      title: 'Delete chat?',
      message: row.title,
    );
    if (approved != true || !mounted) return false;
    _deleting.add(row.id);
    try {
      widget.api.assertCurrentContext();
      await widget.api.deleteConversation(row.id);
      widget.onDeleted?.call(row.id);
      if (mounted) setState(() => _rows?.removeWhere((c) => c.id == row.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      _deleting.remove(row.id);
    }
    // The saved list is the source of truth, including failed deletions.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final rows = (_rows ?? [])
        .where((c) => c.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chats',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Search chats',
                icon: const Icon(CupertinoIcons.search, size: 21),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  _query = '';
                }),
              ),
              IconButton(
                tooltip: 'Close history',
                icon: const Icon(CupertinoIcons.xmark, size: 19),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: Icon(CupertinoIcons.search, size: 20),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Couldn't load history."),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _rows == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Start your first chat'
                          : 'No matching chats',
                    ),
                  )
                : ListView.separated(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      return Dismissible(
                        key: ValueKey(row.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _delete(row),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const Icon(CupertinoIcons.trash),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          title: Text(
                            row.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            historyTime(row.updatedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: row.id == widget.currentId
                              ? const Icon(CupertinoIcons.checkmark, size: 17)
                              : null,
                          onTap: () => Navigator.pop(context, row.id),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LiquidSurface(
                radius: 28,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, ChatHistorySheet.newChat),
                  icon: const Icon(CupertinoIcons.plus, size: 19),
                  label: const Text('New chat'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
