import '../../core/ui/content_card.dart';
import '../../core/ui/native_presentation.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/chat_item_action.dart';
import '../../core/ask_answer.dart';
import '../../core/ui/app_text.dart';

class ChatItemActionCard extends StatefulWidget {
  const ChatItemActionCard({
    super.key,
    required this.api,
    required this.action,
    this.onResult,
    this.onOpenResource,
  });
  final ValueChanged<AskResourceLink>? onOpenResource;
  final ApiClient api;
  final ChatItemAction action;
  final ValueChanged<ChatItemActionResult>? onResult;
  @override
  State<ChatItemActionCard> createState() => _ChatItemActionCardState();
}

class _ChatItemActionCardState extends State<ChatItemActionCard> {
  late ChatItemAction _action = widget.action;
  bool _busy = false;
  String? _error;
  CancelToken? _request;
  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  Future<void> _decide(String decision) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (decision == 'confirm' &&
          _action.operation == 'delete' &&
          _action.status == 'pending') {
        final confirmed = await showAppConfirmation(
          context,
          title:
              'Delete ${_action.items.length} ${_action.items.length == 1 ? 'item' : 'items'}?',
          message:
              'Only the listed item records will be deleted. Their related history and photos may be removed. Spaces, inventories and organizations are kept.',
          confirmLabel: 'Delete items',
        );
        if (confirmed != true || !mounted) return;
      }
      _request = CancelToken();
      final result = await widget.api.decideChatItemAction(
        action: _action,
        decision: decision,
        cancelToken: _request,
      );
      if (!mounted) return;
      setState(() {
        _action = result.action;
        _error = result.answerError;
      });
      widget.onResult?.call(result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AskRequestException
              ? error.message
              : describeError(error).$1,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _action.status == 'pending';
    return ContentCard(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            pending
                ? switch (_action.operation) {
                    'add' => 'Review new items',
                    'delete' => 'Review items to delete',
                    'move' => 'Review item move',
                    'reorder' => 'Review reorder request',
                    _ => 'Review item changes',
                  }
                : _action.status == 'confirmed'
                ? switch (_action.operation) {
                    'add' => 'Items added',
                    'delete' => 'Items deleted',
                    'move' => 'Item moved',
                    _ => 'Changes saved',
                  }
                : 'Cancelled',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (_action.destinationLabel != null) ...[
            const SizedBox(height: 8),
            AppText(
              _action.destinationLabel!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final item in _action.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final detail in item.details)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: AppText(detail),
                          ),
                        AppText(
                          item.details.any(
                                (detail) =>
                                    detail.toLowerCase().contains('quantity'),
                              )
                              ? item.location
                              : '${item.quantity == null ? 'Quantity unknown' : 'Qty ${item.quantity}'} · ${item.location}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        if (item.id != null &&
                            widget.onOpenResource != null &&
                            !(_action.operation == 'delete' &&
                                _action.status == 'confirmed'))
                          TextButton.icon(
                            onPressed: () => widget.onOpenResource!(
                              AskResourceLink(
                                kind: 'item',
                                id: item.id!,
                                inventoryId:
                                    item.inventoryId ?? _action.inventoryId,
                                label: item.name,
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const AppText('Open item'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (pending)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _decide('cancel'),
                    child: const AppText('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _busy || !widget.api.canEdit
                        ? null
                        : () => _decide('confirm'),
                    child: AppText(
                      _busy
                          ? 'Confirming…'
                          : _action.operation == 'add'
                          ? 'Confirm additions'
                          : _action.operation == 'delete'
                          ? 'Review deletion'
                          : 'Confirm change',
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            AppText(_error!),
            if (_action.status == 'confirmed')
              TextButton(
                onPressed: _busy ? null : () => _decide('confirm'),
                child: const AppText('Reload AI reply'),
              ),
          ],
        ],
      ),
    );
  }
}
