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
  int _generation = 0;
  bool _current(ApiClient api, int generation) =>
      mounted && identical(widget.api, api) && generation == _generation;

  @override
  void didUpdateWidget(covariant ConnectorDestinationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.api, widget.api)) _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.api;
    final generation = ++_generation;
    setState(() {
      busy = true;
      error = null;
      inventories = [];
      spaces = [];
      scoped = null;
      inventoryId = null;
    });
    try {
      if (api.inventoryContext != null) {
        final found = await api.listSpaces();
        if (!_current(api, generation)) return;
        scoped = api;
        spaces = found;
      } else if (api.worldKey != null) {
        final world = api.worldKey!;
        final result = await api.collaboration(
          '/worlds/${Uri.encodeComponent(world)}/directory',
        );
        if (!_current(api, generation)) return;
        if (result['world'] != world) {
          throw const FormatException(
            'The organization could not be verified. Reopen this import.',
          );
        }
        inventories = (result['inventories'] as List? ?? [])
            .whereType<Map>()
            .where((row) => row['can_edit'] == true)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      } else {
        final result = await api.collaboration('/inventory-workspaces');
        final found = <Map<String, dynamic>>[];
        for (final workspace
            in (result['workspaces'] as List? ?? []).whereType<Map>()) {
          final response = await api.collaboration(
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
        if (!_current(api, generation)) return;
        inventories = found;
      }
    } catch (e) {
      if (!_current(api, generation)) return;
      error = describeError(e).$1;
    }
    if (_current(api, generation)) setState(() => busy = false);
  }

  Future<void> _select(Map<String, dynamic> inventory) async {
    final api = widget.api;
    final generation = _generation;
    if (busy || !inventories.contains(inventory)) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = inventory['inventory_id'].toString();
      final result = await api.collaboration('/inventories/$id');
      if (!_current(api, generation)) return;
      api.assertCurrentContext();
      final context = InventoryContext.fromJson(
        Map<String, dynamic>.from(result['inventory']),
        accountId: api.accountId!,
        expectedInventory: id,
      );
      if (!context.canEdit ||
          (api.worldKey != null &&
              (context.organizationId ?? 'personal') != api.worldKey)) {
        throw const FormatException(
          'Choose an editable inventory in this organization.',
        );
      }
      final selected = ApiClient.forInventory(
        api,
        context,
        isCurrent: () {
          api.assertCurrentContext();
          return _current(api, generation) && inventoryId == id;
        },
      );
      inventoryId = id;
      final found = await selected.listSpaces();
      if (_current(api, generation)) {
        setState(() {
          scoped = selected;
          spaces = found;
        });
      }
    } catch (e) {
      if (_current(api, generation)) {
        setState(() => error = describeError(e).$1);
      }
    } finally {
      if (_current(api, generation)) setState(() => busy = false);
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
                  onTap: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ImportSheetPage(
                                api: scoped!,
                                location: space['name'].toString(),
                                spaceId: space['id'].toString(),
                                kind: widget.kind,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ),
      ],
    ),
  );
}
