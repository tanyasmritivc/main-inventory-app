import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/ui/app_text.dart';
import 'world_style.dart';

Future<Map<String, dynamic>?> showInventoryPicker(
  BuildContext context,
  List<Map<String, dynamic>> inventories,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) =>
      WorldStyle(child: InventoryPickerSheet(inventories: inventories)),
);

class InventoryPickerSheet extends StatelessWidget {
  const InventoryPickerSheet({super.key, required this.inventories});
  final List<Map<String, dynamic>> inventories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: AppText(
                'Choose',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: inventories.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = inventories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    title: AppText(
                      row['name'].toString(),
                      style: theme.textTheme.bodyLarge,
                    ),
                    subtitle: AppText(
                      row['workspace_name'].toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    onTap: () => Navigator.pop(context, row),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
