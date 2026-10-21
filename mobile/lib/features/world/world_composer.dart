import 'package:flutter/cupertino.dart';
import '../../core/ui/liquid_surface.dart';
import 'package:flutter/material.dart';

/// A quiet, two-row composer. All capture and voice behavior belongs to Chat.
class WorldComposer extends StatelessWidget {
  const WorldComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onAttach,
    required this.onVoice,
    required this.onSend,
    required this.busy,
    required this.listening,
    required this.compact,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAttach, onVoice, onSend;
  final bool busy, listening, compact;
  @override
  Widget build(BuildContext context) {
    return LiquidSurface(
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              minLines: compact ? 1 : 2,
              maxLines: compact ? 2 : 4,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.3,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                hintText: 'Describe, ask, or add a photo…',
                hintStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.3,
                  height: 1.4,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            SizedBox(height: compact ? 6 : 14),
            Row(
              children: [
                IconButton(
                  tooltip: 'Capture or attach',
                  onPressed: onAttach,
                  icon: const Icon(CupertinoIcons.plus, size: 23),
                ),
                const Spacer(),
                LiquidIconButton(
                  tooltip: listening ? 'Stop voice input' : 'Voice input',
                  onPressed: onVoice,
                  icon: listening
                      ? CupertinoIcons.mic_fill
                      : CupertinoIcons.mic,
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: onSend,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFC45A28),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .06),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(CupertinoIcons.arrow_up),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
