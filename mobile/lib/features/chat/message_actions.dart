import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';

class MessageActions extends StatefulWidget {
  const MessageActions({
    super.key,
    required this.api,
    required this.content,
    required this.timestamp,
    required this.isUser,
    this.messageId,
    this.rating,
    this.onRating,
    this.onRetry,
    this.disabled = false,
  });
  final ApiClient api;
  final String content;
  final int timestamp;
  final bool isUser, disabled;
  final String? messageId;
  final Map<String, dynamic>? rating;
  final ValueChanged<Map<String, dynamic>>? onRating;
  final VoidCallback? onRetry;
  @override
  State<MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<MessageActions> {
  bool _busy = false;
  static const reasons = {
    'wrong_inventory': 'Wrong inventory information',
    'misunderstood': 'Misunderstood my request',
    'action_failed': 'Failed to perform or save the action',
    'incomplete': 'Missing or incomplete results',
    'forgot_context': 'Forgot my preferences or context',
    'unsafe_action': 'Incorrect or unsafe action',
    'clarity': 'Poor explanation or excessive verbosity',
    'other': 'Other',
  };
  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> rate(
    int value, {
    String? reason,
    String? comment,
    bool details = false,
  }) async {
    if (_busy || widget.disabled || widget.messageId == null) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.api.collaboration(
        '/response-feedback/${widget.messageId}',
        method: 'PUT',
        data: {
          'rating': value,
          'reason': reason,
          'comment': comment,
          'expected_revision': widget.rating?['revision'] ?? 0,
        },
      );
      widget.api.assertCurrentContext();
      if (saved['message_id'] != widget.messageId ||
          saved['rating'] != value ||
          saved['revision'] is! int) {
        throw const FormatException();
      }
      if (!mounted) return;
      widget.onRating?.call(saved);
      if (value == -1 && !details) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showDetails();
        });
      }
    } catch (_) {
      notice("Feedback wasn't saved. Please try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> showDetails() async {
    String? reason = widget.rating?['reason'];
    final comment = TextEditingController(
      text: widget.rating?['comment'] ?? '',
    );
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('What went wrong? (optional)')),
                    IconButton(
                      tooltip: 'Close feedback details',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: reasons.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, maxLines: 2),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => reason = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comment,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Optional comment',
                    hintText: "Don't include sensitive details.",
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (result == true && mounted) {
      await rate(
        -1,
        reason: reason,
        comment: text.isEmpty ? null : text,
        details: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      widget.timestamp,
    ).toLocal();
    Widget icon(
      String label,
      IconData data,
      VoidCallback? tap, {
      bool selected = false,
    }) => IconButton(
      tooltip: label,
      isSelected: selected,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      iconSize: 17,
      style: IconButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFA9D6F5) : null,
      ),
      onPressed: widget.disabled || _busy ? null : tap,
      icon: Icon(data, color: selected ? const Color(0xFF163F5D) : null),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        icon('Copy message', Icons.copy_outlined, () async {
          try {
            await Clipboard.setData(ClipboardData(text: widget.content));
            notice('Copied');
          } catch (_) {
            notice("Couldn't copy this message.");
          }
        }),
        if (!widget.isUser && widget.messageId != null) ...[
          icon(
            'Good response',
            widget.rating?['rating'] == 1
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            () => rate(1),
            selected: widget.rating?['rating'] == 1,
          ),
          icon(
            'Bad response',
            widget.rating?['rating'] == -1
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            () => widget.rating?['rating'] == -1 ? showDetails() : rate(-1),
            selected: widget.rating?['rating'] == -1,
          ),
        ],
        if (widget.onRetry != null)
          icon(
            widget.isUser ? 'Retry prompt' : 'Retry response',
            Icons.refresh,
            widget.onRetry,
          ),
        Tooltip(
          message: MaterialLocalizations.of(context).formatFullDate(date),
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(date)),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
