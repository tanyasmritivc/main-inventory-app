import 'package:flutter/material.dart';

/// Keep the conversation between its controls, including at large text sizes.
class ChatViewport extends StatelessWidget {
  const ChatViewport({
    super.key,
    required this.header,
    required this.footer,
    required this.messages,
    required this.controller,
    this.preview,
  });
  final Widget header, footer;
  final List<Widget> messages;
  final ScrollController controller;
  final Widget? preview;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 8,
          16,
          12,
        ),
        child: header,
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: ListView(
                    key: const Key('chat-full-viewport'),
                    controller: controller,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: messages,
                  ),
                ),
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          bounds.maxHeight * (messages.isEmpty ? 1 : .65),
                    ),
                    child: preview!,
                  ),
                ),
            ],
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: footer),
    ],
  );
}
