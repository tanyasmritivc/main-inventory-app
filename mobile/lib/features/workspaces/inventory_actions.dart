import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/api_error.dart';
import 'place_ui.dart';
import 'resource_removal.dart';

/// Management lives in the workspace directory, outside the working inventory.
Future<void> manageDirectoryInventory(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic> inventory,
  Future<void> Function() refresh,
) async {
  final name = inventory['name'].toString();
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(name, style: PlacePalette.of(context).rowTitle),
          ),
          if (inventory['can_rename'] == true)
            ListTile(
              title: const Text('Rename inventory'),
              onTap: () => Navigator.pop(sheet, 'rename'),
            ),
          if (inventory['can_manage'] == true)
            ListTile(
              title: Text(
                'Delete inventory',
                style: PlacePalette.of(
                  context,
                ).text(16, color: PlacePalette.of(context).destructive),
              ),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  if (action == 'delete') {
    final changed = await confirmResourceRemoval(
      context,
      api,
      kind: 'inventory',
      id: inventory['inventory_id'].toString(),
      name: name,
    );
    if (changed && context.mounted) await refresh();
    return;
  }
  var entered = name;
  var busy = false;
  String? error;
  final receipt = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, update) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: const Text('Rename inventory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: entered,
                  autofocus: true,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: InputDecoration(labelText: 'Inventory name'),
                  onChanged: (value) => update(() => entered = value),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: PlacePalette.of(context).destructive,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: busy || entered.trim().isEmpty
                  ? null
                  : () async {
                      update(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final result = await api.collaboration(
                          '/inventories/${Uri.encodeComponent(inventory['inventory_id'].toString())}',
                          method: 'PATCH',
                          data: {'name': entered.trim()},
                        );
                        if (result['inventory'] is! Map) {
                          throw const FormatException(
                            'The change could not be confirmed. Refresh before retrying.',
                          );
                        }
                        InventoryCache.clear();
                        if (dialog.mounted) Navigator.pop(dialog, result);
                      } catch (reason) {
                        if (dialog.mounted) {
                          update(() {
                            busy = false;
                            error = describeError(reason).$1;
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || receipt == null) return;
  try {
    await refresh();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The change was saved. Pull to refresh the list.'),
        ),
      );
    }
  }
}

class InventoryDirectoryRow extends StatelessWidget {
  const InventoryDirectoryRow({
    super.key,
    required this.inventory,
    required this.api,
    required this.onOpen,
    required this.refresh,
    this.contained = true,
  });
  final Map<String, dynamic> inventory;
  final ApiClient api;
  final VoidCallback onOpen;
  final Future<void> Function() refresh;
  final bool contained;
  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Expanded(
          child: PlaceRow(
            title: inventory['name'].toString(),
            leading: Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: PlacePalette.of(context).dim,
            ),
            subtitle: inventory['can_open'] != true
                ? 'Access restricted'
                : [
                    if (inventory['item_count'] != null)
                      '${inventory['item_count']} items',
                    if (inventory['role'] != 'owner')
                      placeRole(inventory['role']?.toString() ?? 'viewer'),
                  ].join(' · '),
            showChevron: false,
            onTap: onOpen,
          ),
        ),
        if (inventory['can_rename'] == true || inventory['can_manage'] == true)
          IconButton(
            tooltip: 'Manage ${inventory['name']}',
            icon: const Icon(Icons.more_horiz, size: 20),
            onPressed: () =>
                manageDirectoryInventory(context, api, inventory, refresh),
          ),
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: ExcludeSemantics(child: PlaceGlyph(PlaceSymbol.right)),
        ),
      ],
    );
    return contained ? PlaceCardList(children: [row]) : row;
  }
}
