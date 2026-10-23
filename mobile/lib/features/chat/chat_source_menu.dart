import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<String?> showChatSourceMenu(
  BuildContext context,
  GlobalKey anchorKey, {
  bool nativeAttach = false,
  String initialPage = 'root',
}) {
  final anchor = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (anchor == null) return Future.value();
  final origin = anchor.localToGlobal(Offset.zero);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close attachment menu',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => _SourceMenu(
      anchor: origin,
      nativeAttach: nativeAttach,
      initialPage: initialPage,
    ),
  );
}

class _SourceMenu extends StatefulWidget {
  const _SourceMenu({
    required this.anchor,
    required this.nativeAttach,
    required this.initialPage,
  });
  final String initialPage;
  final Offset anchor;
  final bool nativeAttach;
  @override
  State<_SourceMenu> createState() => _SourceMenuState();
}

class _SourceMenuState extends State<_SourceMenu> {
  late String page = widget.initialPage;
  final search = TextEditingController();
  String query = '';
  void navigate(String next) {
    search.clear();
    setState(() {
      page = next;
      query = '';
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  static const choices = {
    'root': [
      ('auto_extract', CupertinoIcons.sparkles, 'Auto Extract', false),
      ('attach', CupertinoIcons.paperclip, 'Attach', true),
      ('inventory', CupertinoIcons.cube_box, 'Inventory tools', true),
      ('context', CupertinoIcons.text_bubble, 'Add context', true),
    ],
    'inventory': [
      ('spreadsheet', CupertinoIcons.table, 'Import inventory', false),
      ('barcode', CupertinoIcons.barcode_viewfinder, 'Scan barcode', false),
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
      final width = math.min(248.0, constraints.maxWidth - 24);
      final bottom = math.min(
        widget.anchor.dy - 8,
        constraints.maxHeight -
            media.viewInsets.bottom -
            media.padding.bottom -
            12,
      );
      final filtered = choices[page]!
          .where(
            (choice) =>
                choice.$3.toLowerCase().contains(query.trim().toLowerCase()),
          )
          .toList();
      final rowHeight = 48.0 * media.textScaler.scale(1).clamp(1.0, 2.0);
      final desiredHeight = 48 + math.max(1, filtered.length) * rowHeight + 9;
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
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (page != 'root')
                          IconButton(
                            tooltip: 'Back to attachment options',
                            icon: const Icon(
                              CupertinoIcons.chevron_left,
                              size: 16,
                            ),
                            onPressed: () => navigate('root'),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(CupertinoIcons.search, size: 18),
                          ),
                        Expanded(
                          child: TextField(
                            controller: search,
                            style: const TextStyle(fontSize: 15),
                            onChanged: (value) => setState(() => query = value),
                            decoration: InputDecoration(
                              hintText: page == 'context'
                                  ? 'Search context…'
                                  : 'Search options…',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.only(right: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(4),
                      children: [
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'No matching options',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        for (final choice in filtered)
                          SizedBox(
                            height: rowHeight,
                            child: ListTile(
                              dense: true,
                              minVerticalPadding: 0,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              horizontalTitleGap: 12,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(choice.$2, size: 18),
                              title: Text(
                                choice.$3,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              trailing: choice.$4
                                  ? const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                    )
                                  : null,
                              onTap: () {
                                if (choice.$1 == 'attach' &&
                                    widget.nativeAttach) {
                                  Navigator.pop(context, 'attach');
                                } else if (choice.$4) {
                                  navigate(choice.$1);
                                } else {
                                  Navigator.pop(context, choice.$1);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
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
