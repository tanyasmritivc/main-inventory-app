import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/ui/app_text.dart';

/// Every original column stays available in a compact, bounded source section.
class ImportedItemDetails extends StatelessWidget {
  const ImportedItemDetails({super.key, required this.data});
  final ImportedItemData data;

  @override
  Widget build(BuildContext context) {
    if (data.fields.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return AppTypography(
      bodyPointSize: 12,
      captionPointSize: 11,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const PageStorageKey('imported-details'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            dense: true,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const AppText(
              'Imported details',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: AppText(
              '${data.fields.length} columns · ${data.filename} / ${data.sheet}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .32,
                ),
                child: SingleChildScrollView(
                  key: const PageStorageKey('imported-details-scroll'),
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < data.fields.length; i++) ...[
                        const Divider(height: 12),
                        AppText(
                          data.fields[i].name.trim().isEmpty
                              ? 'Column ${i + 1}'
                              : data.fields[i].name,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AppText(
                          data.fields[i].displayValue,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
