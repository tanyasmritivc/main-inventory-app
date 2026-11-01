import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';

/// Original file values are kept separate from the item's current stock/location.
class ImportedItemDetails extends StatelessWidget {
  const ImportedItemDetails({super.key, required this.data});
  final ImportedItemData data;

  @override
  Widget build(BuildContext context) {
    if (data.fields.isEmpty) return const SizedBox.shrink();
    final muted = AppTheme.foreground(context, const Color(0x73FFFFFF));
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Imported details', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 6),
          AppText(
            '${data.filename} / ${data.sheet}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          for (var i = 0; i < data.fields.length; i++) ...[
            const SizedBox(height: 16),
            AppText(
              data.fields[i].name.trim().isEmpty
                  ? 'Column ${i + 1}'
                  : data.fields[i].name,
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 4),
            AppText(
              data.fields[i].displayValue,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
