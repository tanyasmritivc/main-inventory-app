import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';

class ChatPhotoAttachmentCard extends StatefulWidget {
  const ChatPhotoAttachmentCard({
    super.key,
    required this.api,
    required this.attachment,
    required this.onChanged,
    this.onSaved,
  });
  final ApiClient api;
  final Map<String, dynamic> attachment;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback? onSaved;
  @override
  State<ChatPhotoAttachmentCard> createState() =>
      _ChatPhotoAttachmentCardState();
}

class _ChatPhotoAttachmentCardState extends State<ChatPhotoAttachmentCard> {
  late Map<String, dynamic> _card = widget.attachment;
  String? _selected;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> get _choices =>
      (_card['choices'] as List).cast<Map<String, dynamic>>();
  String _key(Map row) => '${row['inventory_id']}/${row['item_id']}';
  Future<void> _decide(String decision) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final chosen = _choices.where((c) => _key(c) == _selected).firstOrNull;
      final result = await widget.api.decideChatPhotoAttachment(
        _card,
        decision,
        choice: chosen,
      );
      if (!mounted) return;
      setState(() => _card = result);
      widget.onChanged(result);
      if (result['status'] == 'confirmed') widget.onSaved?.call();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is AskRequestException
            ? error.message
            : describeError(error).$1,
      );
      // Recover the frozen target after a lost response; the same card is safe to retry.
      try {
        final current = await widget.api.getChatPhotoAttachment(_card);
        if (!mounted) return;
        setState(() {
          _card = current;
          if (current['selected'] is Map) {
            _selected = _key(current['selected'] as Map);
          }
        });
        widget.onChanged(current);
        if (current['status'] == 'confirmed') widget.onSaved?.call();
      } catch (_) {
        /* Keep the original error and retry the same request. */
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _card['status'];
    final saved = status == 'confirmed';
    final cancelled = status == 'cancelled';
    if (_card['selected'] is Map) _selected = _key(_card['selected'] as Map);
    final similar = _choices.any((c) => c['match'] == 'similar');
    final receipt = _card['receipt'] as Map?;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface2(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppText(
            saved
                ? 'Photo added'
                : cancelled
                ? 'Photo request cancelled'
                : similar
                ? 'Did you mean…?'
                : 'Choose the item for this photo',
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 8),
          if (saved)
            AppText('${receipt?['name'] ?? ''} · ${receipt?['location'] ?? ''}')
          else if (!cancelled) ...[
            const AppText('Choose the saved item, then attach this photo.'),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final choice in _choices)
                      Semantics(
                        selected: _selected == _key(choice),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _selected == _key(choice)
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: AppText(choice['name'] as String),
                          subtitle: AppText(
                            '${choice['workspace_name']} / ${choice['inventory_name']} / ${choice['location']}',
                          ),
                          onTap: _busy || status == 'saving'
                              ? null
                              : () => setState(() => _selected = _key(choice)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_card['more_matches'] == true)
              const AppText(
                'More matches exist. Add a location or part number in chat to narrow them down.',
              ),
            const AppText(
              'Adds to this item’s photos. An existing main photo is kept.',
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'pending')
                  TextButton(
                    onPressed: _busy ? null : () => _decide('cancel'),
                    child: const AppText('Cancel'),
                  ),
                FilledButton(
                  onPressed: _busy || _selected == null
                      ? null
                      : () => _decide('confirm'),
                  child: AppText(
                    _busy
                        ? 'Attaching…'
                        : status == 'saving'
                        ? 'Retry attachment'
                        : 'Attach photo',
                  ),
                ),
              ],
            ),
          ],
          if (_error != null && !saved) ...[
            const SizedBox(height: 8),
            AppText(_error!),
          ],
        ],
      ),
    );
  }
}
