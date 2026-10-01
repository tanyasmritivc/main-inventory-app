import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/ask_answer.dart';

class AskQuestionCard extends StatelessWidget {
  const AskQuestionCard({
    super.key,
    required this.question,
    this.photoBytes,
    this.photoUrl,
  });
  final String question;
  final Uint8List? photoBytes;
  // Only a validated app-owned URL may be passed here by the chat controller.
  final String? photoUrl;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF171719),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photoBytes != null || photoUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: photoBytes != null
                  ? Image.memory(
                      photoBytes!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Attached photo',
                      errorBuilder: (_, _, _) =>
                          const Text('Photo unavailable'),
                    )
                  : Image.network(
                      photoUrl!,
                      fit: BoxFit.contain,
                      semanticLabel: 'Attached photo',
                      errorBuilder: (_, _, _) =>
                          const Text('Photo unavailable'),
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SelectableText(
          question,
          style: const TextStyle(
            color: Color(0xFFF2F2F2),
            fontSize: 17,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class AskAnswerView extends StatefulWidget {
  const AskAnswerView({
    super.key,
    required this.answer,
    this.contextData,
    this.isLoading = false,
    this.pendingMessage = 'Checking your things...',
    this.onOpenSource,
  });
  final String answer;
  final AskAnswerContext? contextData;
  final bool isLoading;
  final String pendingMessage;
  final VoidCallback? onOpenSource;

  @override
  State<AskAnswerView> createState() => _AskAnswerViewState();
}

class _AskAnswerViewState extends State<AskAnswerView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFF2F2F2);
    const secondary = Color(0xFF85858E);
    final data = widget.contextData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data != null && data.sources.isNotEmpty) ...[
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _expanded = !_expanded),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Text(
                  'What it read',
                  style: TextStyle(
                    color: primary,
                    fontSize: 15,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFF3A3A40),
                    decorationThickness: 1.2,
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            Container(
              key: const Key('ask-sources'),
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171719),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final source in data.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (source.kind == 'project' &&
                              widget.onOpenSource != null)
                            InkWell(
                              onTap: widget.onOpenSource,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Text(
                                  source.label,
                                  style: const TextStyle(
                                    color: primary,
                                    fontSize: 15,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              source.label,
                              style: const TextStyle(
                                color: primary,
                                fontSize: 15,
                              ),
                            ),
                          if (source.detail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              source.detail,
                              style: const TextStyle(
                                color: secondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        if (widget.answer.trim().isEmpty && widget.isLoading)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.pendingMessage,
                style: const TextStyle(color: secondary, fontSize: 16),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MarkdownBody(
              data: widget.answer,
              selectable: !widget.isLoading,
              softLineBreak: true,
              // Generated images must not trigger arbitrary third-party requests.
              sizedImageBuilder: (_) => const SizedBox.shrink(),
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: primary,
                  fontSize: 17,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
                strong: const TextStyle(
                  color: primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
                listBullet: const TextStyle(
                  color: primary,
                  fontSize: 17,
                  height: 1.5,
                ),
                blockSpacing: 10,
                listIndent: 20,
              ),
            ),
          ),
        if (!widget.isLoading && data != null && data.rows.isNotEmpty) ...[
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: const Color(0xFF171719),
              child: Column(
                children: [
                  for (var index = 0; index < data.rows.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFF29292E),
                      ),
                    _ResultRow(row: data.rows[index]),
                  ],
                ],
              ),
            ),
          ),
          if (data.rowsTruncated)
            const Padding(
              padding: EdgeInsets.only(top: 10, left: 4),
              child: Text(
                'Additional results are not shown here.',
                style: TextStyle(color: secondary, fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row});
  final AskResultRow row;

  @override
  Widget build(BuildContext context) {
    final subtitle = row.requiredQuantity != null
        ? '${row.availableQuantity} of ${row.requiredQuantity}'
        : '${row.availableQuantity} available${row.location.isEmpty ? '' : ' - ${row.location}'}';
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          style: const TextStyle(
            color: Color(0xFFF2F2F2),
            fontSize: 17,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF85858E),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
    final colors = switch (row.status) {
      'missing' => (const Color(0xFFF16B74), const Color(0xFF281316)),
      'low' => (const Color(0xFFE2AE43), const Color(0xFF282110)),
      _ => (const Color(0xFF59BE96), const Color(0xFF13241E)),
    };
    final badge = row.status == null
        ? null
        : Semantics(
            label: '${row.name}: ${row.status}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.$2,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                row.status!,
                style: TextStyle(
                  color: colors.$1,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (badge == null) return details;
          if (MediaQuery.textScalerOf(context).scale(17) > 25 ||
              constraints.maxWidth < 260) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 10), badge],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              badge,
            ],
          );
        },
      ),
    );
  }
}
