import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/world_views.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<ConversationSummary>? _conversations;
  String? _error;
  String? _deleting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final conversations = await widget.api.listConversations();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _delete(ConversationSummary conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('Delete "${conversation.title}" from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = conversation.id);
    try {
      await widget.api.deleteConversation(conversation.id);
      if (!mounted) return;
      setState(
        () => _conversations?.removeWhere((c) => c.id == conversation.id),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  String _relativeTime(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    if (elapsed.inDays == 1) return 'Yesterday';
    if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final conversations = _conversations;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(
              title: 'Ask history',
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('New conversation'),
              ),
            ),
            if (_error != null && conversations == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'History could not load.',
                        style: TextStyle(color: t.ink),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (conversations == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (conversations.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No past conversations.',
                    style: TextStyle(color: t.text2),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => Divider(color: t.separator),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(conversation.title),
                      subtitle: Text(
                        _relativeTime(conversation.updatedAt),
                        style: TextStyle(color: t.text2),
                      ),
                      onTap: () => Navigator.pop(context, conversation.id),
                      trailing: TextButton(
                        onPressed: _deleting == null
                            ? () => _delete(conversation)
                            : null,
                        child: Text(
                          _deleting == conversation.id ? 'Deleting' : 'Delete',
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
