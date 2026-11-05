import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';
import 'space_style.dart';
import 'space_widgets.dart';

Future<String?> chooseSpaceLocation(
  BuildContext context,
  ApiClient api,
  InventoryItem item, {
  VoidCallback? onReady,
}) async {
  final spaces = await api.listSpaces();
  api.assertCurrentContext();
  if (!context.mounted) return null;
  onReady?.call();
  return showSpaceSheet<String>(
    context,
    builder: (ctx) => SpaceSheetList(
      title: 'Move ${item.name}',
      children: [
        for (final space in spaces)
          SpaceAction(
            icon: Icons.grid_view_outlined,
            title: space['name'].toString(),
            selected: item.spaceId != null
                ? (space['id'] ?? space['space_id']) == item.spaceId
                : space['name'] == item.location,
            subtitle: api.inventoryContext?.name,
            onTap: () => Navigator.pop(ctx, space['name'].toString()),
          ),
        if (spaces.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: AppText('No other Spaces available.'),
          ),
      ],
    ),
  );
}
