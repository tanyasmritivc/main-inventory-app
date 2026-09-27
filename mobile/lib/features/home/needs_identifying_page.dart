import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../../core/ui/visual_surfaces.dart';
import '../inventory/item_detail_sheet.dart';
import 'home_metrics.dart';

class NeedsIdentifyingPage extends StatefulWidget {
  const NeedsIdentifyingPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<NeedsIdentifyingPage> createState() => _NeedsIdentifyingPageState();
}

class _NeedsIdentifyingPageState extends State<NeedsIdentifyingPage> {
  late Future<List<InventoryItem>> _items = _load();

  Future<List<InventoryItem>> _load() async {
    final result = await widget.api.searchItems(query: '');
    return HomeMetrics(
      items: result.items,
      thresholds: const {},
      kits: const [],
      checkouts: const [],
    ).needsIdentifyingItems;
  }

  Future<void> _refresh() async {
    setState(() => _items = _load());
    await _items;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Needs identifying')),
    body: FutureBuilder<List<InventoryItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(describeError(snapshot.error!).$1));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              if (items.isEmpty)
                const GroupedSurface(
                  child: Text('Every saved object has an identity to review.'),
                )
              else
                GroupedSurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0)
                          Divider(
                            height: 1,
                            color: AppTokens.of(context).separator,
                          ),
                        ListTile(
                          title: Text(
                            items[index].name.trim().isEmpty
                                ? 'Unnamed object'
                                : items[index].name,
                          ),
                          subtitle: Text(
                            items[index].location.trim().isEmpty
                                ? 'No place'
                                : items[index].location,
                          ),
                          onTap: () async {
                            await showItemDetailSheet(
                              context,
                              item: items[index],
                              api: widget.api,
                              spaceName: items[index].location,
                            );
                            if (context.mounted) await _refresh();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
