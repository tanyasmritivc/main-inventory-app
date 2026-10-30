import 'package:flutter/material.dart';
import '../../core/ui/scroll_glass.dart';

/// Full-height messages flow beneath softly blurred controls. Measured insets
/// keep the first/last message reachable with keyboards and larger text.
class ChatViewport extends StatefulWidget {
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
  State<ChatViewport> createState() => _ChatViewportState();
}

class _ChatViewportState extends State<ChatViewport> {
  double _header = 80, _footer = 150;
  // Extraction controls keep their established keyboard/large-text layout.
  Widget _previewLayout(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top + 8,
          16,
          12,
        ),
        child: widget.header,
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, bounds) => Column(
            children: [
              Expanded(
                child: ListView(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: widget.messages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        bounds.maxHeight * (widget.messages.isEmpty ? 1 : .65),
                  ),
                  child: widget.preview!,
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.all(8), child: widget.footer),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => widget.preview != null
        ? _previewLayout(context)
        : Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                key: const Key('chat-full-viewport'),
                controller: widget.controller,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, _header + 8, 16, _footer + 16),
                children: widget.messages,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ReportSize(
                  onSize: (size) {
                    if (mounted && _header != size.height) {
                      setState(() => _header = size.height);
                    }
                  },
                  child: ScrollGlass(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        MediaQuery.paddingOf(context).top + 8,
                        16,
                        24,
                      ),
                      child: widget.header,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ReportSize(
                  onSize: (size) {
                    if (mounted && _footer != size.height) {
                      setState(() => _footer = size.height);
                    }
                  },
                  child: ScrollGlass(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                      child: widget.footer,
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}
