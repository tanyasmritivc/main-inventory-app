import 'package:mobile/core/private_image.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/ui/app_text.dart';

/// Read-only capture results. Opening a preview never queues or saves records.
class ScanInspection extends StatelessWidget {
  const ScanInspection({super.key, required this.items});
  final List<ExtractedInventoryItem> items;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const AppText('Scan preview', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          const AppText('Nothing was saved. Saving requires Editor access.'),
          const SizedBox(height: 16),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: item.imageUrl?.isNotEmpty == true
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: PrivateImage(
                        item.imageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_outlined),
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              title: AppText(
                item.name.trim().isEmpty ? 'Unidentified item' : item.name,
              ),
              subtitle: AppText(
                [
                  item.category,
                  item.brand,
                  item.partNumber,
                  item.barcode,
                ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Done'),
          ),
        ],
      ),
    ),
  );
}
