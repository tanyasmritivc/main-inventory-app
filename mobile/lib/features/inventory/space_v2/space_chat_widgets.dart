import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import '../../../core/ask_answer.dart';
import 'space_style.dart';
import 'space_widgets.dart';

/// Optional presentation hooks. ChatPage still owns transport, history, voice,
/// cancellation and all confirmations. Other ChatPage callers are unchanged.
class SpaceChatPresentation {
  const SpaceChatPresentation({
    required this.space,
    required this.scopeLabel,
    required this.items,
    required this.onClose,
    required this.onAdd,
    required this.results,
    this.initialDraft,
    this.startVoice = false,
    this.registerSend,
  });
  final String space, scopeLabel;
  final List<InventoryItem> items;
  final VoidCallback onClose;
  final VoidCallback? onAdd;
  final ValueChanged<ValueChanged<String>>? registerSend;
  final Widget? Function(AskAnswerContext) results;
  final String? initialDraft;
  final bool startVoice;
}

class SpaceChatHeader extends StatelessWidget {
  const SpaceChatHeader({
    super.key,
    required this.presentation,
    required this.onHistory,
    required this.onNew,
  });
  final SpaceChatPresentation presentation;
  final VoidCallback? onHistory, onNew;
  @override
  Widget build(BuildContext context) {
    final title = Text('Ask FindEZ', style: SpaceStyle.text(19));
    final scope = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: SpaceStyle.card(13, SpaceStyle.s2),
      child: Text(
        presentation.scopeLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: SpaceStyle.text(12.5, SpaceStyle.tx2),
      ),
    );
    final history = SpaceCircle(
      label: 'Chat history',
      icon: Icons.history_rounded,
      onTap: onHistory,
    );
    final newChat = SpaceCircle(
      label: 'New chat',
      icon: Icons.edit_square,
      onTap: onNew,
    );
    final close = SpaceCircle(
      label: 'Close',
      icon: Icons.close,
      onTap: presentation.onClose,
    );
    return Column(
      children: [
        const SpaceHandle(),
        if (MediaQuery.textScalerOf(context).scale(19) > 26) ...[
          Row(
            children: [
              Expanded(child: title),
              close,
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: scope),
              const SizedBox(width: 8),
              history,
              const SizedBox(width: 4),
              newChat,
            ],
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 5), scope],
                ),
              ),
              const SizedBox(width: 4),
              history,
              const SizedBox(width: 4),
              newChat,
              const SizedBox(width: 4),
              close,
            ],
          ),
      ],
    );
  }
}

class SpaceChatEmpty extends StatelessWidget {
  const SpaceChatEmpty({
    super.key,
    required this.presentation,
    required this.onSend,
  });
  final SpaceChatPresentation presentation;
  final ValueChanged<String> onSend;
  @override
  Widget build(BuildContext context) {
    final items = presentation.items;
    final suggestions = <(String, InventoryItem?)>[
      ('What is running low in ${presentation.space}?', null),
      if (items.isNotEmpty)
        ('How many ${items.first.name} do we have?', items.first),
      if (items.length > 1) ('Do we have ${items[1].name}?', items[1]),
      ('What did I add recently?', null),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 34, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask about ${presentation.space}.',
            style: SpaceStyle.text(
              28,
            ).copyWith(height: 1.15, letterSpacing: -.84),
          ),
          const SizedBox(height: 6),
          Text(
            'Find, count or change items in this inventory.',
            style: SpaceStyle.text(
              28,
              SpaceStyle.tx3,
            ).copyWith(height: 1.15, letterSpacing: -.84),
          ),
          const SizedBox(height: 20),
          Material(
            color: SpaceStyle.s1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: SpaceStyle.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, suggestion) in suggestions.indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: SpaceStyle.line,
                    ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    leading: suggestion.$2 == null
                        ? Container(
                            width: 34,
                            height: 34,
                            decoration: SpaceStyle.card(10, SpaceStyle.s3),
                            child: Icon(
                              index == 0
                                  ? Icons.inventory_2_outlined
                                  : Icons.schedule,
                              size: 18,
                            ),
                          )
                        : SpaceThumbnail(
                            item: suggestion.$2!,
                            size: 34,
                            radius: 10,
                          ),
                    title: Text(suggestion.$1, style: SpaceStyle.text(15.5)),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: SpaceStyle.tx3,
                    ),
                    onTap: () => onSend(suggestion.$1),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SpaceChatComposer extends StatelessWidget {
  const SpaceChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.placeholder,
    this.onSend,
    this.onVoice,
    this.onAdd,
    this.onStop,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final VoidCallback? onSend, onVoice, onAdd, onStop;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.all(5),
    decoration: SpaceStyle.card(28),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Add items',
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 22),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            minLines: 1,
            maxLines: 3,
            style: SpaceStyle.text(16),
            decoration: InputDecoration(
              hintText: placeholder,
              hintMaxLines: 1,
              hintStyle: SpaceStyle.text(16, SpaceStyle.tx3),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Voice input',
          onPressed: onVoice,
          icon: const Icon(Icons.mic_none, size: 22, color: SpaceStyle.tx2),
        ),
        SpaceCircle(
          label: onStop != null ? 'Stop response' : 'Send message',
          icon: onStop != null ? Icons.stop_rounded : Icons.arrow_upward,
          white: onSend != null && onStop == null,
          onTap: onStop ?? onSend,
        ),
      ],
    ),
  );
}

class SpaceChatTyping extends StatefulWidget {
  const SpaceChatTyping({super.key, this.status});
  final String? status;
  @override
  State<SpaceChatTyping> createState() => _SpaceChatTypingState();
}

class _SpaceChatTypingState extends State<SpaceChatTyping>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpaceStyle.reduced(context)) {
      _animation.stop();
    } else {
      _animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.status ?? 'FindEZ is thinking',
    child: AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Row(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Opacity(
                opacity: SpaceStyle.reduced(context)
                    ? .7
                    : .3 + .7 * ((_animation.value + i / 3) % 1),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: SpaceStyle.tx2,
                  ),
                ),
              ),
            ),
          if (widget.status != null) ...[
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                widget.status!,
                style: SpaceStyle.text(13, SpaceStyle.tx2),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
