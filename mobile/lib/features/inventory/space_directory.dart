import '../../core/ui/scroll_glass.dart';
import '../chat/inventory_chat_button.dart';
import '../../core/ui/content_loading.dart';
import 'space_texture.dart';
import '../../core/ui/native_presentation.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../notifications/notification_bell.dart';
import '../workspaces/resource_removal.dart';
import '../world/world_style.dart';
import 'inventory_page.dart';

String spaceIdentifier(Map<String, dynamic> space) =>
    (space['id'] ?? space['space_id'] ?? '').toString();

Future<void> openDirectorySpace(
  BuildContext context,
  ApiClient api,
  Map<String, dynamic> space,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _DirectorySpacePage(api: api, space: space),
    ),
  );
}

class _DirectorySpacePage extends StatefulWidget {
  const _DirectorySpacePage({required this.api, required this.space});
  final ApiClient api;
  final Map<String, dynamic> space;
  @override
  State<_DirectorySpacePage> createState() => _DirectorySpacePageState();
}

class _DirectorySpacePageState extends State<_DirectorySpacePage> {
  late Future<Widget> _page = _load();
  Future<Widget> _load() async {
    final result = await widget.api.searchItems(query: '');
    final thresholds = await LowStockPrefs.loadAll();
    widget.api.assertCurrentContext();
    final name = widget.space['name'].toString();
    final id = spaceIdentifier(widget.space);
    return WorldStyle(
      child: LocationItemsPage(
        api: widget.api,
        location: name,
        spaceId: id,
        items: result.items
            .where(
              (item) => item.spaceId != null
                  ? item.spaceId == id
                  : item.location == name,
            )
            .toList(),
        allItems: result.items,
        thresholds: thresholds,
        readOnly: !widget.api.canEdit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _page,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return Scaffold(
        appBar: AppBar(title: Text(widget.space['name'].toString())),
        body: snapshot.hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(describeError(snapshot.error!).$1),
                      TextButton(
                        onPressed: () => setState(() => _page = _load()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : const ContentLoading(label: 'Loading items...'),
      );
    },
  );
}

/// Shared manual creation flow; the caller resolves an authorized inventory first.
Future<bool> createDirectorySpace(BuildContext context, ApiClient api) async {
  api.assertCurrentContext();
  if (!api.canEdit) return false;
  final name = await _askSpaceName(context);
  if (!context.mounted || name == null) return false;
  api.assertCurrentContext();
  await api.createSpace(name: name);
  api.assertCurrentContext();
  InventoryCache.clear();
  return true;
}

/// Both organization and inventory directories use the same scoped Space actions.
class SpaceDirectoryTile extends StatefulWidget {
  const SpaceDirectoryTile({
    super.key,
    required this.space,
    required this.subtitle,
    required this.resolveApi,
    required this.onChanged,
  });
  final Map<String, dynamic> space;
  final String subtitle;
  final Future<ApiClient> Function() resolveApi;
  final Future<void> Function() onChanged;
  @override
  State<SpaceDirectoryTile> createState() => _SpaceDirectoryTileState();
}

class _SpaceDirectoryTileState extends State<SpaceDirectoryTile> {
  final _anchor = GlobalKey();
  bool _busy = false;
  String get name => widget.space['name'].toString();
  String get id => spaceIdentifier(widget.space);

  Future<void> _run(Future<void> Function(ApiClient) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final api = await widget.resolveApi();
      if (!mounted) return;
      api.assertCurrentContext();
      await action(api);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(ApiClient api) async {
    await openDirectorySpace(context, api, widget.space);
    if (mounted) await widget.onChanged();
  }

  Future<void> _menu(ApiClient api) async {
    final box = _anchor.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final choice = usesNativePresentation
        ? showNativeChoices(
            context,
            title: name,
            rows: [
              {'id': 'open', 'title': 'Open Space', 'symbol': 'folder'},
              if (api.canEdit && id.isNotEmpty)
                {'id': 'rename', 'title': 'Rename', 'symbol': 'pencil'},
              if (api.canDeleteSpace && id.isNotEmpty)
                {
                  'id': 'delete',
                  'title': 'Delete Space',
                  'symbol': 'trash',
                  'destructive': true,
                },
            ],
          )
        : showMenu<String>(
            context: context,
            position: RelativeRect.fromRect(
              origin & box.size,
              Offset.zero & overlay.size,
            ),
            popUpAnimationStyle: AnimationStyle.noAnimation,
            items: [
              const PopupMenuItem(
                value: 'open',
                child: _MenuLabel(CupertinoIcons.folder_open, 'Open Space'),
              ),
              if (api.canEdit && id.isNotEmpty)
                const PopupMenuItem(
                  value: 'rename',
                  child: _MenuLabel(CupertinoIcons.pencil, 'Rename'),
                ),
              if (api.canDeleteSpace && id.isNotEmpty) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: _MenuLabel(
                    CupertinoIcons.trash,
                    'Delete Space',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          );
    final action = await choice;
    if (!mounted || action == null) return;
    api.assertCurrentContext();
    if (action == 'open') {
      await _open(api);
    } else if (action == 'rename') {
      final newName = await _askSpaceName(context, name: name);
      if (!mounted || newName == null || newName == name) return;
      api.assertCurrentContext();
      await api.renameSpace(spaceId: id, name: newName);
      api.assertCurrentContext();
      InventoryCache.clear();
      if (mounted) await widget.onChanged();
    } else if (action == 'delete') {
      final changed = await confirmResourceRemoval(
        context,
        api,
        kind: 'space',
        id: id,
        name: name,
      );
      if (!mounted || !changed) return;
      api.assertCurrentContext();
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
    leading: SpaceTexture(identity: id.isEmpty ? name : id),
    title: Text(name),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(widget.subtitle),
    ),
    trailing: IconButton(
      key: _anchor,
      tooltip: 'Options for $name',
      onPressed: _busy ? null : () => _run(_menu),
      icon: const Icon(CupertinoIcons.ellipsis),
    ),
    onTap: _busy ? null : () => _run(_open),
  );
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 21, color: color),
      const SizedBox(width: 14),
      Flexible(
        child: Text(label, style: TextStyle(color: color)),
      ),
    ],
  );
}

Future<String?> _askSpaceName(BuildContext context, {String? name}) {
  if (usesNativePresentation) {
    return showNativeNamePrompt(
      context,
      title: name == null ? 'New Space' : 'Rename Space',
      placeholder: 'Space name',
      initial: name,
    );
  }
  return showDialog<String>(
    context: context,
    builder: (_) => _SpaceNameDialog(name: name),
  );
}

class _SpaceNameDialog extends StatefulWidget {
  const _SpaceNameDialog({this.name});
  final String? name;
  @override
  State<_SpaceNameDialog> createState() => _SpaceNameDialogState();
}

class _SpaceNameDialogState extends State<_SpaceNameDialog> {
  late final _text = TextEditingController(text: widget.name);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    if (_text.text.trim().isNotEmpty) Navigator.pop(context, _text.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.name == null ? 'New Space' : 'Rename Space'),
    content: TextField(
      controller: _text,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Space name'),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _save(),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _text.text.trim().isEmpty ? null : _save,
        child: const Text('Save'),
      ),
    ],
  );
}

/// Inventory entry is a Space directory, never the retired dashboard shell.
class InventorySpacesPage extends StatefulWidget {
  const InventorySpacesPage({super.key, required this.api, this.onBack});
  final ApiClient api;
  final VoidCallback? onBack;
  @override
  State<InventorySpacesPage> createState() => _InventorySpacesPageState();
}

class _InventorySpacesPageState extends State<InventorySpacesPage> {
  List<Map<String, dynamic>>? _spaces;
  Object? _error;
  String _query = '';
  int _generation = 0;
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final rows = await widget.api.listSpaces();
      if (!mounted || generation != _generation) return;
      widget.api.assertCurrentContext();
      setState(() {
        _spaces = rows;
        _error = null;
      });
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final created = await createDirectorySpace(context, widget.api);
      if (mounted && created) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorldStyle(
    child: Builder(
      builder: (context) {
        final inventory = widget.api.inventoryContext;
        final rows = (_spaces ?? [])
            .where(
              (row) => row['name'].toString().toLowerCase().contains(
                _query.toLowerCase(),
              ),
            )
            .toList();
        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          bottomNavigationBar: IgnorePointer(
            child: ScrollGlass(
              top: false,
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ),
          floatingActionButton: InventoryChatButton(api: widget.api),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : const Color(0xFFFFFFFF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: const ScrollGlass(child: SizedBox.expand()),
            title: const Text('Spaces'),
            leading: BackButton(onPressed: widget.onBack),
            actions: [NotificationBell(api: widget.api)],
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
                20,
                120,
              ),
              children: [
                if (inventory != null)
                  Text(
                    inventory.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Search Spaces',
                    prefixIcon: Icon(CupertinoIcons.search),
                  ),
                ),
                if (_error != null) ...[
                  Text(describeError(_error!).$1),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ] else ...[
                  const SizedBox(height: 16),
                  if (_spaces == null)
                    const ContentLoading(label: 'Loading Spaces...')
                  else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _query.isEmpty
                            ? 'No Spaces yet.'
                            : 'No matching Spaces.',
                      ),
                    ),
                  for (final space in rows)
                    SpaceDirectoryTile(
                      key: ValueKey(spaceIdentifier(space)),
                      space: space,
                      subtitle:
                          '${space['item_count'] ?? 0} ${space['item_count'] == 1 ? 'item' : 'items'}',
                      resolveApi: () async => widget.api,
                      onChanged: _load,
                    ),
                ],
                if (widget.api.canEdit)
                  TextButton.icon(
                    onPressed: _creating || _spaces == null ? null : _create,
                    icon: const Icon(CupertinoIcons.plus),
                    label: const Text('New Space'),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
