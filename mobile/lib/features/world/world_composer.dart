import 'dart:ui';
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: contrast ? 0 : 16,
          sigmaY: contrast ? 0 : 16,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF272524) : Colors.white).withValues(
              alpha: contrast ? 1 : .84,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withValues(
                alpha: .10,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Capture or attach',
                      onPressed: onAttach,
                      icon: const Icon(Icons.add_rounded, size: 27),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: listening ? 'Stop voice input' : 'Voice input',
                      onPressed: onVoice,
                      icon: Icon(
                        listening ? Icons.mic : Icons.mic_none_rounded,
                        color: listening ? const Color(0xFFC45A28) : null,
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFC45A28),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            (dark ? Colors.white : Colors.black).withValues(
                              alpha: .07,
                            ),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
