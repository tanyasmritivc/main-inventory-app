import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api_client.dart';
import '../../core/memory_controller.dart';
import '../../core/ui/app_text.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final MemoryController store;
  final alias = TextEditingController();
  String? spaceId;
  @override
  void initState() {
    super.initState();
    store = MemoryController(widget.api)..addListener(_changed);
    unawaited(store.load());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    store.dispose();
    alias.dispose();
    super.dispose();
  }

  Future<void> _forget() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Forget personalization?'),
        content: const AppText(
          'This removes your preferences, aliases and unverified legacy memory. Your chats and inventory stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Forget'),
          ),
        ],
      ),
    );
    if (yes == true) await store.change({'action': 'clear'});
  }

  Widget _choice(String key, String title, List<String> values) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<String>(
      key: ValueKey(
        '$key:${store.preference(key)}:${store.snapshot?['revision']}',
      ),
      initialValue: store.preference(key) ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: title),
      items: [
        const DropdownMenuItem(value: '', child: AppText('Default')),
        ...values.map((v) => DropdownMenuItem(value: v, child: AppText(v))),
      ],
      onChanged: store.busy || store.pending != null || !store.enabled
          ? null
          : (value) => unawaited(
              store.change(
                value == ''
                    ? {'action': 'delete', 'key': key}
                    : {'action': 'set', 'key': key, 'value': value},
              ),
            ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final blocked = store.busy || store.pending != null;
    return Scaffold(
      appBar: AppBar(title: const AppText('Memory')),
      body: RefreshIndicator(
        onRefresh: store.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppText(
              'Save only the preferences you choose. Preferences are private to your account across devices.',
            ),
            if (store.busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (store.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AppText(
                  store.error!,
                  semanticsLabel: 'Memory error: ${store.error}',
                ),
              ),
            if (store.notice != null) AppText(store.notice!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: store.busy ? null : store.load,
                child: const AppText('Refresh memory'),
              ),
            ),
            if (store.pending != null)
              FilledButton(
                onPressed: store.busy ? null : () => store.change(null),
                child: const AppText('Retry save'),
              ),
            if (store.snapshot != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const AppText('Use personalization'),
                value: store.enabled,
                onChanged: blocked
                    ? null
                    : (v) => store.change({'action': 'settings', 'enabled': v}),
              ),
              const AppText(
                'Turning this off stops using preferences. It keeps them until you forget them.',
              ),
              _choice('answer_length', 'Answer length', [
                'brief',
                'standard',
                'detailed',
              ]),
              _choice('answer_format', 'Answer format', [
                'paragraphs',
                'bullets',
              ]),
              for (final entry in store.entries.where(
                (e) => e['kind'] == 'preference',
              ))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AppText(
                    '${entry['key']}: ${(entry['payload'] as Map)['value']}. ${entry['source']}. Saved ${entry['confirmed_at']}.',
                  ),
                ),
              if (store.inventoryId != null) ...[
                const SizedBox(height: 20),
                const AppText('Location aliases'),
                const AppText(
                  'Private names for saved locations in this inventory. An alias does not move any item.',
                ),
                TextField(
                  controller: alias,
                  enabled: !blocked && store.enabled,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Alias'),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  initialValue: spaceId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Saved location',
                  ),
                  items: store.spaces
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: AppText(s['name'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: blocked || !store.enabled
                      ? null
                      : (v) => setState(() => spaceId = v),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed:
                      blocked ||
                          !store.enabled ||
                          alias.text.trim().isEmpty ||
                          spaceId == null
                      ? null
                      : () => store.change({
                          'action': 'set',
                          'inventory_id': store.inventoryId,
                          'alias': alias.text.trim(),
                          'space_id': spaceId,
                        }),
                  child: const AppText('Save alias'),
                ),
                for (final entry in store.entries.where(
                  (e) => e['kind'] == 'alias',
                ))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: AppText(
                      (entry['payload'] as Map)['alias'].toString(),
                    ),
                    subtitle: AppText(
                      _location(
                        (entry['payload'] as Map)['space_id'].toString(),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: blocked
                          ? null
                          : () => store.change({
                              'action': 'delete',
                              'inventory_id': store.inventoryId,
                              'alias': (entry['payload'] as Map)['alias'],
                            }),
                      child: const AppText('Forget alias'),
                    ),
                  ),
              ],
              if ((store.snapshot!['legacy'] as List? ?? []).isNotEmpty)
                ExpansionTile(
                  title: const AppText('Unverified legacy memory'),
                  subtitle: const AppText('Excluded from personalization'),
                  children: [
                    for (final entry in store.snapshot!['legacy'] as List)
                      ListTile(
                        title: AppText('${entry['key']}'),
                        subtitle: AppText('${entry['value']}'),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: blocked
                    ? null
                    : () async {
                        final result = await store.export();
                        if (result == null || !context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const AppText('Memory export'),
                            content: SingleChildScrollView(
                              child: SelectableText(result),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: result),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: const AppText('Copy JSON'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const AppText('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                child: const AppText('Export memory'),
              ),
              TextButton(
                onPressed: blocked ? null : _forget,
                child: const AppText('Forget personalization'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _location(String id) {
    for (final space in store.spaces) {
      if (space['id'] == id) return space['name'].toString();
    }
    return 'Unavailable location';
  }
}
