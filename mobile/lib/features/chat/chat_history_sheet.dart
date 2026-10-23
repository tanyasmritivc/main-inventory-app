import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/ui/liquid_surface.dart';

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

  String _time(DateTime date) {
    final age = DateTime.now().difference(date);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    if (age.inDays == 1) return 'Yesterday';
    if (age.inDays < 7) return '${age.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<bool> _delete(ConversationSummary row) async {
    if (_deleting.contains(row.id)) return false;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(row.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
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
                            _time(row.updatedAt),
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
