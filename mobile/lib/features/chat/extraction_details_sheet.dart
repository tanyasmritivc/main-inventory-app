import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/appearance_controller.dart';
import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/native_presentation.dart';

Future<void> showExtractionDetails(
  BuildContext context,
  List<Map<String, dynamic>> rows, {
  bool itemsConfirmed = false,
}) async {
  final items = rows.where((row) => row['selected'] == true).map((row) {
    final item = row['item'] as Map;
    final review =
        !itemsConfirmed &&
        (item['scan_evidence'] as Map?)?['needs_review'] == true;
    return <String, dynamic>{
      'title': item['name'] as String,
      'subtitle':
          '${item['category']} · Qty ${item['quantity'] ?? 'Not specified'}'
          '${review ? ' · Sent to Review' : ''}',
      'readOnly': true,
    };
  }).toList();
  if (usesNativePresentation) {
    final result = await NativePresentation.show(
      context,
      model: {
        'title': 'Extraction details',
        'textSizeFactor':
            (AppearanceScope.maybeOf(context)?.textSize ?? AppTextSize.standard)
                .factor,
        'large': true,
        'sections': [
          {'rows': items},
        ],
      },
    );
    if (context.mounted && result?['error'] is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(result!['error'] as String)));
    }
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
            child: Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Extraction details',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(18) : Radius.zero,
                  bottom: index == items.length - 1
                      ? const Radius.circular(18)
                      : Radius.zero,
                ),
                child: ColoredBox(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.secondarySystemGroupedBackground,
                    context,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: AppText(items[index]['title'] as String),
                        subtitle: AppText(items[index]['subtitle'] as String),
                      ),
                      if (index < items.length - 1)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: AppTheme.border(context),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
