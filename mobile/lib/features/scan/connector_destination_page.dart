import 'package:flutter/material.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/utility_page.dart';
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

  Future<void> _openImport(Map<String, dynamic> space) async {
    try {
      scoped!.assertCurrentContext();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImportSheetPage(
            api: scoped!,
            location: space['name'].toString(),
            kind: widget.kind,
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = describeError(e).$1);
    }
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
      inventories = [];
    });
    try {
      if (widget.api.inventoryContext != null) {
        widget.api.assertCurrentContext();
        if (!widget.api.canEdit) {
          throw const FormatException('Choose an inventory you can edit.');
        }
        scoped = widget.api;
        spaces = await scoped!.listSpaces();
      } else if (widget.api.worldKey != null) {
        final world = widget.api.worldKey!;
        final result = await widget.api.collaboration(
          '/worlds/${Uri.encodeComponent(world)}/directory',
        );
        widget.api.assertCurrentContext();
        if (!mounted) return;
        if (result['world'] != null && result['world'] != world) {
          throw const FormatException(
            'The organization changed. Choose again.',
          );
        }
        inventories = (result['inventories'] as List? ?? [])
            .whereType<Map>()
            .where((row) => row['can_edit'] == true)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
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
      if (!mounted) return;
      final context = InventoryContext.fromJson(
        Map<String, dynamic>.from(result['inventory']),
        accountId: widget.api.accountId!,
        expectedInventory: id,
        expectedWorkspace: inventory['workspace_id'] as String?,
      );
      if (!context.canEdit ||
          (widget.api.worldKey != null &&
              (context.organizationId ?? 'personal') != widget.api.worldKey)) {
        throw const FormatException(
          'This inventory is no longer available in this organization. Choose again.',
        );
      }
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
  Widget build(BuildContext context) => UtilityPage(
    title: scoped == null ? 'Choose inventory' : 'Choose Space',
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        UtilityHint(
          scoped == null
              ? 'Choose where to import your items.'
              : 'Select a Space for this import.',
        ),
        const SizedBox(height: 20),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: UtilityCard(
                child: ListTile(
                  title: AppText(
                    inventory['name'].toString(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: UtilityHint(inventory['workspace_name'].toString()),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: busy ? null : () => _select(inventory),
                ),
              ),
            ),
        if (scoped != null)
          for (final space in spaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: UtilityCard(
                child: ListTile(
                  title: AppText(
                    space['name'].toString(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: busy ? null : () => _openImport(space),
                ),
              ),
            ),
      ],
    ),
  );
}
