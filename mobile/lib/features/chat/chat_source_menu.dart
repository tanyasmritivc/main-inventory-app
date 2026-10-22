import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<String?> showChatSourceMenu(BuildContext context, GlobalKey anchorKey) {
  final anchor = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (anchor == null) return Future.value();
  final origin = anchor.localToGlobal(Offset.zero);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close attachment menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => _SourceMenu(anchor: origin),
  );
}

class _SourceMenu extends StatefulWidget {
  const _SourceMenu({required this.anchor});
  final Offset anchor;
  @override
  State<_SourceMenu> createState() => _SourceMenuState();
}

class _SourceMenuState extends State<_SourceMenu> {
  String page = 'root';
  static const choices = {
    'root': [
      ('auto_extract', CupertinoIcons.sparkles, 'Auto Extract', false),
      ('attach', CupertinoIcons.paperclip, 'Attach', true),
      ('spreadsheet', CupertinoIcons.table, 'Import inventory', false),
      ('barcode', CupertinoIcons.barcode_viewfinder, 'Scan barcode', false),
      ('context', CupertinoIcons.text_bubble, 'Add context', true),
    ],
    'attach': [
      ('library', CupertinoIcons.photo_on_rectangle, 'Photo library', false),
      ('camera', CupertinoIcons.camera, 'Take photo', false),
      ('file', CupertinoIcons.folder, 'Choose files', false),
    ],
    'context': [
      ('space', CupertinoIcons.square_grid_2x2, 'Spaces', false),
      ('item', CupertinoIcons.cube_box, 'Items', false),
      ('project', CupertinoIcons.folder, 'Projects', false),
      ('document', CupertinoIcons.doc_text, 'Documents and notes', false),
      ('connections', CupertinoIcons.link, 'Connections', false),
    ],
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final width = math.min(280.0, constraints.maxWidth - 24);
      final bottom = math.min(
        widget.anchor.dy - 8,
        constraints.maxHeight -
            media.viewInsets.bottom -
            media.padding.bottom -
            12,
      );
      final rows = choices[page]!.length + (page == 'root' ? 0 : 1);
      final desiredHeight =
          rows * 48.0 * media.textScaler.scale(1).clamp(1.0, 2.0) + 16;
      final top = math.max(media.padding.top + 12, bottom - desiredHeight);
      final height = math.max(48.0, bottom - top);
      final left = widget.anchor.dx.clamp(
        12.0,
        math.max(12.0, constraints.maxWidth - width - 12),
      );
      return Stack(
        children: [
          Positioned(
            left: left.toDouble(),
            top: top,
            width: width,
            height: height,
            child: Material(
              elevation: 12,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (page != 'root') ...[
                    ListTile(
                      dense: true,
                      minVerticalPadding: 8,
                      leading: const Icon(
                        CupertinoIcons.chevron_left,
                        size: 18,
                      ),
                      title: Text(page == 'attach' ? 'Attach' : 'Add context'),
                      onTap: () => setState(() => page = 'root'),
                    ),
                    const Divider(height: 1),
                  ],
                  for (final choice in choices[page]!)
                    ListTile(
                      dense: true,
                      minVerticalPadding: 8,
                      leading: Icon(choice.$2, size: 21),
                      title: Text(
                        choice.$3,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      trailing: choice.$4
                          ? const Icon(CupertinoIcons.chevron_right, size: 15)
                          : null,
                      onTap: () => choice.$4
                          ? setState(() => page = choice.$1)
                          : Navigator.pop(context, choice.$1),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
