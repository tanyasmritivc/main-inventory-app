import 'package:flutter/material.dart';
import '../../core/chat_question.dart';

/// A reply chooser, never a save/creation confirmation.
Future<String?> showChatQuestion(BuildContext context, ChatQuestion question) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => ChatQuestionSheet(question: question),
    );

class ChatQuestionSheet extends StatelessWidget {
  const ChatQuestionSheet({super.key, required this.question});
  final ChatQuestion question;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                question.prompt,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              for (final choice in question.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (ModalRoute.of(context)?.isCurrent == true) {
                          Navigator.pop(context, choice.reply);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            if (choice.kind == 'new_space') ...[
                              Icon(
                                Icons.add,
                                size: 18,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    choice.label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  if (choice.detail.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      choice.detail,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text(
                  'Write my own answer',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
