import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_context.dart';
import 'import_sheet_page.dart';

/// Uses existing authorized inventory/Space selection; IDs never grant access.
class ConnectorDestinationPage extends StatefulWidget {
  const ConnectorDestinationPage({
    super.key,
    required this.api,
    this.kind = 'inventory',
  });
  final ApiClient api;
  final String kind;
  @override
  State<ConnectorDestinationPage> createState() =>
      _ConnectorDestinationPageState();
}

class _ConnectorDestinationPageState extends State<ConnectorDestinationPage> {
  List<Map<String, dynamic>> inventories = [], spaces = [];
  ApiClient? scoped;
  bool busy = true;
  String? error;
  String? inventoryId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.api.inventoryContext != null) {
        scoped = widget.api;
        spaces = await scoped!.listSpaces();
      } else {
        final result = await widget.api.collaboration('/inventory-workspaces');
        final found = <Map<String, dynamic>>[];
        for (final workspace
            in (result['workspaces'] as List? ?? []).whereType<Map>()) {
          final response = await widget.api.collaboration(
            '/inventory-workspaces/${workspace['workspace_id']}/inventories',
          );
          found.addAll(
            (response['inventories'] as List? ?? [])
                .whereType<Map>()
                .where((i) => i['can_edit'] == true)
                .map(
                  (i) => {
                    ...Map<String, dynamic>.from(i),
                    'workspace_name': workspace['name'],
                  },
                ),
          );
        }
        inventories = found;
      }
    } catch (e) {
      error = describeError(e).$1;
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _select(Map<String, dynamic> inventory) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = inventory['inventory_id'].toString();
      final result = await widget.api.collaboration('/inventories/$id');
      widget.api.assertCurrentContext();
      final context = InventoryContext.fromJson(
        Map<String, dynamic>.from(result['inventory']),
        accountId: widget.api.accountId!,
        expectedInventory: id,
      );
      final selected = ApiClient.forInventory(
        widget.api,
        context,
        isCurrent: () {
          widget.api.assertCurrentContext();
          return mounted && inventoryId == id;
        },
      );
      inventoryId = id;
      final found = await selected.listSpaces();
      if (mounted) {
        setState(() {
          scoped = selected;
          spaces = found;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = describeError(e).$1);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(scoped == null ? 'Choose inventory' : 'Choose Space'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(
            onPressed: busy ? null : _load,
            child: const Text('Try again'),
          ),
        ],
        if (!busy && scoped == null && inventories.isEmpty)
          const Text('Create an inventory and a Space before importing.'),
        if (!busy && scoped != null && spaces.isEmpty)
          const Text('Create a Space in this inventory before importing.'),
        if (scoped == null)
          for (final inventory in inventories)
            Card(
              child: ListTile(
                title: Text(inventory['name'].toString()),
                subtitle: Text(inventory['workspace_name'].toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy ? null : () => _select(inventory),
              ),
            ),
        if (scoped != null)
          for (final space in spaces)
            Card(
              child: ListTile(
                title: Text(space['name'].toString()),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ImportSheetPage(
                              api: scoped!,
                              location: space['name'].toString(),
                              kind: widget.kind,
                            ),
                          ),
                        );
                      },
              ),
            ),
      ],
    ),
  );
}
